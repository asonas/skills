require 'digest'
require 'tempfile'
require 'rbconfig'
require_relative 'compare'

module JevRerank
  def self.preview(snapshot)
    JevQmd.payload(snapshot)
    candidates = snapshot.fetch('candidates')
    files = candidates.map { |c| c.fetch('file') }
    raise ArgumentError, 'Duplicate candidate URI' unless files.uniq.size == files.size
    requests = candidates.map { |c| JevQmd.payload(snapshot.merge('candidates' => [c])) }
    reviewed = { destination: 'https://api.typesafe.ai/v1/systemone', candidates: files, requests: requests }
    reviewed.merge(approval_sha256: Digest::SHA256.hexdigest(JSON.generate(reviewed)))
  end

  def self.run(snapshot, approval)
    review = preview(snapshot)
    unless approval == review.fetch(:approval_sha256)
      raise ArgumentError, 'Approval mismatch: preview and review this input before sending'
    end
    raise ArgumentError, 'Set TYPESAFE_API_KEY' if ENV.fetch('TYPESAFE_API_KEY', '').empty?
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    jobs = Queue.new
    snapshot.fetch('candidates').each_with_index { |c, i| jobs << [c, i] }
    reports = Array.new(snapshot['candidates'].size)
    failures = Queue.new
    workers = [4, reports.size].min.times.map do
      Thread.new do
        loop do
          break unless failures.empty?
          job = begin
            jobs.pop(true)
          rescue ThreadError
            break
          end
          candidate, index = job
          Tempfile.create(['jev-rerank-', '.json']) do |file|
            file.write(JSON.generate(snapshot.merge('candidates' => [candidate])))
            file.flush
            output, status = Open3.capture2(RbConfig.ruby, File.join(__dir__, 'compare.rb'), 'run', '--input', file.path)
            raise "Candidate #{index + 1} failed; requests are not retried" unless status.success?
            report = JSON.parse(output)
            raise 'Response candidate mismatch' unless report.fetch('ranking').map { |c| c.fetch('file') } == [candidate.fetch('file')]
            report['ranking'].first['original_rank'] = index + 1
            reports[index] = report
          end
        end
      rescue StandardError => error
        # Already dispatched requests may finish and incur cost after a peer fails.
        failures << error
      end
    end
    workers.each(&:join)
    raise failures.pop unless failures.empty?
    {
      question: snapshot.fetch('question'), approval_sha256: approval,
      wall_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
      requests: reports.size, models: reports.map { |r| r.fetch('model') }.uniq,
      input_tokens: reports.sum { |r| r.fetch('usage').fetch('input_tokens') },
      estimated_usd: reports.all? { |r| r['estimated_usd'] } ? reports.sum { |r| r['estimated_usd'] } : nil,
      price_date: '2026-09-19',
      baseline: snapshot['candidates'].map { |c| c.reject { |k, _| k == 'body' } },
      ranking: reports.map { |r| r.fetch('ranking').first }.sort_by { |c| [-c.fetch('jev'), c.fetch('original_rank')] }
    }
  end

  def self.main(argv)
    mode = argv.shift
    opts = {}
    parser = OptionParser.new do |p|
      p.banner = 'Usage: rerank.rb preview|run --input FILE [--approve SHA256]'
      p.on('--input FILE') { |v| opts[:input] = v }
      p.on('--approve SHA256') { |v| opts[:approval] = v }
    end
    parser.parse!(argv)
    raise ArgumentError, parser.to_s unless %w[preview run].include?(mode) && opts[:input] && argv.empty?
    snapshot = JSON.parse(File.read(opts[:input]))
    result = mode == 'preview' ? preview(snapshot) : run(snapshot, opts[:approval])
    puts JSON.pretty_generate(result)
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    JevRerank.main(ARGV)
  rescue StandardError => error
    warn "#{error.class}: #{error.message}"
    exit 1
  end
end
