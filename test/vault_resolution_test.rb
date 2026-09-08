require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'

class VaultResolutionTest < Minitest::Test
  ROOT = File.expand_path(ENV.fetch('SKILLS_ROOT', File.expand_path('..', __dir__)))
  SCRIPT = File.join(ROOT, 'obsidian-vault/scripts/resolve-vault.rb')

  def setup
    @root = Dir.mktmpdir('vault-resolution-')
    @old = File.join(@root, 'Documents/asonas')
    @current = File.join(@root, 'Obsidian/asonas')
    [@old, @current].each { |path| FileUtils.mkdir_p(File.join(path, '.obsidian')) }
    @config = File.join(@root, 'obsidian.json')
    register(@current)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def register(*paths)
    File.write(@config, JSON.generate('vaults' => paths.each_with_index.to_h { |path, index| [index.to_s, { 'path' => path }] }))
  end

  def resolve(override = nil)
    Open3.capture3({ 'OBSIDIAN_CONFIG' => @config, 'OBSIDIAN_VAULT' => override }, RbConfig.ruby, SCRIPT, 'asonas')
  end

  def test_registered_vault_wins_even_when_old_vault_still_exists
    stdout, stderr, status = resolve
    assert status.success?, stderr
    assert_equal "#{File.realpath(@current)}\n", stdout
    stdout, stderr, status = resolve(@old)
    refute status.success?
    assert_empty stdout
    assert_includes stderr, 'does not match'
  end

  def test_ambiguous_or_unknown_vault_stops_without_a_path
    [[@old, @current], []].each do |paths|
      register(*paths)
      stdout, stderr, status = resolve
      refute status.success?
      assert_empty stdout
      assert_includes stderr, 'Expected one registered vault'
    end
  end

  def test_invalid_registration_stops_without_creating_a_directory
    FileUtils.remove_entry(@current)
    stdout, stderr, status = resolve
    refute status.success?
    assert_empty stdout
    assert_includes stderr, 'missing'
    refute File.exist?(@current)
    File.write(@config, '{broken')
    stdout, stderr, status = resolve
    refute status.success?
    assert_empty stdout
    assert_includes stderr, 'Cannot read Obsidian registration'
  end

  def test_importers_reject_a_stale_vault_before_accessing_external_data
    [['books-highlights/books-highlights.rb', '--book', 'Synthetic book'],
     ['raindrop-sync/raindrop-sync.rb', '--dry-run']].each do |script, *args|
      stdout, stderr, status = Open3.capture3(
        { 'OBSIDIAN_CONFIG' => @config, 'OBSIDIAN_VAULT' => @old },
        RbConfig.ruby, File.join(ROOT, script), *args
      )
      refute status.success?
      assert_empty stdout
      assert_includes stderr, 'does not match'
      assert_equal ['.obsidian'], Dir.children(@old)
      assert_equal ['.obsidian'], Dir.children(@current)
    end
  end
end
