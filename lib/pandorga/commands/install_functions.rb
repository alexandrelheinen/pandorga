# frozen_string_literal: true

require "fileutils"
require "pathname"

module Pandorga
  module Commands
    # Option A (PLT-0.2): copy functions/ and studio/ from the gem into the site root
    # so Cloudflare Pages can compile Functions from the project root.
    class InstallFunctions
      STAMP = ".pandorga-version"

      def run(argv)
        dest_root = Pathname.new(argv[0] || Dir.pwd).expand_path
        gem_functions = Pathname.new(Pandorga.gem_path("functions"))
        gem_studio = Pathname.new(Pandorga.gem_path("studio"))

        unless gem_functions.directory?
          warn "error: gem has no functions/ directory at #{gem_functions}"
          return 1
        end

        copy_tree(gem_functions, dest_root.join("functions"))
        copy_tree(gem_studio, dest_root.join("studio")) if gem_studio.directory?

        stamp = dest_root.join("functions", STAMP)
        stamp.write("#{Pandorga::VERSION}\n")
        puts "pandorga install-functions: copied to #{dest_root} (v#{Pandorga::VERSION})"
        0
      end

      private

      def copy_tree(src, dest)
        FileUtils.rm_rf(dest) if dest.exist?
        FileUtils.mkdir_p(dest.dirname)
        FileUtils.cp_r(src, dest)
      end
    end
  end
end
