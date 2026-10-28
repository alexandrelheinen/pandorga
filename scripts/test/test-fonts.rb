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

DEFAULT_HREF = "https://fonts.googleapis.com/css2?family=Ancizar+Serif:ital,wght@0,400;0,600;1,400" \
               "&family=Marcellus+SC:wght@400;700" \
               "&family=Ancizar+Sans:wght@300;350;400;600" \
               "&family=Courier+Prime:ital,wght@0,400;0,700;1,400;1,700" \
               "&display=swap"

theme = YAML.safe_load(ROOT.join("_data/themes/shared.yml").read).fetch("fonts")
bare = Pandorga::Fonts.resolve(nil, nil)
from_theme = Pandorga::Fonts.resolve(nil, theme)
fail!("unset config dropped the ledger faces") unless Pandorga::Fonts.stylesheet_href(bare) == DEFAULT_HREF
fail!("theme tokens drifted from the ledger faces") unless Pandorga::Fonts.stylesheet_href(from_theme) == DEFAULT_HREF
fail!("default stylesheet href contained Cinzel") if DEFAULT_HREF.include?("Cinzel")

fail!("title stack dropped Ancizar Serif") unless Pandorga::Fonts.css_stack(from_theme, "title") ==
  "'Ancizar Serif', 'Pandorga Ancizar Fallback', serif"
fail!("body stack dropped Ancizar Sans") unless Pandorga::Fonts.css_stack(from_theme, "body") ==
  "'Ancizar Sans', 'Pandorga Ancizar Sans Fallback', sans-serif"
fail!("label stack dropped the metric fallback") unless Pandorga::Fonts.css_stack(from_theme, "label") ==
  "'Marcellus SC', 'Pandorga Label Fallback', serif"
fail!("mono stack dropped Courier Prime") unless Pandorga::Fonts.css_stack(from_theme, "mono").start_with?("'Courier Prime', ui-monospace")

site_faces = Pandorga::Fonts.resolve(
  { "title" => "Cinzel", "body" => { "family" => "Ancizar Serif", "weights" => [300, 400, 600] } },
  theme
)
fail!("Cinzel stack missed its metric fallback") unless Pandorga::Fonts.css_stack(site_faces, "title") ==
  "'Cinzel', 'Pandorga Cinzel Fallback', serif"
fail!("Ancizar stack missed its metric fallback") unless Pandorga::Fonts.css_stack(site_faces, "body") ==
  "'Ancizar Serif', 'Pandorga Ancizar Fallback', sans-serif"

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

# A font rename once replaced the letters "hind" inside the word "behind".
token = "be" + "Newsreader"
broken = []
Dir.glob(ROOT.join("**/*.{css,html,rb,js,mjs,md,liquid,yml}")).each do |path|
  next if path.include?("/studio/assets/")
  next if path.include?("/node_modules/")
  next if path.include?("/_site/")
  next if path.end_with?("test-fonts.rb")
  text = File.read(path)
  next unless text.include?(token)

  broken << Pathname.new(path).relative_path_from(ROOT).to_s
end
fail!("corrupted 'behind' left by a font rename (#{broken.size} files): #{broken.join(', ')}") unless broken.empty?
fail!("code face did not follow mono") unless Pandorga::Fonts.css_stack(custom, "code").start_with?("'IBM Plex Mono'")

kept = Pandorga::Fonts.resolve({ "title" => "Ancizar Serif" }, theme)
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

theme_vars = File.read(File.expand_path("../../_includes/theme/theme-vars.html", __dir__))
fail!("theme-vars.html missing mobile --weight-body rebind (PLT-AC-57 cascade)") unless theme_vars.match?(/@media\s*\(max-width:\s*767px\)[\s\S]*--weight-body:\s*var\(--weight-body-mobile/)

