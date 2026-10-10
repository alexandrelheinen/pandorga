# frozen_string_literal: true

require_relative "../../fonts"

# Liquid filters for pandorga.fonts. The stylesheet URL and the CSS stacks
# come from one resolver so the head and the tokens cannot drift.
module PandorgaFontFilter
  def pandorga_font_stylesheet(site)
    Pandorga::Fonts.stylesheet_href(Pandorga::Fonts.from_site(site))
  end

  def pandorga_font_stack(site, role)
    Pandorga::Fonts.css_stack(Pandorga::Fonts.from_site(site), role)
  end
end

Liquid::Template.register_filter(PandorgaFontFilter) if defined?(Liquid::Template)
