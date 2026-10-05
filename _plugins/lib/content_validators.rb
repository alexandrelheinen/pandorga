# frozen_string_literal: true

require "pathname"

require_relative "resource_validator"
require_relative "tag_validator"
require_relative "../writing_slug_limits"
require_relative "../content_keys"

# Single validation entry point for editorial content under content/.
module ContentValidators
  module_function

  def validate_all!(repo_root = Pathname.pwd)
    root = Pathname.new(repo_root)
    errors = []
    errors.concat(ResourceValidator.collect_errors(root))
    errors.concat(TagValidator.collect_errors(root))
    errors.concat(WritingSlugLimits.collect_errors(root))

    unless errors.empty?
      raise ArgumentError, "Content validation failed:\n  - #{errors.join("\n  - ")}"
    end

    ContentKeys.validate!(root)
  end
end
