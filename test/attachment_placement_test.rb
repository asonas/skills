# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class AttachmentPlacementTest < Minitest::Test
  ROOT = File.expand_path(ENV.fetch('SKILLS_ROOT', File.expand_path('..', __dir__)))
  SCRIPT = File.join(ROOT, 'obsidian-vault/scripts/place-attachment.rb')

  def setup
    @root = Dir.mktmpdir('attachment-placement-')
    @vault = File.join(@root, 'asonas')
    @config = File.join(@root, 'obsidian.json')
    @note = 'projects/example/Design #1.md'
    FileUtils.mkdir_p(File.join(@vault, '.obsidian/plugins/obsidian-custom-attachment-location'))
    FileUtils.mkdir_p(File.join(@vault, 'projects/example'))
    File.write(File.join(@vault, @note), 'Example')
    File.write(@config, JSON.generate('vaults' => { 'test' => { 'path' => @vault } }))
    write_settings
    @source = File.join(@root, 'source image.png')
    File.binwrite(@source, 'image bytes')
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_places_a_copy_using_the_live_plugin_settings
    stdout, stderr, status = run_script
    assert status.success?, stderr
    target = 'projects/example/assets/Design -1/file-20260910123456789.png'
    assert_equal "#{target}\n", stdout
    assert_equal 'image bytes', File.binread(File.join(@vault, target))
    assert File.exist?(@source)

    stdout, stderr, status = run_script
    assert status.success?, stderr
    duplicate = 'projects/example/assets/Design -1/file-20260910123456789 1.png'
    assert_equal "#{duplicate}\n", stdout
    assert_equal 'image bytes', File.binread(File.join(@vault, duplicate))
  end

  def test_stops_before_writing_when_the_configuration_uses_an_unknown_token
    write_settings('attachmentFolderPath' => './assets/${frontmatter}')
    stdout, stderr, status = run_script
    refute status.success?
    assert_empty stdout
    assert_includes stderr, 'Unsupported Custom Attachment Location token'
    refute File.exist?(File.join(@vault, 'projects/example/assets'))
  end

  def test_stops_before_writing_when_plugin_behavior_is_not_supported
    write_settings('convertImagesToJpegMode' => 'All')
    stdout, stderr, status = run_script
    refute status.success?
    assert_empty stdout
    assert_includes stderr, 'Unsupported Custom Attachment Location settings'
    refute File.exist?(File.join(@vault, 'projects/example/assets'))
  end

  def test_rejects_a_note_outside_the_vault
    outside = File.join(@root, 'outside.md')
    File.write(outside, 'Outside')
    stdout, stderr, status = run_script('../outside.md')
    refute status.success?
    assert_empty stdout
    assert_includes stderr, 'Path escapes the Vault'
  end

  private

  def write_settings(overrides = {})
    settings = {
      'attachmentFolderPath' => './assets/${noteFileName}',
      'attachmentRenameMode' => 'All',
      'attachmentUnitFolderPaths' => [],
      'convertImagesToJpegMode' => 'None',
      'generatedAttachmentFileName' => "file-${date:{momentJsFormat:'YYYYMMDDHHmmssSSS'}}",
      'duplicateNameSeparator' => ' ',
      'specialCharacters' => '#^[]|*\\<>:?/',
      'specialCharactersReplacement' => '-'
    }.merge(overrides)
    path = File.join(@vault, '.obsidian/plugins/obsidian-custom-attachment-location/data.json')
    File.write(path, JSON.generate(settings))
  end

  def run_script(note = @note)
    env = {
      'OBSIDIAN_CONFIG' => @config,
      'OBSIDIAN_VAULT' => @vault,
      'OBSIDIAN_ATTACHMENT_TIME' => '2026-09-10T12:34:56.789+09:00'
    }
    Open3.capture3(env, RbConfig.ruby, SCRIPT, 'asonas', note, @source)
  end
end
