# frozen_string_literal: true

require_relative "commands/doctor"
require_relative "commands/export"
require_relative "commands/serve"
require_relative "commands/publish"
require_relative "commands/install_functions"
require_relative "commands/studio_schema"

module Pandorga
  # Dispatch for `exe/pandorga`.
  module CLI
    COMMANDS = {
      "doctor" => Commands::Doctor,
      "export" => Commands::Export,
      "serve" => Commands::Serve,
      "publish" => Commands::Publish,
      "install-functions" => Commands::InstallFunctions,
      "studio-schema" => Commands::StudioSchema
    }.freeze

    module_function

    def run(argv)
      command = argv.shift
      if command.nil? || %w[-h --help help].include?(command)
        print_help
        return 0
      end
      if %w[-v --version].include?(command)
        puts "pandorga #{Pandorga::VERSION}"
        return 0
      end

      klass = COMMANDS[command]
      unless klass
        warn "Unknown command: #{command}"
        print_help
        return 1
      end

      klass.new.run(argv)
    end

    def print_help
      puts <<~HELP
        pandorga #{Pandorga::VERSION} — static shell + JSON content platform

        Usage:
          pandorga doctor                 Check site config and environment
          pandorga export [src] [dest]    Export content collections to JSON
          pandorga serve                  Local Jekyll serve with JSON re-export
          pandorga publish                Sync content JSON to R2
          pandorga install-functions      Copy functions/ and studio/ into site root
          pandorga studio-schema          Compose studio/schema.yml from templates

        Options:
          -h, --help      Show this help
          -v, --version   Show version
      HELP
    end
  end
end
