require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'

class RecentDailyNotesTest < Minitest::Test
  SCRIPT = File.expand_path('../skills/today/scripts/find-recent-daily-notes.rb', __dir__)

  def setup
    @tmp = Dir.mktmpdir('recent-daily-')
    @vault = File.join(@tmp, 'asonas')
    FileUtils.mkdir_p(File.join(@vault, '.obsidian'))
    FileUtils.mkdir_p(File.join(@vault, 'daily'))
    @config = File.join(@tmp, 'obsidian.json')
    File.write(@config, JSON.generate('vaults' => {'fixture' => {'path' => @vault}}))
  end

  def teardown = FileUtils.remove_entry(@tmp)
  def note(date) = File.write(File.join(@vault, 'daily', "#{date}.md"), 'fixture')
  def dates(date)
    Open3.capture3({'OBSIDIAN_CONFIG' => @config, 'OBSIDIAN_VAULT' => nil}, RbConfig.ruby, SCRIPT, date)
  end

  def test_monday_includes_existing_friday_through_sunday_in_order
    %w[2026-11-12 2026-11-13 2026-11-14 2026-11-15 2026-11-16].each { |d| note(d) }
    out, error, status = dates('2026-11-16')
    assert status.success?, error
    assert_equal "2026-11-13\n2026-11-14\n2026-11-15\n", out
  end

  def test_other_days_return_only_the_most_recent_of_seven_days
    %w[2026-11-10 2026-11-14 2026-11-17].each { |d| note(d) }
    out, error, status = dates('2026-11-17')
    assert status.success?, error
    assert_equal "2026-11-14\n", out
  end

  def test_no_recent_note_returns_nonzero_and_no_dates
    note('2026-11-09')
    out, _, status = dates('2026-11-17')
    assert_equal 1, status.exitstatus
    assert_empty out
  end

  def test_invalid_registry_stops_without_creating_notes
    File.write(@config, '{}')
    out, error, status = dates('2026-11-17')
    refute status.success?
    assert_empty out
    assert_includes error, 'Cannot read Obsidian registration'
    assert_empty Dir.children(File.join(@vault, 'daily'))
  end
end
