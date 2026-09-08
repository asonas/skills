# frozen_string_literal: true

require 'json'

module ObsidianVault
  module_function

  def resolve(name = 'asonas', path: ENV['OBSIDIAN_VAULT'])
    config = ENV.fetch('OBSIDIAN_CONFIG') {
      File.expand_path('~/Library/Application Support/obsidian/obsidian.json')
    }
    begin
      data = JSON.parse(File.read(config))
      vaults = data.fetch('vaults')
    rescue JSON::ParserError, KeyError, SystemCallError => error
      abort "Cannot read Obsidian registration: #{error.message}"
    end
    abort 'Invalid Obsidian vault registry' unless vaults.is_a?(Hash)
    matches = vaults.values.select do |entry|
      entry.is_a?(Hash) && entry['path'].is_a?(String) && File.basename(entry['path']) == name
    end
    abort "Expected one registered vault named #{name}; found #{matches.size}" unless matches.size == 1

    registered = matches.first.fetch('path')
    unless registered.start_with?('/') && File.directory?(File.join(registered, '.obsidian'))
      abort "Registered vault is missing or invalid: #{registered}"
    end
    resolved = File.realpath(registered)
    if path && (path.empty? || !File.directory?(path) || File.realpath(path) != resolved)
      abort "Explicit vault path does not match registered vault #{name}: #{path}"
    end
    resolved
  end
end

if $PROGRAM_NAME == __FILE__
  abort 'usage: resolve-vault.rb [vault-name]' if ARGV.size > 1
  puts ObsidianVault.resolve(ARGV.fetch(0, 'asonas'))
end
