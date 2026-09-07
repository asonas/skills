# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'json'

class VaultStateTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def setup
    @vault = Dir.mktmpdir('synthetic-vault-')
    FileUtils.mkdir_p(File.join(@vault, 'wiki'))
    FileUtils.mkdir_p(File.join(@vault, 'notes'))
    File.write(File.join(@vault, 'wiki/Example.md'), "---\nsources:\n  - \"[[notes/source]]\"\ntype: concept\n---\nExample\n")
    File.write(File.join(@vault, 'notes/source.md'), 'A deliberately unrelated source.')
  end

  def teardown
    FileUtils.remove_entry(@vault)
  end

  def run_script(path, *args)
    Open3.capture3({ 'OBSIDIAN_VAULT' => @vault }, RbConfig.ruby, File.join(ROOT, path), *args)
  end

  def test_source_review_exceptions_are_read_from_vault_not_package
    script = 'wiki-update/health/verify-sources.rb'
    stdout, _stderr, status = run_script(script)
    refute status.success?
    assert_includes stdout, 'NG   Example'
    state = File.join(@vault, '.agent-state/wiki-update')
    FileUtils.mkdir_p(state)
    File.write(File.join(state, 'verify-sources-accepted.tsv'), "Example\tnotes/source.md\tSynthetic reviewed exception\n")
    stdout, stderr, status = run_script(script, '--show-accepted')
    assert status.success?, stderr
    assert_includes stdout, 'Synthetic reviewed exception'
    assert_includes stdout, 'OK   Example'
  end

  def test_benchmark_defaults_to_vault_state_and_reports_missing_fixture
    script = 'vault-rag/bench/verify-fixture.rb'
    _stdout, stderr, status = run_script(script)
    refute status.success?
    assert_includes stderr, '.agent-state/vault-rag/vault-fixture.json'
    state = File.join(@vault, '.agent-state/vault-rag')
    FileUtils.mkdir_p(state)
    File.write(File.join(state, 'vault-fixture.json'), JSON.generate({
      'queries' => [{
        'id' => 'example', 'type' => 'exact',
        'query' => "lex: Example\nvec: Exampleの設定を探す",
        'expected_files' => ['wiki/Example.md'], 'expected_in_top_k' => 3
      }]
    }))
    stdout, stderr, status = run_script(script)
    assert status.success?, stderr
    assert_includes stdout, 'OK: fixture'
  end
end
