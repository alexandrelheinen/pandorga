# frozen_string_literal: true

require_relative "pandorga/version"

# Pandorga — Jekyll theme, plugin, and CLI for a static shell with JSON content.
module Pandorga
  class Error < StandardError; end

  ROOT = File.expand_path("..", __dir__)

  def self.gem_path(*parts)
    File.join(ROOT, *parts)
  end
end

require_relative "pandorga/registry"

# Jekyll loads this file as a plugin when `plugins: [pandorga]`.
require_relative "pandorga/jekyll" if defined?(Jekyll)
