# frozen_string_literal: true

require "pathname"
require "yaml"

# Shared resource collection validation (content/ source, not Jekyll collections).
module ResourceValidator
  module_function

  def split_front_matter(text)
    text = text.to_s.sub(/\A\xEF\xBB\xBF/, "")
    return [{}, text] unless text.start_with?("---\n")

    parts = text.split(/^---\s*$\n?/, 3)
    return [{}, text] unless parts.length == 3

    data = YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
    [data, parts[2]]
  end

  def collect_errors(repo_root)
    root = Pathname.new(repo_root)
    resources_dir = root.join("content/collections/resources")
    return [] unless resources_dir.directory?

    errors = []
    resources_dir.glob("*.{md,markdown}").sort.each do |source|
      front_matter, = split_front_matter(source.read)
      name = front_matter["name"] || source.basename(source.extname).to_s
      type = front_matter["type"].to_s.downcase
      link = front_matter["link"].to_s

      if link.empty?
        errors << "#{name}: missing required 'link' field"
        next
      end

      case type
      when "youtube"
        unless link.match?(%r{\Ahttps?://(www\.)?(youtube\.com|youtu\.be)/}i)
          errors << "#{name}: type 'youtube' but link does not point to youtube.com or youtu.be (got: #{link})"
        end
      when "spotify"
        unless link.match?(%r{\Ahttps?://(open\.)?spotify\.com/}i)
          errors << "#{name}: type 'spotify' but link does not point to spotify.com (got: #{link})"
        end
      when "pdf"
        unless link.end_with?(".pdf")
          errors << "#{name}: type 'pdf' but link does not end with .pdf (got: #{link})"
        end
      end
    end

    errors
  end
end
