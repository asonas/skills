require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require_relative '../obsidian-vault/scripts/review-locations'

class LocationReviewTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir('location-review-')
    %w[essays notes projects/partch companies/ivry career/job-search-2026 daily conversations].each do |path|
      FileUtils.mkdir_p(File.join(@tmp, path))
    end
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def write(path, body)
    absolute = File.join(@tmp, path)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, body)
    absolute
  end

  def test_preview_uses_only_existing_destinations
    note = write('notes/partch.md', "---\nauthorship: ai\nproject: partch\n---\n基板製造の調査")
    review = LocationReview.preview(vault: @tmp, date: Date.today, paths: [note])
    request = review[:notes].first[:request]
    criteria = request[:questions][:destination][:criteria]
    assert_equal 'notes/partch.md', request[:state][:current_path]
    assert_equal({ 'authorship' => 'ai', 'project' => 'partch' }, request[:state][:metadata])
    assert_includes review[:destinations].values, 'projects/partch'
    assert_includes criteria.keys, 'keep_current'
    assert_includes criteria.keys, 'needs_review'
    refute criteria.values.join.include?('pr-reviews')
    refute criteria.values.join.include?('scripts')
    refute review[:destinations].values.any? { |path| path.start_with?('daily') || path.start_with?('conversations') }
  end

  def test_fixed_destinations_are_excluded_from_date_scan
    today = Date.today
    write('daily/today.md', 'daily')
    write('conversations/chat.md', 'chat')
    included = write('notes/research.md', 'research')
    assert_equal [included], LocationReview.note_paths(@tmp, today)
  end

  def test_preview_is_offline_and_changes_with_content
    note = write('notes/research.md', 'research')
    first = LocationReview.preview(vault: @tmp, date: Date.today, paths: [note])
    File.write(note, 'changed')
    second = LocationReview.preview(vault: @tmp, date: Date.today, paths: [note])
    refute_equal first[:approval_sha256], second[:approval_sha256]
    assert_equal LocationReview::ENDPOINT, first[:destination]
  end

  def test_preview_cli_emits_reviewable_json_without_credentials
    write('notes/research.md', 'research')
    script = File.expand_path('../obsidian-vault/scripts/review-locations.rb', __dir__)
    output, error, status = Open3.capture3(
      { 'TYPESAFE_API_KEY' => nil }, RbConfig.ruby, script, 'preview',
      '--vault', @tmp, '--date', Date.today.iso8601
    )
    assert status.success?, error
    review = JSON.parse(output)
    assert_equal ['notes/research.md'], review.fetch('notes').map { |note| note.fetch('path') }
    assert_match(/\A[0-9a-f]{64}\z/, review.fetch('approval_sha256'))
  end

  def test_run_requires_exact_preview_and_unchanged_note
    note = write('notes/research.md', 'research')
    review = JSON.parse(JSON.generate(LocationReview.preview(vault: @tmp, date: Date.today, paths: [note])))
    assert_raises(ArgumentError) { LocationReview.run(review, 'wrong') }
    File.write(note, 'changed')
    old_key = ENV['TYPESAFE_API_KEY']
    ENV['TYPESAFE_API_KEY'] = 'test-key'
    error = assert_raises(RuntimeError) { LocationReview.run(review, review['approval_sha256']) }
    assert_match(/changed after preview/, error.message)
  ensure
    old_key ? ENV['TYPESAFE_API_KEY'] = old_key : ENV.delete('TYPESAFE_API_KEY')
  end

  def test_run_returns_advisory_proposal_without_moving_file
    note = write('notes/partch.md', 'partch circuit investigation')
    review = JSON.parse(JSON.generate(LocationReview.preview(vault: @tmp, date: Date.today, paths: [note])))
    destination_id = review.fetch('destinations').key('projects/partch')
    original = LocationReview.method(:request)
    LocationReview.define_singleton_method(:request) do |payload, _key|
      keys = payload.fetch('questions').fetch('destination').fetch('criteria').keys
      probabilities = keys.to_h { |key| [key, key == destination_id ? 1.0 : 0.0] }
      { 'model' => LocationReview::MODEL, 'usage' => { 'input_tokens' => 100, 'output_tokens' => 20 },
        'answers' => { 'destination' => { 'type' => 'choice', 'choice' => destination_id,
          'confidence' => 1.0, 'probabilities' => probabilities } } }
    end
    old_key = ENV['TYPESAFE_API_KEY']
    ENV['TYPESAFE_API_KEY'] = 'test-key'
    report = LocationReview.run(review, review['approval_sha256'])
    assert report[:advisory_only]
    assert_equal 'projects/partch', report[:results].first[:proposed_directory]
    assert File.file?(note)
    refute File.exist?(File.join(@tmp, 'projects/partch/partch.md'))
  ensure
    LocationReview.define_singleton_method(:request, original) if original
    old_key ? ENV['TYPESAFE_API_KEY'] = old_key : ENV.delete('TYPESAFE_API_KEY')
  end
end
