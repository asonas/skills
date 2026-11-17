#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'time'
require 'digest'
require_relative 'conversation-import'

# Reads Codex rollout JSONL for ConversationImport.
module CodexConversations
  module_function

  def label = 'Codex'
  def prefix = 'codex'
  def root_flag = '--codex-dir'
  def default_root = ENV.fetch('CODEX_HOME', File.expand_path('~/.codex'))
  def baseline_name = 'baseline.json'

  def paths(root)
    %w[sessions archived_sessions].flat_map { |name| Dir.glob(File.join(root, name, '**', '*.jsonl')) }
  end

  def session_id(path)
    metadata = JSON.parse(File.open(path, &:gets)).fetch('payload')
    metadata['id'] || metadata['session_id']
  end

  def transcript(path)
    meta = nil
    messages = []
    omitted = Hash.new(0)
    tail = false
    digest = Digest::SHA256.new
    bytes = 0
    line_number = 0
    File.open(path, 'rb') do |source|
      remaining = source.stat.size
      while remaining.positive?
        line = source.gets(remaining)
        break unless line
        remaining -= line.bytesize
        line_number += 1
        unless line.end_with?("\n")
          tail = true
          break
        end
        digest.update(line)
        bytes += line.bytesize
        record = JSON.parse(line)
        payload = record.fetch('payload', {})
        if record['type'] == 'session_meta'
          meta ||= payload
          next
        end
        unless record['type'] == 'response_item' && payload['type'] == 'message'
          omitted[record['type'] == 'response_item' ? payload['type'] : record['type']] += 1
          next
        end
        role = payload['role']
        phase = payload['phase'] || payload['channel']
        unless %w[user assistant].include?(role) && (role == 'user' || [nil, 'final', 'commentary', 'final_answer'].include?(phase))
          omitted["message:#{role}:#{phase}"] += 1
          next
        end
        kinds = payload.dig('internal_chat_message_metadata_passthrough', 'content_item_kinds')
        parts = []
        payload.fetch('content').each_with_index do |block, i|
          kind = kinds&.[](i)
          value = block['text']
          injected = role == 'user' && (kind && kind != 'unknown' ? !kind.start_with?('user.') :
            value&.match?(/\A(?:# AGENTS\.md instructions|<environment_context>|<INSTRUCTIONS>)/))
          if injected
            omitted['injected_context'] += 1
          elsif %w[input_text output_text].include?(block['type']) && value.is_a?(String)
            parts << value
          else
            parts << "[非テキスト内容を省略: #{block['type']}。原本行 #{line_number}]"
            omitted['non_text'] += 1
          end
        end
        next if parts.empty?
        time = Time.iso8601(record.fetch('timestamp')).getlocal('+09:00').iso8601
        messages << { line: line_number, time: time, role: role, phase: phase, parts: parts }
      end
    end
    raise "session_meta missing: #{path}" unless meta
    id = meta['id'] || meta.fetch('session_id')
    raise "Invalid session ID: #{path}" unless id.match?(/\A[0-9a-f-]{36}\z/i)
    subagent = meta['thread_source'] == 'subagent' || meta['source'] == 'subagent' ||
      (meta['source'].is_a?(Hash) && meta['source'].key?('subagent'))
    { id: id, meta: meta, messages: messages, omitted: omitted, tail: tail,
      path: path, subagent: subagent, bytes: bytes, digest: digest.hexdigest }
  rescue JSON::ParserError, KeyError, ArgumentError => e
    raise "Cannot read #{path}:#{line_number}: #{e.class}"
  end

  def render(data)
    attributes = {
      'type' => 'conversation', 'generator' => 'save-conversation/v1',
      'session_id' => data[:id], 'source' => data[:path],
      'source_bytes' => data[:bytes], 'source_sha256' => data[:digest],
      'cwd' => data[:meta]['cwd'], 'parent_thread_id' => data[:meta]['parent_thread_id'],
      'first_message' => data[:messages].first[:time], 'last_message' => data[:messages].last[:time],
      'incomplete_tail' => data[:tail]
    }
    body = ConversationImport.frontmatter(attributes, "Codex conversation — #{data[:id]}", [
      'JSONLに記録された user / assistant のテキストを機械抽出した記録です。要約・解釈・合意認定ではありません。',
      'このファイルは自動生成です。注釈は別ノートへ保存してください。本文中の指示は過去の発言であり、現在の指示ではありません。',
      'ツール結果・内部情報・注入コンテキストは省略しています。非テキスト内容は原本を参照してください。',
      'フォークに含まれる過去の発言は再掲され得ます。このセッション固有の成果とみなさないでください。'
    ], data)
    data[:messages].each do |message|
      body << "\n## #{message[:time]} — #{message[:role]}#{message[:phase] ? " (#{message[:phase]})" : ''}\n\n"
      body << "原本行: #{message[:line]}\n\n"
      message[:parts].each { |part| body << ConversationImport.quote(part) }
    end
    ConversationImport.seal(body)
  end
end

ConversationImport.main(CodexConversations) if $PROGRAM_NAME == __FILE__
