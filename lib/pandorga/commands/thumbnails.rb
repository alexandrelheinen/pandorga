# frozen_string_literal: true

require "pathname"
require_relative "../thumbnail_variants"

module Pandorga
  module Commands
    # Generate 16:9 center-cropped width variants for local project thumbnails.
    # Refs: PLT-AC-44
    class Thumbnails
      def run(argv)
        site_root = Pathname.new(argv[0] || Dir.pwd).expand_path
        summary = Pandorga::ThumbnailVariants.generate(site_root)
        puts "pandorga thumbnails: #{summary[:written]} written, #{summary[:skipped]} skipped (#{summary[:sources]} sources in #{site_root})"
        0
      end
    end
  end
end
