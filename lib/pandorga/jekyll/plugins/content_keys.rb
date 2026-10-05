# frozen_string_literal: true

require "date"
require "pathname"
require "yaml"

require_relative "git_chronology"
require_relative "content_detail_paths"
require_relative "content_writing_paths"

# Canonical content identity and public detail URLs for articles, posts,
# projects, and products. The front-matter `key` is the stable cross-reference
# identifier; public path segments are derived from `key` (and Git `date` for
# dated writing).
module ContentKeys
  KEYED_TYPES = %w[article post project product].freeze

  TYPE_CONFIG = {
    "article" => { dated: true, detail: :article_detail_path },
    "post" => { dated: true, detail: :post_detail_path },
    "project" => { dated: false, detail: :project_detail_path },
    "product" => { dated: false, detail: :product_detail_path }
  }.freeze

  CONTENT_PATHS = ContentWritingPaths::BY_TYPE.transform_values { |rel| File.join(ContentWritingPaths::CONTENT_ROOT_SEGMENT, rel) }.merge(
    "project" => "content/collections/projects",
    "product" => "content/collections/products"
  ).freeze

  REDIRECTS_BEGIN = "# BEGIN content-key redirects (generated — do not edit)"
  REDIRECTS_END = "# END content-key redirects (generated — do not edit)"

  # Cloudflare Pages first-match wins. Specific 301s must sit above these
  # SPA catch-alls or old slugs are rewritten with HTTP 200 and never redirect.
  CATCHALL_200_PREFIXES = %w[/articles/:slug /posts/:slug /blog/:slug].freeze

  class ValidationError < StandardError; end

  module_function

  def normalize_key(value)
    value.to_s.strip
  end

  def normalize_date(value)
    case value
    when Date then value.iso8601
    when Time then value.to_date.iso8601
    when String
      value.strip[0, 10]
    else
      value&.to_s&.strip&.[](0, 10)
    end
  end

  def filename_stem(path)
    File.basename(path.to_s, File.extname(path.to_s))
  end

  def infer_key_from_filename(path, type)
    stem = filename_stem(path)
    config = TYPE_CONFIG.fetch(type)
    config[:dated] ? stem.sub(/\A\d{4}-\d{2}-\d{2}-/, "") : stem
  end

  def path_segment(type, key, date: nil)
    normalized_key = normalize_key(key)
    config = TYPE_CONFIG.fetch(type)
    return normalized_key unless config[:dated]

    day = normalize_date(date)
    raise ValidationError, "dated content requires a publication date (key=#{normalized_key})" if day.nil? || day.empty?

    "#{day}-#{normalized_key}"
  end

  def detail_path(type, key, date: nil)
    segment = path_segment(type, key, date: date)
    ContentDetailPaths.public_send(TYPE_CONFIG.fetch(type).fetch(:detail), segment)
  end

  def split_front_matter(text)
    text = text.to_s.sub(/\A\xEF\xBB\xBF/, "")
    return [{}, text] unless text.start_with?("---\n")

    parts = text.split(/^---\s*$\n?/, 3)
    return [{}, text] unless parts.length == 3

    data = YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
    [data, parts[2]]
  end

  def load_entry(absolute_path, type, repo_root: Pathname.pwd)
    text = File.read(absolute_path).sub(/\A\xEF\xBB\xBF/, "")
    front_matter, = split_front_matter(text)
    relative_source = Pathname.new(absolute_path).relative_path_from(repo_root.join("content")).to_s
    repo_relative_path = Pathname.new("content").join(relative_source).to_s

    if KEYED_TYPES.include?(type)
      GitChronology.apply!(front_matter, repo_relative_path, type) if %w[article post].include?(type)
    end

    key = normalize_key(front_matter["key"])
    date = front_matter["date"]
    legacy_segment = filename_stem(absolute_path)

    {
      "type" => type,
      "path" => absolute_path.to_s,
      "repo_relative_path" => repo_relative_path,
      "key" => key,
      "date" => date,
      "legacy_segment" => legacy_segment,
      "path_segment" => key.empty? ? nil : path_segment(type, key, date: date),
      "detail_path" => key.empty? ? nil : detail_path(type, key, date: date),
      "redirects" => normalize_redirects(front_matter),
      "published" => front_matter["published"] != false
    }
  end

  def collect_entries(repo_root = Pathname.pwd)
    entries = []
    CONTENT_PATHS.each do |type, relative_dir|
      directory = repo_root.join(relative_dir)
      next unless directory.directory?

      Dir.glob(directory.join("*.{md,markdown}")).sort.each do |absolute_path|
        entries << load_entry(absolute_path, type, repo_root: repo_root)
      end
    end
    entries
  end

  def published_entries(repo_root = Pathname.pwd)
    collect_entries(repo_root).select { |entry| entry["published"] }
  end

  def validate!(repo_root = Pathname.pwd)
    errors = []
    published = published_entries(repo_root)
    by_key = Hash.new { |hash, key| hash[key] = [] }

    published.each do |entry|
      key = entry["key"]
      label = "#{entry["type"]} #{entry["repo_relative_path"]}"

      if key.empty?
        errors << "#{label}: missing required non-empty `key`"
        next
      end

      begin
        entry["path_segment"] = path_segment(entry["type"], key, date: entry["date"])
        entry["detail_path"] = detail_path(entry["type"], key, date: entry["date"])
      rescue ValidationError => e
        errors << "#{label}: #{e.message}"
        next
      end

      by_key[key] << label
    end

    by_key.each do |key, labels|
      next if labels.length < 2

      errors << "duplicate key #{key.inspect} used by: #{labels.join(', ')}"
    end

    return if errors.empty?

    errors.each { |message| warn "ContentKeys: #{message}" }
    raise ValidationError, "Content key validation failed with #{errors.length} error(s)"
  end

  def normalize_redirects(front_matter)
    values = []
    %w[redirects redirect_from].each do |field|
      raw = front_matter[field]
      case raw
      when Array
        values.concat(raw)
      when String
        values << raw unless raw.strip.empty?
      end
    end
    values.map { |value| normalize_redirect_path(value) }.compact.uniq
  end

  def normalize_redirect_path(path)
    value = path.to_s.strip
    return nil if value.empty?

    value = "/#{value}" unless value.start_with?("/")
    value = value.chomp("/")
    value
  end

  def redirect_rules(entries = nil)
    entries ||= published_entries
    rules = []

    entries.each do |entry|
      next if entry["detail_path"].nil?

      canonical = entry["detail_path"].chomp("/")
      entry["redirects"].each do |source|
        next if source.nil? || source.empty?
        next if source == canonical

        rules << [source, "#{canonical}/", 301]
        rules << ["#{source}/", "#{canonical}/", 301] unless source.end_with?("/")
      end
    end

    rules.uniq
  end

  def alias_slugs(entry)
    slugs = []
    slugs << entry["legacy_segment"].to_s
    slugs << entry["key"].to_s
    slugs.concat(redirect_path_slugs(entry["redirects"]))
    slugs.concat(compact_dated_slugs(slugs))

    canonical = entry["path_segment"].to_s
    slugs.map { |slug| slug.to_s.strip }.reject(&:empty?).uniq.reject { |slug| slug == canonical }
  end

  def catchall_200_line?(line)
    stripped = line.to_s.strip
    CATCHALL_200_PREFIXES.any? do |prefix|
      stripped.start_with?("#{prefix} ") || stripped.start_with?("#{prefix}/ ")
    end
  end

  def generated_redirects_precede_catchalls?(text)
    begin_at = text.index(REDIRECTS_BEGIN)
    catchall_at = text.lines.find_index { |line| catchall_200_line?(line) }
    return false if begin_at.nil? || catchall_at.nil?

    begin_line = text.lines.find_index { |line| line.include?(REDIRECTS_BEGIN) }
    !begin_line.nil? && begin_line < catchall_at
  end

  def sync_redirects_file!(repo_root = Pathname.pwd, redirects_path: repo_root.join("_redirects"))
    rules = redirect_rules(published_entries(repo_root))
    body = rules.map { |source, target, code| "#{source} #{target} #{code}" }.join("\n")
    block = [REDIRECTS_BEGIN, body, REDIRECTS_END].join("\n").strip

    original = redirects_path.file? ? redirects_path.read : ""
    stripped = if original.include?(REDIRECTS_BEGIN) && original.include?(REDIRECTS_END)
                 original.sub(/#{Regexp.escape(REDIRECTS_BEGIN)}.*?#{Regexp.escape(REDIRECTS_END)}\n*/m, "")
               else
                 original
               end

    updated = insert_generated_redirects(stripped, block)
    redirects_path.write(updated)
  end

  def insert_generated_redirects(text, block)
    lines = text.to_s.lines
    insert_at = catchall_section_start(lines)
    block_text = "#{block.to_s.rstrip}\n"

    if insert_at
      before = lines[0...insert_at]
      after = lines[insert_at..]
      before.pop while before.last && before.last.strip.empty?
      before_text = before.join
      before_text += "\n" if !before_text.empty? && !before_text.end_with?("\n")
      before_text += "\n" unless before_text.empty?
      remainder = after.join.sub(/\A\n+/, "")
      "#{before_text}#{block_text}\n#{remainder}"
    else
      updated = text.to_s.rstrip
      updated.empty? ? block_text : "#{updated}\n\n#{block_text}"
    end
  end

  def catchall_section_start(lines)
    insert_at = lines.find_index { |line| catchall_200_line?(line) }
    return nil unless insert_at

    idx = insert_at
    while idx > 0
      previous = lines[idx - 1].to_s.strip
      break unless previous.empty? || previous.start_with?("#")

      idx -= 1
    end
    idx
  end

  def redirect_path_slugs(paths)
    Array(paths).filter_map do |path|
      segment = path.to_s.split("/").reject(&:empty?).last
      segment unless segment.nil? || segment.empty?
    end
  end

  def compact_dated_slugs(slugs)
    Array(slugs).filter_map do |slug|
      match = slug.to_s.match(/\A(\d{4})-(\d{2})-(\d{2})-(.+)\z/)
      next unless match

      "#{match[1]}#{match[2]}#{match[3]}-#{match[4]}"
    end
  end
end
