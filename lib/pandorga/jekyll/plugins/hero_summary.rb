# frozen_string_literal: true

require "jekyll"
require_relative "../../hero_summary"

module Pandorga
  # Emits the hero summary element. HTML is raw so the paragraph is in the
  # first response when the markdown file exists.
  class HeroSummaryTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      HeroSummary.element(HeroSummary.html_for(site))
    end
  end
end

Liquid::Template.register_tag("pandorga_hero_summary", Pandorga::HeroSummaryTag)
