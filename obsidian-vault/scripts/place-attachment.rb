# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'
require_relative 'resolve-vault'

module ObsidianAttachment
  module_function

  PLUGIN_ID = 'obsidian-custom-attachment-location'
  DATE_TOKEN = /\$\{date:\{momentJsFormat:'([^']+)'\}\}/
  TOKEN = /\$\{[^}]+\}/

  def place(vault_name, note_path, source_path, now: Time.now)
    vault = ObsidianVault.resolve(vault_name)
    note = vault_file(vault, note_path)
    abort "Note must be an existing Markdown file: #{note_path}" unless File.file?(note) && File.extname(note).downcase == '.md'

    source = File.expand_path(source_path)
    abort "Source must be an existing file: #{source_path}" unless File.file?(source)

    settings = load_settings(vault)
    validate_settings!(settings)
    folder = expand_folder(settings.fetch('attachmentFolderPath'), note, settings)
    stem = expand_file_name(settings.fetch('generatedAttachmentFileName'), note, source, now, settings)
    extension = File.extname(source)
    target = available_path(File.join(folder, "#{stem}#{extension}"), settings.fetch('duplicateNameSeparator'))
    ensure_inside_vault!(vault, target)
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target)
    target.delete_prefix("#{vault}/")
  rescue JSON::ParserError, KeyError, SystemCallError => error
    abort "Cannot place Obsidian attachment: #{error.message}"
  end

  def load_settings(vault)
    path = File.join(vault, '.obsidian/plugins', PLUGIN_ID, 'data.json')
    JSON.parse(File.read(path))
  end

  def validate_settings!(settings)
    supported = settings.fetch('attachmentRenameMode') == 'All' &&
                settings.fetch('convertImagesToJpegMode') == 'None' &&
                settings.fetch('attachmentUnitFolderPaths').empty?
    abort 'Unsupported Custom Attachment Location settings' unless supported
  end

  def vault_file(vault, relative_path)
    abort "Vault path must be relative: #{relative_path}" if relative_path.start_with?('/')

    path = File.expand_path(relative_path, vault)
    ensure_inside_vault!(vault, path)
    path
  end

  def expand_folder(template, note, settings)
    note_name = sanitize(File.basename(note, '.md'), settings)
    expanded = template.gsub('${noteFileName}', note_name)
    reject_tokens!(expanded)
    base = template.start_with?('./') ? File.dirname(note) : vault_root(note)
    File.expand_path(expanded.delete_prefix('./'), base)
  end

  def expand_file_name(template, note, source, now, settings)
    expanded = template.gsub('${noteFileName}', sanitize(File.basename(note, '.md'), settings))
    expanded = expanded.gsub('${originalAttachmentFileName}', sanitize(File.basename(source, File.extname(source)), settings))
    expanded = expanded.gsub(DATE_TOKEN) { format_date(now, Regexp.last_match(1)) }
    reject_tokens!(expanded)
    sanitize(expanded, settings)
  end

  def format_date(time, format)
    abort "Unsupported Moment.js date format: #{format}" unless format == 'YYYYMMDDHHmmssSSS'

    time.strftime('%Y%m%d%H%M%S') + format('%03d', time.usec / 1000)
  end

  def sanitize(value, settings)
    characters = settings.fetch('specialCharacters')
    replacement = settings.fetch('specialCharactersReplacement')
    value.gsub(/[#{Regexp.escape(characters)}]+/, replacement)
  end

  def reject_tokens!(value)
    token = value[TOKEN]
    abort "Unsupported Custom Attachment Location token: #{token}" if token
  end

  def vault_root(note)
    path = File.dirname(note)
    path = File.dirname(path) until File.directory?(File.join(path, '.obsidian')) || File.dirname(path) == path
    abort 'Cannot find Vault root for note' unless File.directory?(File.join(path, '.obsidian'))

    path
  end

  def ensure_inside_vault!(vault, path)
    expanded_vault = File.expand_path(vault)
    expanded_path = File.expand_path(path)
    return if expanded_path.start_with?("#{expanded_vault}/")

    abort "Path escapes the Vault: #{path}"
  end

  def available_path(path, separator)
    return path unless File.exist?(path)

    extension = File.extname(path)
    stem = path.delete_suffix(extension)
    number = 1
    number += 1 while File.exist?("#{stem}#{separator}#{number}#{extension}")
    "#{stem}#{separator}#{number}#{extension}"
  end
end

if $PROGRAM_NAME == __FILE__
  abort 'usage: place-attachment.rb <vault-name> <vault-relative-note.md> <source-file>' unless ARGV.size == 3
  now = ENV['OBSIDIAN_ATTACHMENT_TIME'] ? Time.iso8601(ENV.fetch('OBSIDIAN_ATTACHMENT_TIME')) : Time.now
  puts ObsidianAttachment.place(*ARGV, now: now)
end
