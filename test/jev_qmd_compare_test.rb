require 'minitest/autorun'
require_relative '../jev-qmd/scripts/compare'

class CompareTest < Minitest::Test
  def setup
    @snapshot = { 'question' => 'How is the server upgraded?', 'qmd_command' => ['qmd', 'query'], 'qmd_seconds' => 1.2,
      'candidates' => [
        { 'file' => 'qmd://example/a.md', 'body' => 'Unrelated topic', 'qmd_score' => 0.9 },
        { 'file' => 'qmd://example/b.md', 'body' => 'The upgrade procedure', 'qmd_score' => 0.8 }
      ] }
  end

  def test_same_candidates_are_reranked_and_cost_uses_input_only
    response = { 'model' => JevQmd::MODEL, 'answers' => { 'p0' => { 'type' => 'noul', 'noul' => 0.1 }, 'p1' => { 'type' => 'noul', 'noul' => 0.9 } }, 'usage' => { 'input_tokens' => 1000, 'output_tokens' => 100 } }
    result = JevQmd.report(@snapshot, response, 0.2)
    assert_equal [2, 1], result[:ranking].map { |c| c['original_rank'] }
    assert_in_delta 0.000042, result[:estimated_usd]
    assert_equal 2, result[:baseline].size
    refute result[:ranking].any? { |c| c.key?('body') }
    response['answers']['p1']['noul'] = 1.1
    assert_raises(ArgumentError) { JevQmd.report(@snapshot, response, 0.2) }
  end

  def test_payload_preserves_full_evidence_and_excludes_paths_and_scores
    request = JevQmd.payload(@snapshot)
    assert_equal ['Unrelated topic', 'The upgrade procedure'], request[:state][:passages]
    refute JSON.generate(request).include?('qmd://')
    assert_includes request[:questions]['p1'][:instructions], 'passages[1]'
    @snapshot['candidates'][0]['body'] = 'x' * 60_001
    assert_raises(ArgumentError) { JevQmd.payload(@snapshot) }
  end
end
