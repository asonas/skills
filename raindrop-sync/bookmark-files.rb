# frozen_string_literal: true

# File identity comes from frontmatter, independently of the article title.
module BookmarkFiles
  def self.key(name)
    name.unicode_normalize(:nfc).downcase
  end

  def self.metadata(path)
    header = File.read(path).split(/^---\s*$\n?/, 3)[1].to_s
    id = header[/^raindrop_id: (\d+)\s*$/, 1]
    title = header[/^title: (.*)$/, 1].to_s.strip
    # Read the sync writer's single-line string format, including its legacy
    # unescaped backslashes. Other metadata may contain malformed legacy YAML.
    title = title[1...-1].gsub('\\"', '"') if title.start_with?('"') && title.end_with?('"')
    { id: id, title: title }
  end

  def self.stem(title)
    value = title.to_s.unicode_normalize(:nfc)
      .gsub(/[\x00-\x1f\x7f\/\\:*?"<>|#\[\]^]/, ' ')
      .gsub(/\s+/, ' ').strip.sub(/\A\.+/, '').sub(/[. ]+\z/, '')
    value = 'Untitled bookmark' if value.empty?
    shortened = +''
    value.each_char do |char|
      break if shortened.bytesize + char.bytesize > 180
      shortened << char
    end
    shortened.strip.sub(/[. ]+\z/, '')
  end

  class Catalog
    def initialize(vault)
      @directory = File.join(vault, 'bookmarks')
      @by_id = {}
      @names = {}
      Dir.glob(File.join(vault, '**', '*.md')).each do |path|
        @names[BookmarkFiles.key(File.basename(path))] = true
        next unless File.dirname(path) == @directory
        id = BookmarkFiles.metadata(path)[:id]
        raise "Missing raindrop_id: #{path}" unless id
        raise "Duplicate raindrop_id: #{id}" if @by_id.key?(id)
        @by_id[id] = path
      end
    end

    def path_for(id, title, migrate: false)
      id = id.to_s
      raise 'Invalid raindrop_id' unless id.match?(/\A\d+\z/)
      existing = @by_id[id]
      return existing if existing && (!migrate || File.basename(existing) != "#{id}.md")
      stem = BookmarkFiles.stem(title)
      name = "#{stem}.md"
      name = "#{stem} (#{id}).md" if @names[BookmarkFiles.key(name)]
      suffix = 2
      while @names[BookmarkFiles.key(name)]
        name = "#{stem} (#{id}-#{suffix}).md"
        suffix += 1
      end
      @names[BookmarkFiles.key(name)] = true
      @by_id[id] = File.join(@directory, name)
    end
  end
end
