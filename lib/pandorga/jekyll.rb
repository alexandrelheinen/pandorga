# frozen_string_literal: true

require_relative "jekyll/generator"

# Load migrated site plugins (generators, hooks) shipped inside the gem.
plugins_root = File.expand_path("jekyll/plugins", __dir__)
if File.directory?(plugins_root)
  # lib/ helpers first
  lib_dir = File.join(plugins_root, "lib")
  Dir[File.join(lib_dir, "*.rb")].sort.each { |path| require path } if File.directory?(lib_dir)
  Dir[File.join(plugins_root, "*.rb")].sort.each { |path| require path }
end

# Auto-loaded when listed under `plugins: [pandorga]` in _config.yml.
Liquid::Template.error_mode = :strict if defined?(Liquid)
