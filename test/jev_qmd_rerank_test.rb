require 'minitest/autorun'
require_relative '../jev-qmd/scripts/rerank'

class RerankTest < Minitest::Test
  def with_child_process(replacement)
    original = Open3.method(:capture2)
    key = ENV['TYPESAFE_API_KEY']
    ENV['TYPESAFE_API_KEY'] = 'test-key'
    Open3.define_singleton_method(:capture2, replacement)
    yield
  ensure
    Open3.define_singleton_method(:capture2, original)
    key ? ENV['TYPESAFE_API_KEY'] = key : ENV.delete('TYPESAFE_API_KEY')
  end

  def setup
    @snapshot = { 'question' => 'Which document answers?', 'qmd_command' => ['qmd', 'query'], 'qmd_seconds' => 1,
      'candidates' => %w[a b c].map.with_index { |s, i| { 'file' => "qmd://test/#{s}.md", 'body' => s, 'qmd_rank' => i + 2 } } }
  end

  def test_preview_and_rejection_work_without_credentials_at_process_boundary
    Tempfile.create(['rerank-test-', '.json']) do |f|
      f.write(JSON.generate(@snapshot)); f.flush
      command = [RbConfig.ruby, File.expand_path('../jev-qmd/scripts/rerank.rb', __dir__)]
      out, err, status = Open3.capture3({ 'TYPESAFE_API_KEY' => nil }, *command, 'preview', '--input', f.path)
      assert status.success?, err
      review = JSON.parse(out)
      assert_equal [%w[a], %w[b], %w[c]], review['requests'].map { |r| r['state']['passages'] }
      @snapshot['question'] = 'Changed after review'
      f.rewind; f.truncate(0); f.write(JSON.generate(@snapshot)); f.flush
      out, err, status = Open3.capture3({ 'TYPESAFE_API_KEY' => nil }, *command, 'run', '--input', f.path, '--approve', review['approval_sha256'])
      refute status.success?
      assert_empty out
      assert_includes err, 'Approval mismatch'
    end
  end

  def test_isolated_results_keep_low_scores_and_stable_ties
    mutex = Mutex.new
    calls = []
    child = lambda do |*args|
      input = JSON.parse(File.read(args.last))
      mutex.synchronize { calls << input }
      body = input['candidates'].first['body']
      response = { 'model' => JevQmd::MODEL, 'answers' => { 'p0' => { 'type' => 'noul', 'noul' => body == 'a' ? 0.01 : 0.9 } }, 'usage' => { 'input_tokens' => 100, 'output_tokens' => 21 } }
      [JSON.generate(JevQmd.report(input, response, 0.1)), Struct.new(:success?).new(true)]
    end
    with_child_process(child) do
        result = JevRerank.run(@snapshot, JevRerank.preview(@snapshot)[:approval_sha256])
        assert_equal [2, 3, 1], result[:ranking].map { |r| r['original_rank'] }
        assert_equal 3, result[:baseline].size
        assert_equal 300, result[:input_tokens]
        assert_in_delta 0.0000126, result[:estimated_usd]
        assert calls.all? { |s| s['candidates'].size == 1 }
        refute result[:ranking].any? { |r| r.key?('body') }
    end
  end

  def test_failed_request_does_not_return_partial_ranking_or_retry
    @snapshot['candidates'] = @snapshot['candidates'].first(1)
    calls = 0
    with_child_process(->(*_) { calls += 1; ['', Struct.new(:success?).new(false)] }) do
        assert_raises(RuntimeError) { JevRerank.run(@snapshot, JevRerank.preview(@snapshot)[:approval_sha256]) }
    end
    assert_equal 1, calls
  end
end
