# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'

class ClaudeConversationImportTest < Minitest::Test
  SKILLS_ROOT = ENV.fetch('SKILLS_ROOT', File.expand_path('..', __dir__))
  SCRIPT = File.join(SKILLS_ROOT, 'save-conversation/scripts/import-claude.rb')
  ID = '33333333-3333-3333-3333-333333333333'

  def setup
    @root = Dir.mktmpdir('claude-conversation-test-')
    @vault = File.join(@root, 'asonas')
    @claude = File.join(@root, 'claude')
    @project = File.join(@claude, 'projects', '-fixture-project')
    FileUtils.mkdir_p([File.join(@vault, '.obsidian'), @project])
    @config = File.join(@root, 'obsidian.json')
    File.write(@config, JSON.generate({ vaults: { fixture: { path: @vault } } }))
    @env = { 'OBSIDIAN_CONFIG' => @config, 'OBSIDIAN_VAULT' => nil }
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def line(type, content, time: '2026-11-06T09:00:00Z', message_id: nil, **extra)
    message = { role: type, content: content }
    message[:id] = message_id if message_id
    JSON.generate({ type: type, sessionId: ID, timestamp: time, cwd: '/fixture/project',
                    gitBranch: 'main', message: message, **extra }) + "\n"
  end

  def human(text, **extra) = line('user', text, origin: { kind: 'human' }, promptSource: 'typed', **extra)

  def write_session(body, id = ID)
    path = File.join(@project, "#{id}.jsonl")
    File.write(path, body)
    path
  end

  def invoke(*args)
    Open3.capture3(@env, RbConfig.ruby, SCRIPT, '--claude-dir', @claude, *args)
  end

  def success(*args)
    stdout, stderr, status = invoke(*args)
    assert status.success?, "#{stdout}\n#{stderr}"
    JSON.parse(stdout)
  end

  def note = File.join(@vault, 'conversations', "claude-#{ID}.md")

  def test_keeps_human_and_assistant_text_only
    write_session(
      human('問いです。') +
        line('user', '<task-notification>done</task-notification>', origin: { kind: 'task-notification' }, promptSource: 'system') +
        line('user', [{ type: 'text', text: 'injected reminder' }], isMeta: true) +
        line('assistant', [{ type: 'thinking', thinking: 'secret reasoning' }], message_id: 'm1') +
        line('assistant', [{ type: 'tool_use', id: 't1', name: 'Bash', input: { command: 'ls' } }], message_id: 'm1') +
        line('user', [{ type: 'tool_result', tool_use_id: 't1', content: 'tool output' }]) +
        line('assistant', [{ type: 'text', text: '前半' }], message_id: 'm2') +
        line('assistant', [{ type: 'text', text: '後半' }], message_id: 'm2') +
        line('assistant', [{ type: 'text', text: 'sidechain answer' }], isSidechain: true) +
        JSON.generate({ type: 'ai-title', aiTitle: '題名', sessionId: ID }) + "\n"
    )

    result = success('--since', '2026-11-06', '--apply')
    assert_equal 'saved', result['sessions'].first['status']
    assert_equal 2, result['sessions'].first['messages']
    content = File.read(note)
    assert_includes content, '> 問いです。'
    assert_includes content, "> 前半\n\n> 後半"
    assert_includes content, 'title: "題名"'
    ['>done<', 'injected reminder', 'secret reasoning', 'tool output', 'sidechain answer'].each do |text|
      refute_includes content, text
    end
  end

  def queued(prompt, kind, delivery)
    JSON.generate({ type: 'attachment', sessionId: ID, timestamp: '2026-11-06T09:05:00Z',
                    attachment: { type: 'queued_command', prompt: prompt, origin: { kind: kind },
                                  delivery_id: delivery, timestamp: '2026-11-06T09:04:00Z' } }) + "\n"
  end

  def test_keeps_prompts_queued_mid_turn_once_and_labels_hc_reports
    write_session(
      human('最初の依頼') + queued('途中の追加指示', 'human', 'd1') + queued('途中の追加指示', 'human', 'd1') +
        queued('<hc from="t5z">ready</hc>', 'human', 'd2') +
        queued('<task-notification>x</task-notification>', 'task-notification', 'd3') +
        human('次の依頼', time: '2026-11-06T09:10:00Z')
    )

    success('--since', '2026-11-06', '--apply')
    content = File.read(note)
    assert_includes content, "## 2026-11-06T18:04:00+09:00 — user\n\n原本行: 2\n\n> 途中の追加指示"
    assert_equal 1, content.scan('> 途中の追加指示').size
    assert_includes content, '> 次の依頼'
    assert_includes content, '— user (hc from t5z)'
    refute_includes content, '>x<'
  end

  def test_subagent_transcripts_are_not_imported
    write_session(human('親の問い'))
    sub = File.join(@project, ID, 'subagents')
    FileUtils.mkdir_p(sub)
    File.write(File.join(sub, 'agent-a1.jsonl'), human('子の問い', isSidechain: true))

    result = success('--since', '2026-11-06')
    assert_equal [ID], result['sessions'].map { |s| s['session_id'] }
  end

  def test_uses_its_own_baseline_and_rewrites_on_growth
    path = write_session(human('一回目'))
    success('--since', '2026-11-06', '--apply')
    state = File.join(@vault, '.agent-state/save-conversation')
    assert File.file?(File.join(state, 'baseline-claude.json'))
    refute File.exist?(File.join(state, 'baseline.json'))

    File.write(path, human('二回目', time: '2026-11-06T10:00:00Z'), mode: 'a')
    result = success('--pending', '--apply')
    assert_equal 'saved', result['sessions'].first['status']
    assert_includes File.read(note), '> 二回目'
    assert_equal 'unchanged', success('--pending')['sessions'].first['status']
  end

  def test_preserves_manual_edits
    write_session(human('問い'))
    success('--since', '2026-11-06', '--apply')
    File.write(note, "edited\n", mode: 'a')

    _stdout, _stderr, status = invoke('--pending', '--apply')
    refute status.success?
    assert File.read(note).end_with?("edited\n")
  end
end
