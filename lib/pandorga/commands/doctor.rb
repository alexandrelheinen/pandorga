# frozen_string_literal: true

require "yaml"
require "pathname"
require "date"

module Pandorga
  module Commands
    # Sanity-check a site directory for pandorga configuration.
    class Doctor
      def run(argv)
        root = Pathname.new(argv[0] || Dir.pwd).expand_path
        errors = []
        warnings = []

        config_path = root.join("_config.yml")
        unless config_path.file?
          warn "error: no _config.yml in #{root}"
          return 1
        end

        config = YAML.safe_load(config_path.read, permitted_classes: [Date]) || {}
        pandorga = config["pandorga"]
        unless pandorga.is_a?(Hash)
          errors << "missing top-level `pandorga:` key (identity, content, pages)"
        else
          identity = pandorga["identity"]
          if !identity.is_a?(Hash) || identity["name"].to_s.strip.empty?
            errors << "pandorga.identity.name is required"
          end
          pages = pandorga["pages"]
          if pages.nil?
            warnings << "pandorga.pages is empty — no pages will be generated"
          elsif !pages.is_a?(Array)
            errors << "pandorga.pages must be an array"
          else
            keys = pages.map { |p| p.is_a?(Hash) ? p["key"] : nil }
            dup = keys.compact.group_by(&:itself).select { |_, v| v.size > 1 }.keys
            errors << "duplicate page keys: #{dup.join(', ')}" if dup.any?
            pages.each_with_index do |page, i|
              next unless page.is_a?(Hash)

              errors << "pages[#{i}]: missing key" if page["key"].to_s.empty?
              errors << "pages[#{i}] (#{page['key']}): missing template" if page["template"].to_s.empty?
            end
          end
        end

        gemfile = root.join("Gemfile")
        warnings << "Gemfile does not mention pandorga" if gemfile.file? && !gemfile.read.include?("pandorga")

        if errors.empty? && warnings.empty?
          puts "pandorga doctor: ok (#{root})"
          return 0
        end

        warnings.each { |w| warn "warning: #{w}" }
        errors.each { |e| warn "error: #{e}" }
        return 1 if errors.any?

        puts "pandorga doctor: ok with warnings (#{root})"
        0
      end
    end
  end
end
