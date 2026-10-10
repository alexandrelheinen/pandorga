#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-30. A site names its Google Fonts families in pandorga.fonts.
# Omitted roles keep Cinzel Decorative, Newsreader, and Courier Prime.

require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-fonts: #{message}"
  exit 1
end

require_relative "../../lib/pandorga/fonts"

DEFAULT_HREF = "https://fonts.googleapis.com/css2?family=Cinzel+Decorative:wght@400;700;900" \
               "&family=Marcellus+SC:wght@400;700" \
               "&family=Newsreader:wght@300;400;500;600;700" \
               "&family=Courier+Prime:ital,wght@0,400;0,700;1,400;1,700" \
               "&display=swap"

theme = YAML.safe_load(ROOT.join("_data/themes/shared.yml").read).fetch("fonts")
bare = Pandorga::Fonts.resolve(nil, nil)
from_theme = Pandorga::Fonts.resolve(nil, theme)
fail!("unset config dropped the ledger faces") unless Pandorga::Fonts.stylesheet_href(bare) == DEFAULT_HREF
fail!("theme tokens drifted from the ledger faces") unless Pandorga::Fonts.stylesheet_href(from_theme) == DEFAULT_HREF

fail!("title stack dropped Cinzel") unless Pandorga::Fonts.css_stack(from_theme, "title") == "'Cinzel Decorative', serif"
fail!("body stack dropped the serif fallback") unless Pandorga::Fonts.css_stack(from_theme, "body") == "'Newsreader', Georgia, serif"
fail!("mono stack dropped Courier Prime") unless Pandorga::Fonts.css_stack(from_theme, "mono").start_with?("'Courier Prime', ui-monospace")

custom = Pandorga::Fonts.resolve(
  {
    "title" => "Fraunces",
    "body" => { "family" => "Source Serif 4", "weights" => [600, 400, 400] },
    "mono" => { "family" => "IBM Plex Mono", "weights" => [400, 500], "italic" => true }
  },
  theme
)
custom_href = Pandorga::Fonts.stylesheet_href(custom)
fail!("custom title was not requested") unless custom_href.include?("family=Fraunces:wght@400;700")
fail!("custom title kept the Cinzel axis") if custom_href.include?("Cinzel")
fail!("body weights were not sorted") unless custom_href.include?("family=Source+Serif+4:wght@400;600")
fail!("mono italic axis is wrong") unless custom_href.include?("family=IBM+Plex+Mono:ital,wght@0,400;0,500;1,400;1,500")
fail!("unset label left Marcellus") unless custom_href.include?("family=Marcellus+SC:wght@400;700")
fail!("body change left the tagline on Newsreader") unless Pandorga::Fonts.css_stack(custom, "subtitle").start_with?("'Source Serif 4'")
fail!("code face did not follow mono") unless Pandorga::Fonts.css_stack(custom, "code").start_with?("'IBM Plex Mono'")

kept = Pandorga::Fonts.resolve({ "title" => "Cinzel Decorative" }, theme)
fail!("naming the default title changed the stylesheet") unless Pandorga::Fonts.stylesheet_href(kept) == DEFAULT_HREF

ignored = Pandorga::Fonts.resolve({ "title" => "Fraunces</style>" }, theme)
fail!("a broken family name was accepted") unless Pandorga::Fonts.stylesheet_href(ignored) == DEFAULT_HREF

example = YAML.safe_load(ROOT.join("examples/full/_config.yml").read)
example_fonts = example.dig("pandorga", "fonts")
fail!("full example has no pandorga.fonts") unless example_fonts.is_a?(Hash)
fail!("full example changed the measured faces") unless Pandorga::Fonts.stylesheet_href(Pandorga::Fonts.resolve(example_fonts, theme)) == DEFAULT_HREF

loader = ROOT.join("_includes/theme/font-loader.html").read
shell = ROOT.join("_layouts/shell.html").read
fail!("loader no longer hands the href to the shell") unless loader.include?("__pandorgaFontsHref")
fail!("loader preloads the text faces") if loader.include?('rel="preload"')
fail!("text faces wait for the load event") if loader.include?("addEventListener('load'")
preconnect_at = shell.index("fonts.googleapis.com")
script_at = shell.index("theme/critical-preload.html")
fail!("font host is not preconnected before the preload script") unless preconnect_at && script_at && preconnect_at < script_at
fail!("text faces are not requested after the first paint") unless shell.include?("requestAnimationFrame") && shell.include?("__pandorgaFontsHref")

spec = ROOT.join("docs/spec.md").read
fail!("spec is missing PLT-AC-30") unless spec.include?("PLT-AC-30")
fail!("configuration reference omits pandorga.fonts") unless ROOT.join("docs/configuration.md").read.include?("pandorga.fonts")

puts "PASS test-fonts"
