# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'

class ConversationImportTest < Minitest::Test
  SKILLS_ROOT = ENV.fetch('SKILLS_ROOT', File.expand_path('..', __dir__))
  SCRIPT = File.join(SKILLS_ROOT, 'save-conversation/scripts/import-codex.rb')
  ID = '11111111-1111-1111-1111-111111111111'
  OTHER = '22222222-2222-2222-2222-222222222222'

  def setup
    @root = Dir.mktmpdir('conversation-test-')
    @vault = File.join(@root, 'asonas')
    @codex = File.join(@root, 'codex')
    FileUtils.mkdir_p([File.join(@vault, '.obsidian'), File.join(@codex, 'sessions')])
    @config = File.join(@root, 'obsidian.json')
    File.write(@config, JSON.generate({ vaults: { fixture: { path: @vault } } }))
    @env = { 'OBSIDIAN_CONFIG' => @config, 'OBSIDIAN_VAULT' => nil }
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def record(type, payload, time = '2026-09-08T14:59:00Z')
    JSON.generate({ type: type, timestamp: time, payload: payload }) + "\n"
  end

  def chat_message(role, text, time = '2026-09-08T14:59:00Z', **extra)
    record('response_item', { type: 'message', role: role, content: [{ type: 'input_text', text: text }], **extra }, time)
  end

  def source(id = ID, suffix = '')
    path = File.join(@codex, 'sessions', "#{id}.jsonl")
    File.write(path, record('session_meta', { id: id, source: 'cli', cwd: '/fixture/project' }) + chat_message('user', '問いです。') + suffix)
    path
  end

  def invoke(*args)
    stdout, stderr, status = Open3.capture3(@env, RbConfig.ruby, SCRIPT, '--codex-dir', @codex, *args)
    [stdout, stderr, status]
  end

  def success(*args)
    stdout, stderr, status = invoke(*args)
    assert status.success?, "#{stdout}\n#{stderr}"
    JSON.parse(stdout)
  end

  def note(id = ID)
    File.join(@vault, 'conversations', "codex-#{id}.md")
  end

  def test_preview_then_exact_speakers_without_duplicate_events_or_injected_context
    suffix = chat_message('user', 'injected secret', internal_chat_message_metadata_passthrough: { content_item_kinds: ['agents_md.instructions'] })
    suffix << chat_message('assistant', 'private reasoning', channel: 'analysis')
    suffix << record('response_item', { type: 'function_call_output', output: 'tool secret' })
    suffix << record('event_msg', { type: 'agent_message', message: '答えです。' })
    suffix << chat_message('assistant', "答えです。\n\n## 見出し\n```rb\nputs 1\n```", phase: 'final')
    suffix << record('response_item', { type: 'message', role: 'user', content: [{ type: 'input_image', image_url: 'secret image' }] })
    source(ID, suffix)
    result = success('--since', '2026-09-08')
    assert_equal 'would_save', result['sessions'].first['status']
    refute Dir.exist?(File.join(@vault, '.agent-state'))
    refute File.exist?(note)
    success('--since', '2026-09-08', '--apply')
    text = File.read(note)
    assert_includes text, '2026-09-08T23:59:00+09:00 — user'
    assert_includes text, "> 答えです。\n> \n> ## 見出し\n> ```rb\n> puts 1\n> ```"
    assert_equal 1, text.scan('答えです。').size
    %w[injected\ secret private\ reasoning tool\ secret secret\ image].each { |value| refute_includes text, value }
    assert_includes text, '非テキスト内容を省略: input_image'
    assert_equal 0o600, File.stat(note).mode & 0o777
  end

  def test_pending_requires_scope_and_updates_resumed_and_archived_sessions_across_midnight
    source
    _, stderr, status = invoke('--pending')
    refute status.success?
    assert_includes stderr, 'No baseline'
    success('--since', '2026-09-08', '--apply')
    original = File.binread(note)
    assert_equal 'unchanged', success('--pending', '--apply')['sessions'].first['status']
    assert_equal original, File.binread(note)
    path = File.join(@codex, 'sessions', "#{ID}.jsonl")
    File.open(path, 'a') { |f| f.write(chat_message('assistant', '翌日の続き', '2026-09-08T15:01:00Z')) }
    archived = File.join(@codex, 'archived_sessions')
    FileUtils.mkdir_p(archived)
    FileUtils.mv(path, archived)
    source(OTHER)
    result = success('--pending', '--apply')
    assert_equal 2, result['sessions'].size
    assert_includes File.read(note), '2026-09-09T00:01:00+09:00 — assistant'
    assert_includes File.read(note), '/archived_sessions/'
    assert_equal 1, File.read(note).scan('問いです。').size
  end

  def test_incomplete_tail_is_retried_but_complete_corruption_blocks_overwrite
    complete = chat_message('assistant', '後で完了')
    path = source(ID, complete[0, 30])
    result = success('--session', ID, '--apply')
    assert result['sessions'].first['incomplete_tail']
    refute_includes File.read(note), '後で完了'
    File.open(path, 'a') { |f| f.write(complete[30..]) }
    success('--session', ID, '--apply')
    saved = File.binread(note)
    assert_equal 1, saved.scan('後で完了'.b).size
    File.open(path, 'a') { |f| f.write("invalid json\n") }
    stdout, _, status = invoke('--session', ID, '--apply')
    refute status.success?
    assert_includes stdout, 'Cannot read'
    assert_equal saved, File.binread(note)
  end

  def test_manual_edits_and_source_rewrites_are_preserved
    path = source
    success('--session', ID, '--apply')
    original = File.binread(note)
    File.open(note, 'a') { |f| f.write('my annotation') }
    edited = File.binread(note)
    stdout, _, status = invoke('--session', ID, '--apply')
    refute status.success?
    assert_includes stdout, 'Manual edit'
    assert_equal edited, File.binread(note)
    File.binwrite(note, original)
    File.write(path, record('session_meta', { id: ID }) + chat_message('user', 'different source'))
    stdout, _, status = invoke('--session', ID, '--apply')
    refute status.success?
    assert_includes stdout, 'Source truncated or rewritten'
    assert_equal original, File.binread(note)
  end

  def test_subagents_are_excluded_and_duplicate_ids_fail_before_writing
    path = source
    other = File.join(@codex, 'sessions', "#{OTHER}.jsonl")
    File.write(other, record('session_meta', { id: OTHER, source: { subagent: 'spawn' } }) + chat_message('user', 'internal task'))
    assert_equal [ID], success('--since', '2026-09-08')['sessions'].map { |s| s['session_id'] }
    FileUtils.cp(path, File.join(@codex, 'sessions', 'duplicate.jsonl'))
    stdout, _, status = invoke('--since', '2026-09-08', '--apply')
    refute status.success?
    assert_includes stdout, 'Duplicate session'
    refute File.exist?(note)
  end

  def test_concurrent_import_lock_and_symlink_do_not_overwrite
    source
    state = File.join(@vault, '.agent-state', 'save-conversation')
    FileUtils.mkdir_p(state)
    File.open(File.join(state, 'import.lock'), 'w') do |lock|
      lock.flock(File::LOCK_EX)
      _, stderr, status = invoke('--session', ID, '--apply')
      refute status.success?
      assert_includes stderr, 'Another conversation import'
    end
    outside = File.join(@root, 'outside.md')
    File.write(outside, 'untouched')
    FileUtils.mkdir_p(File.dirname(note))
    File.symlink(outside, note)
    stdout, _, status = invoke('--session', ID, '--apply')
    refute status.success?
    assert_includes stdout, 'Refusing symlink'
    assert_equal 'untouched', File.read(outside)
  end
end
