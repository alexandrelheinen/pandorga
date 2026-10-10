# frozen_string_literal: true

# Home hero summary from content/pages/cv/summary.md.
# That paragraph is the LCP element. Leaving it empty until JSON arrives
# makes most of LCP render delay, and a guessed empty box shifts the
# call to action when the real text replaces it.
# Refs: PLT-AC-23
module Pandorga
  module HeroSummary
    RELATIVE = "content/pages/cv/summary.md"
    FALLBACK = '<div id="home-cv-summary" class="home-hero-summary font-body" ' \
               'data-content-fragment="cv/summary" data-content-quiet></div>'

    module_function

    def markdown(source_root)
      root = File.expand_path(source_root.to_s)
      path = File.expand_path(RELATIVE, root)
      prefix = root.end_with?(File::SEPARATOR) ? root : root + File::SEPARATOR
      return "" unless path.start_with?(prefix)
      return "" unless File.file?(path)

      strip_front_matter(File.read(path, encoding: "UTF-8")).strip
    end

    def strip_front_matter(text)
      text = text.to_s.sub(/\A\xEF\xBB\xBF/, "")
      return text unless text.start_with?("---\n")

      parts = text.split(/^---\s*$\n?/, 3)
      return text unless parts.length == 3

      parts[2]
    end

    def html_for(site)
      text = markdown(site.source)
      return "" if text.empty?

      converter = site.find_converter_instance(::Jekyll::Converters::Markdown)
      converter.convert(text).to_s.strip
    end

    def element(html)
      body = html.to_s.strip
      return FALLBACK if body.empty?

      %(<div id="home-cv-summary" class="home-hero-summary font-body" data-content-static>#{body}</div>)
    end
  end
end
