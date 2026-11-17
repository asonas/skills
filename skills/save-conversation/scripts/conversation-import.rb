# frozen_string_literal: true

require 'json'
require 'date'
require 'digest'
require 'fileutils'
require 'tempfile'
require 'optparse'
require_relative '../../obsidian-vault/scripts/resolve-vault'

# Shared import loop for agent transcripts. Each source supplies an adapter
# that reads its JSONL format; this module owns the Vault side: ownership
# checks, baselines, locking and atomic writes.
#
# Deterministic re-rendering and a checksum in the same atomic file avoid a
# separate cursor commit, so interruption cannot duplicate appended messages.
module ConversationImport
  module_function

  def quote(part)
    # Quote message Markdown so it cannot impersonate speaker headings.
    part.split("\n", -1).map { |line| "> #{line}" }.join("\n") << "\n\n"
  end

  def frontmatter(attributes, heading, notes, data)
    body = attributes.map { |key, value| "#{key}: #{JSON.generate(value)}\n" }.join
    body << "---\n\n# #{heading}\n\n"
    notes.each { |line| body << line << "\n" }
    body << "\n省略レコード種別: `#{JSON.generate(data[:omitted].sort.to_h)}`\n"
    body << "末尾の未完了レコードは次回取り込みます。\n" if data[:tail]
    body
  end

  def seal(body)
    "---\ngenerated_sha256: #{Digest::SHA256.hexdigest(body)}\n#{body}"
  end

  def verify_owned(path, source)
    raise "Refusing symlink: #{path}" if File.symlink?(path)
    return unless File.exist?(path)
    current = File.binread(path)
    match = current.match(/\A---\ngenerated_sha256: ([0-9a-f]{64})\n/)
    unless match && Digest::SHA256.hexdigest(current.byteslice(match[0].bytesize..)) == match[1]
      raise "Manual edit or unmanaged file; preserved: #{path}"
    end
    header = current.split("\n---\n", 2).first
    bytes = Integer(header[/^source_bytes: (\d+)$/, 1])
    expected = JSON.parse(header[/^source_sha256: (.+)$/, 1])
    digest = Digest::SHA256.new
    File.open(source, 'rb') do |file|
      remaining = bytes
      while remaining.positive? && (chunk = file.read([remaining, 65_536].min))
        digest.update(chunk)
        remaining -= chunk.bytesize
      end
      raise "Source truncated or rewritten; preserved: #{path}" unless remaining.zero? && digest.hexdigest == expected
    end
  end

  def atomic_write(path, content)
    Tempfile.create(['.conversation-', '.tmp'], File.dirname(path)) do |file|
      file.chmod(0o600)
      file.write(content)
      file.flush
      file.fsync
      File.rename(file.path, path)
    end
  end

  # The adapter responds to: label, prefix, root_flag, default_root,
  # baseline_name, paths(root), session_id(path), transcript(path), render(data).
  def run(argv, adapter)
    options = { root: adapter.default_root, ids: [], apply: false }
    parser = OptionParser.new do |p|
      p.banner = "#{File.basename($PROGRAM_NAME)} (--since YYYY-MM-DD | --pending | --session ID ...) [--apply] [#{adapter.root_flag} PATH]"
      p.on('--since DATE') { |v| options[:since] = Date.iso8601(v).iso8601 }
      p.on('--pending') { options[:pending] = true }
      p.on('--session ID') { |v| options[:ids] << v }
      p.on('--apply') { options[:apply] = true }
      p.on("#{adapter.root_flag} PATH") { |v| options[:root] = File.expand_path(v) }
    end
    parser.parse!(argv)
    modes = [options[:since], options[:pending], !options[:ids].empty?].count { |v| v }
    raise parser.to_s unless modes == 1 && argv.empty?
    vault = ObsidianVault.resolve
    directory = File.join(vault, 'conversations')
    state = File.join(vault, '.agent-state', 'save-conversation')
    [directory, File.dirname(state), state].each do |path|
      raise "Refusing symlink: #{path}" if File.symlink?(path)
    end
    lock = nil
    if options[:apply]
      FileUtils.mkdir_p(state, mode: 0o700)
      lock_path = File.join(state, 'import.lock')
      raise "Refusing symlink: #{lock_path}" if File.symlink?(lock_path)
      lock = File.open(lock_path, File::RDWR | File::CREAT, 0o600)
      raise 'Another conversation import is running; retry later.' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
    end
    baseline_path = File.join(state, adapter.baseline_name)
    raise "Refusing symlink: #{baseline_path}" if File.symlink?(baseline_path)
    baseline = File.exist?(baseline_path) ? JSON.parse(File.read(baseline_path)).fetch('since') : nil
    if options[:pending]
      raise 'No baseline. Preview --since YYYY-MM-DD and approve the scope before --apply.' unless baseline
      options[:since] = baseline
    end
    if baseline && options[:since] && options[:since] != baseline
      raise "Baseline already #{baseline}; use --session ID for additional historical imports."
    end
    root = File.realpath(options[:root])
    paths = adapter.paths(root).sort_by { |path| [File.basename(path), path] }
    raise "No #{adapter.label} JSONL found in #{root}" if paths.empty?
    results = []
    plans = []
    errors = []
    seen = {}
    destinations = {}
    paths.each do |path|
      begin
        next if !options[:ids].empty? && !options[:ids].include?(adapter.session_id(path))
        data = adapter.transcript(path)
        next if data[:subagent] || data[:messages].empty?
        suffix = seen.key?(data[:id]) ? "-#{Digest::SHA256.hexdigest(File.basename(path))[0, 12]}" : ''
        output = File.join(directory, "#{adapter.prefix}-#{data[:id]}#{suffix}.md")
        next if options[:since] && !File.exist?(output) && data[:messages].none? { |m| m[:time][0, 10] >= options[:since] }
        raise "Destination collision: #{destinations[output]} and #{path}" if destinations.key?(output)
        destinations[output] = path
        seen[data[:id]] ||= path
        verify_owned(output, path)
        content = adapter.render(data)
        previous = File.exist?(output) ? File.binread(output) : nil
        changed = previous != content.b
        plans << [output, content, previous] if changed
        results << { session_id: data[:id], source: path, destination: output,
                     first_message: data[:messages].first[:time], last_message: data[:messages].last[:time],
                     messages: data[:messages].size, incomplete_tail: data[:tail],
                     status: changed ? 'would_save' : 'unchanged' }
      rescue StandardError => e
        errors << e.message
      end
    end
    missing = options[:ids] - results.map { |r| r[:session_id] }
    errors << "Requested sessions not imported: #{missing.join(', ')}" unless missing.empty?
    if options[:apply] && errors.empty?
      FileUtils.mkdir_p(directory, mode: 0o700)
      plans.each do |path, content, previous|
        current = File.exist?(path) ? File.binread(path) : nil
        raise "Destination changed during import; preserved: #{path}" if File.symlink?(path) || current != previous
        atomic_write(path, content)
      end
      results.each { |r| r[:status] = 'saved' if r[:status] == 'would_save' }
      atomic_write(baseline_path, JSON.generate({ since: options[:since] }) + "\n") if options[:since] && !baseline
    end
    puts JSON.pretty_generate({ apply: options[:apply], since: options[:since], sessions: results, errors: errors })
    errors.empty? ? 0 : 1
  ensure
    lock&.close
  end

  def main(adapter)
    exit run(ARGV, adapter)
  rescue StandardError => e
    warn e.message
    exit 1
  end
end
