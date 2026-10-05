# frozen_string_literal: true

require "pathname"

require_relative "lib/content_validators"

# Editorial validation for content-aware builds only. Public Pages shells set
# shell_content_agnostic and skip this — gates live in validate.sh / export.
module Jekyll
  class ContentValidatorsHook < Generator
    safe true
    priority :highest

    def generate(site)
      return if site.config["shell_content_agnostic"]

      ContentValidators.validate_all!(Pathname.new(site.source))
    end
  end
end
