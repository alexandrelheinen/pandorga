# frozen_string_literal: true

require_relative "jekyll/generator"

# Auto-loaded when listed under `plugins: [pandorga]` in _config.yml.
Liquid::Template.error_mode = :strict if defined?(Liquid)
