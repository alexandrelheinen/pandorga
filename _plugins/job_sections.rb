# frozen_string_literal: true

# Renders the private CV job body fields to HTML for the print layouts,
# storing the result in doc.data["extended"/"single_page"].
# body_public is not rendered here: the public CV page reads it straight
# from the exported JSON through the client-side runtime.
module Jekyll
  class JobSectionsGenerator < Generator
    safe true
    priority :high

    def generate(site)
      return if site.config["shell_content_agnostic"]

      converter = site.find_converter_instance(Jekyll::Converters::Markdown)

      (site.collections["jobs"]&.docs || []).each do |doc|
        %w[extended single_page].each do |key|
          markdown = doc.data["body_#{key}"].to_s.strip
          doc.data[key] = converter.convert(markdown) unless markdown.empty?
        end
      end
    end
  end
end
