# frozen_string_literal: true

require "jekyll"
require_relative "../../hero_summary"

module Pandorga
  # Emits the hero summary element. HTML is raw so the paragraph is in the
  # first response when the markdown file exists. A blank hero file
  # renders nothing (PLT-AC-54).
  class HeroSummaryTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      return "" if HeroSummary.hidden?(site.source)

      HeroSummary.element(HeroSummary.html_for(site))
    end
  end
end

Liquid::Template.register_tag("pandorga_hero_summary", Pandorga::HeroSummaryTag)
