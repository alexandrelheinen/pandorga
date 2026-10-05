# frozen_string_literal: true

require "pathname"
require "yaml"

# Generates a build-time references.bib artifact in a temporary build location
# for jekyll-scholar if needed, compiled from YAML entries in content/collections/bibliography/.
# Editors edit YAML in content/collections/bibliography/ (one file per citation key);
# BibTeX is never edited by hand in content/.
module Jekyll
  class BibliographyArtifactGenerator < Generator
    safe true
    priority :highest

    def generate(site)
      source_dir = Pathname.new(site.source).join("content/collections/bibliography")
      return unless source_dir.directory?

      artifact_dir = Pathname.new(site.source).join(".jekyll-cache")
      artifact_dir.mkpath
      artifact_file = artifact_dir.join("generated_references.bib")

      # Decouple blocking I/O from CPU-intensive YAML parsing
      # Pre-read all file contents into memory sequentially
      files = source_dir.glob("*.{yml,yaml}").sort
      file_contents = files.map do |file|
        [file.basename(".*").to_s, file, file.read]
      end

      bib_entries = []
      file_contents.each do |key, file, content|
        begin
          data = YAML.safe_load(content, permitted_classes: [Date, Time], aliases: true) || {}
        rescue StandardError => e
          Jekyll.logger.warn "BibliographyArtifactGenerator:", "Failed to load #{file}: #{e.message}"
          next
        end

        type = data.delete("type") || "misc"
        fields = []
        data.each do |k, v|
          next if v.nil? || v.to_s.empty?
          fields << "  #{k} = {#{v}}"
        end

        bib_entries << "@#{type}{#{key},\n#{fields.join(",\n")}\n}"
      end

      artifact_file.write(bib_entries.join("\n\n"))

      if site.config["scholar"]
        site.config["scholar"]["source"] = ".jekyll-cache"
        site.config["scholar"]["bibliography"] = "generated_references.bib"
      end
    end
  end
end
