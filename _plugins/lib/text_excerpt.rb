# frozen_string_literal: true

# Plain-text listing excerpt from editorial Markdown.
# Mirrors textExcerpt() in _includes/content-runtime/40-listing.html closely
# enough for card previews. Liquid includes are stripped rather than rendered.
module TextExcerpt
  LIMIT = 220

  module_function

  def from_markdown(markdown, limit: LIMIT)
    text = markdown.to_s.sub(/\A\xEF\xBB\xBF/, "")
    text = strip_non_prose(text)
    text = flatten_markup(text)
    text = text.gsub(/\s+/, " ").strip
    truncate(text, limit)
  end

  def listing_fields(front_matter, body)
    editorial = front_matter["description"].to_s.strip
    excerpt = from_markdown(body)
    {
      "description" => editorial,
      "excerpt" => excerpt
    }
  end

  def strip_non_prose(text)
    text = text.gsub(/<!--[\s\S]*?-->/, " ")
    text = text.gsub(/\{%-?[\s\S]*?-?%\}/, " ")
    text = text.gsub(/\$\$[\s\S]*?\$\$/, " ")
    text = text.gsub(/\$[^$\n]+\$/, " ")
    text = text.gsub(/\\\[[\s\S]*?\\\]/, " ")
    text = text.gsub(/\\\([\s\S]*?\\\)/, " ")
    text.gsub(/```[\s\S]*?```/, " ")
  end

  def flatten_markup(text)
    text = text.gsub(/!\[([^\]]*)\]\([^)]+\)/, ' \1 ')
    text = text.gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
    text = text.gsub(/^\#{1,6}\s+(.+?)\s*$/) { "#{Regexp.last_match(1).sub(/:+\s*\z/, "")}: " }
    text = text.gsub(/<br\s*\/?>/i, " ")
    text = text.gsub(/<[^>]+>/, " ")
    text = text.gsub(/[*_~`]+/, "")
    text = text.gsub(/^\s*>\s+/, "")
    text = text.gsub(/^\s*[-*+]\s+/, "")
    text = text.gsub(/^\s*\d+\.\s+/, "")
    text.gsub(/\|/, " ")
  end

  def truncate(text, limit)
    return text if text.length <= limit

    "#{text[0, [limit - 3, 0].max].rstrip}..."
  end
end
