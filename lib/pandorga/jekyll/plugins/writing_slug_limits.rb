# frozen_string_literal: true

require "pathname"

require_relative "content_writing_paths"

# Slug rules for articles and posts:
# - ASCII only (accents break Cloudflare Pages path matching and R2 JSON keys)
# - Length cap derived from the longest existing article filename slug (34 chars) plus 10
module WritingSlugLimits
  MAX_LENGTH = 44
  NON_ASCII_PATTERN = /[^\x00-\x7F]/

  TRANSLITERATION_MAP = {
    "á" => "a", "à" => "a", "â" => "a", "ã" => "a", "ä" => "a", "å" => "a",
    "é" => "e", "è" => "e", "ê" => "e", "ë" => "e",
    "í" => "i", "ì" => "i", "î" => "i", "ï" => "i",
    "ó" => "o", "ò" => "o", "ô" => "o", "õ" => "o", "ö" => "o",
    "ú" => "u", "ù" => "u", "û" => "u", "ü" => "u",
    "ç" => "c", "ñ" => "n", "ý" => "y", "ÿ" => "y",
    "Á" => "A", "À" => "A", "Â" => "A", "Ã" => "A", "Ä" => "A", "Å" => "A",
    "É" => "E", "È" => "E", "Ê" => "E", "Ë" => "E",
    "Í" => "I", "Ì" => "I", "Î" => "I", "Ï" => "I",
    "Ó" => "O", "Ò" => "O", "Ô" => "O", "Õ" => "O", "Ö" => "O",
    "Ú" => "U", "Ù" => "U", "Û" => "U", "Ü" => "U",
    "Ç" => "C", "Ñ" => "N", "Ý" => "Y"
  }.freeze

  module_function

  def ascii_slug?(slug)
    !slug.match?(NON_ASCII_PATTERN)
  end

  def transliterate_slug(slug)
    slug.chars.map { |char| TRANSLITERATION_MAP.fetch(char, char) }.join
  end

  def collect_errors(repo_root = Pathname.pwd)
    errors = []
    root = Pathname.new(repo_root)

    ContentWritingPaths::BY_TYPE.each do |kind, relative_dir|
      directory = root.join(ContentWritingPaths::CONTENT_ROOT_SEGMENT, relative_dir)
      next unless directory.directory?

      directory.glob("*.{md,markdown}").sort.each do |file|
        slug = file.basename(file.extname).to_s

        unless ascii_slug?(slug)
          suggested = transliterate_slug(slug)
          errors << "#{kind} #{file}: slug '#{slug}' contains non-ASCII characters; rename to '#{suggested}'"
        end

        next if slug.length <= MAX_LENGTH

        errors << "#{kind} #{file}: slug '#{slug}' is #{slug.length} chars (max #{MAX_LENGTH})"
      end
    end

    errors
  end

  def validate!(repo_root = Pathname.pwd)
    errors = collect_errors(repo_root)
    return if errors.empty?

    raise ArgumentError, "Writing slug validation failed:\n  - #{errors.join("\n  - ")}"
  end
end
