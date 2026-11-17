# frozen_string_literal: true

require 'date'
require_relative '../../obsidian-vault/scripts/resolve-vault'

abort 'usage: find-recent-daily-notes.rb [YYYY-MM-DD]' if ARGV.size > 1
today = ARGV.empty? ? Time.now.getlocal('+09:00').to_date : Date.iso8601(ARGV.first)
daily = File.join(ObsidianVault.resolve, 'daily')
abort "Daily directory not found: #{daily}" unless File.directory?(daily)

dates = (today.monday? ? [3, 2, 1] : (1..7)).filter_map do |offset|
  date = today - offset
  date if File.file?(File.join(daily, "#{date}.md"))
end
dates = dates.first(1) unless today.monday?
puts dates
exit(dates.empty? ? 1 : 0)
