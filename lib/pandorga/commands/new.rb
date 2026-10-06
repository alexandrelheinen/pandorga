# frozen_string_literal: true

require "fileutils"
require "optparse"
require "pathname"

module Pandorga
  module Commands
    # Scaffold a new site from examples/minimal.
    class New
      EXCLUDE = %w[
        Gemfile.lock
        _site
        vendor
        .bundle
        _content_json
        .jekyll-cache
      ].freeze

      GEMFILE = <<~RUBY
        # frozen_string_literal: true

        source "https://rubygems.org"

        gem "pandorga", "~> 1.3"
        # Local checkout: gem "pandorga", path: "../pandorga"
        # GitHub tag: gem "pandorga", github: "alexandrelheinen/pandorga", tag: "v1.3.10"
        gem "csv"
        gem "base64"
      RUBY

      def run(argv)
        force = false
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: pandorga new PATH [--force]"
          opts.on("--force", "Overwrite an existing directory") { force = true }
          opts.on("-h", "--help", "Show this help") do
            puts opts
            return 0
          end
        end
        parser.parse!(argv)

        raw = argv[0]
        if raw.nil? || raw.strip.empty?
          warn "error: PATH is required"
          warn parser.banner
          return 1
        end

        dest = Pathname.new(raw).expand_path
        src = Pathname.new(Pandorga.gem_path("examples/minimal"))
        unless src.directory?
          warn "error: scaffold source missing at #{src}"
          return 1
        end

        if dest.exist?
          nonempty = dest.directory? && dest.children.any?
          if nonempty && !force
            warn "error: #{dest} is not empty (pass --force to overwrite)"
            return 1
          end
          if force
            FileUtils.rm_rf(dest)
          elsif dest.file?
            warn "error: #{dest} exists and is a file"
            return 1
          end
        end

        FileUtils.mkdir_p(dest)
        copy_scaffold(src, dest)
        dest.join("Gemfile").write(GEMFILE)

        puts "Created site at #{dest}"
        puts
        puts "Next steps:"
        puts "  cd #{shell_path(dest)}"
        puts "  bundle install"
        puts "  bundle exec pandorga doctor"
        puts "  bundle exec pandorga serve"
        0
      end

      private

      def copy_scaffold(src, dest)
        src.each_child do |child|
          name = child.basename.to_s
          next if EXCLUDE.include?(name)
          next if name == "Gemfile" # rewritten after copy

          target = dest.join(name)
          if child.directory?
            FileUtils.mkdir_p(target)
            copy_scaffold(child, target)
          else
            FileUtils.cp(child, target)
          end
        end
      end

      def shell_path(pathname)
        begin
          pathname.relative_path_from(Pathname.pwd).to_s
        rescue ArgumentError
          pathname.to_s
        end
      end
    end
  end
end
