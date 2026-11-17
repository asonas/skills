require 'tmpdir'
require 'fileutils'
require_relative 'bookmark-files'

def assert(condition, message)
  raise message unless condition
end

Dir.mktmpdir do |vault|
  dir = File.join(vault, 'bookmarks')
  FileUtils.mkdir_p([dir, File.join(vault, 'wiki')])
  File.write(File.join(dir, '123.md'), "---\nraindrop_id: 123\ntitle: \"古い記事\"\ndefuddle_status: error: legacy\n---\nbody\n")
  File.write(File.join(vault, 'wiki', 'Same.md'), 'existing')
  c = BookmarkFiles::Catalog.new(vault)
  assert(c.path_for(123, 'changed') == File.join(dir, '123.md'), 'legacy identity lost')
  moved = c.path_for(123, '古い記事', migrate: true)
  assert(File.basename(moved) == '古い記事.md', 'migration title wrong')
  File.rename(File.join(dir, '123.md'), moved)
  c = BookmarkFiles::Catalog.new(vault)
  assert(c.path_for(123, 'new title') == moved, 'title update broke existing link')
  assert(File.basename(c.path_for(124, 'same')) == 'same (124).md', 'vault-wide collision')
  a = c.path_for(125, '記事')
  b = c.path_for(126, '記事')
  assert(a != b && b.end_with?('記事 (126).md'), 'duplicate title overwritten')
  assert(c.path_for(126, 'changed') == b, 'same batch identity lost')
  assert(BookmarkFiles.stem('a/b:c [[d]] #e | f').match?(/\Aa b c d e f\z/), 'unsafe punctuation')
  assert(BookmarkFiles.stem('...') == 'Untitled bookmark', 'empty title')
  long = BookmarkFiles.stem('日' * 200)
  assert(long.valid_encoding? && long.bytesize <= 180, 'multibyte truncation')
  assert(BookmarkFiles.key("e\u0301.md") == BookmarkFiles.key('é.md'), 'unicode collision')
  assert(BookmarkFiles.metadata(moved)[:title] == '古い記事', 'legacy metadata parsing')
  File.write(File.join(dir, 'duplicate.md'), File.read(moved))
  begin
    BookmarkFiles::Catalog.new(vault)
    raise 'duplicate id silently accepted'
  rescue RuntimeError => e
    raise unless e.message.start_with?('Duplicate raindrop_id:')
  end
end
puts 'PASS: identity, migration, title changes, collisions, Unicode, legacy metadata, duplicate ID protection'
