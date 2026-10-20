#!/usr/bin/env ruby
# frozen_string_literal: true

# Dark tertiary container text must clear WCAG AA for normal text.
# PLT-AC-33

require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-theme-contrast: #{message}"
  exit 1
end

def channel(value)
  value = value / 255.0
  value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
end

def luminance(hex)
  rgb = hex.delete("#").scan(/../).map { |part| part.to_i(16) }
  fail!("not a hex colour: #{hex}") unless rgb.length == 3

  (0.2126 * channel(rgb[0])) + (0.7152 * channel(rgb[1])) + (0.0722 * channel(rgb[2]))
end

def contrast(foreground, background)
  lighter, darker = [luminance(foreground), luminance(background)].sort.reverse
  (lighter + 0.05) / (darker + 0.05)
end

dark = YAML.safe_load(ROOT.join("_data/themes/dark.yml").read) || {}
colors = dark["colors"] || {}
background = colors["tertiary_container"].to_s
foreground = colors["on_tertiary_container"].to_s
fail!("dark tertiary container moved") unless background.casecmp("#6a684f").zero?

ratio = contrast(foreground, background)
fail!("#{foreground} on #{background} is #{ratio.round(2)}:1") unless ratio >= 4.5

# Footer imprint middot. outline-variant is a hairline and fails as ink
# on the panel step. The separator uses outline, which clears 4.5:1.
footer = ROOT.join("assets/css/ledger/footer.css").read
fail!("footer imprint separator still uses outline-variant") if footer.include?("color: var(--color-outline-variant)")
fail!("footer imprint separator lost outline") unless footer.include?("color: var(--color-outline)")

light = YAML.safe_load(ROOT.join("_data/themes/light.yml").read) || {}
pairs = {
  "light" => [light.dig("neutrals", "outline"), light.dig("neutrals", "panel_contrast")],
  "dark" => [dark.dig("neutrals", "outline"), dark.dig("neutrals", "panel_contrast")]
}
reports = []
pairs.each do |name, (ink, panel)|
  fail!("#{name} outline or panel missing") if ink.to_s.empty? || panel.to_s.empty?

  pair_ratio = contrast(ink, panel)
  fail!("#{name} outline #{ink} on panel #{panel} is #{pair_ratio.round(2)}:1") unless pair_ratio >= 4.5
  reports << "#{name} #{ink} on #{panel} = #{pair_ratio.round(2)}:1"
end

# PLT-AC-46: Highlighter pills contrast assertions.
# For each accent ink and each family's text color and strength, composite the mark head
# over background, surface, and surface_card, then assert >= 4.5:1 WCAG contrast.
def mix(color_a, color_b, percentage)
  rgb_a = color_a.delete("#").scan(/../).map { |p| p.to_i(16) }
  rgb_b = color_b.delete("#").scan(/../).map { |p| p.to_i(16) }
  res = (0..2).map { |i| ((rgb_a[i] * percentage + rgb_b[i] * (100.0 - percentage)) / 100.0).round }
  "#%02x%02x%02x" % res
end

themes = [
  { name: "light", theme: light, menu_strength: 18, strong_strength: 28, facet_strength: 14, quiet_strength: 12 },
  { name: "dark", theme: dark, menu_strength: 14, strong_strength: 22, facet_strength: 14, quiet_strength: 10 }
]

themes.each do |entry|
  mode = entry[:name]
  theme_data = entry[:theme]
  colors = theme_data["colors"] || {}
  neutrals = theme_data["neutrals"] || {}
  accents = [colors["primary"], colors["secondary"], colors["tertiary"]].compact
  surfaces = [neutrals["background"], neutrals["surface"], neutrals["surface_card"]].compact.uniq

  on_surface = neutrals["on_surface"].to_s
  on_variant = neutrals["on_surface_variant"].to_s
  on_primary = (mode == "light") ? "#ffffff" : theme_data.dig("static", "on_primary") || "#0f1a22"

  accents.each do |accent|
    surfaces.each do |bg|
      # F1 / F2: Tags and featured badge
      f1_text = (mode == "light") ? mix(accent, on_surface, 82) : mix(accent, on_surface, 78)
      f1_head = mix(accent, bg, entry[:menu_strength])
      c = contrast(f1_text, f1_head)
      fail!("PLT-AC-46 F1 #{mode} #{accent} on #{bg}: #{c.round(2)}:1 < 4.5:1") if c < 4.5
      c_base = contrast(f1_text, bg)
      fail!("PLT-AC-46 F1 #{mode} #{accent} on bare #{bg}: #{c_base.round(2)}:1 < 4.5:1") if c_base < 4.5

      # F4: Selected filter
      f4_head = mix(accent, bg, entry[:menu_strength])
      c = contrast(on_surface, f4_head)
      fail!("PLT-AC-46 F4 selected #{mode} #{accent} on #{bg}: #{c.round(2)}:1 < 4.5:1") if c < 4.5

      # F5: Emphasis button
      f5_text = (mode == "light") ? mix(accent, on_surface, 82) : accent
      f5_head = mix(accent, bg, entry[:strong_strength])
      c = contrast(f5_text, f5_head)
      fail!("PLT-AC-46 F5 #{mode} #{accent} on #{bg}: #{c.round(2)}:1 < 4.5:1") if c < 4.5

      # Menu M: Active link
      m_head = mix(accent, bg, entry[:menu_strength])
      c = contrast(on_surface, m_head)
      fail!("PLT-AC-46 Menu active #{mode} #{accent} on #{bg}: #{c.round(2)}:1 < 4.5:1") if c < 4.5
    end

    # F6: Solid mark (inverted on-primary text over solid accent at glyph)
    c_f6 = contrast(on_primary, accent)
    fail!("PLT-AC-46 F6 #{mode} #{on_primary} on #{accent}: #{c_f6.round(2)}:1 < 4.5:1") if c_f6 < 4.5
  end

  # F3: Facets
  facet_inks = accents + [on_variant]
  facet_inks.each do |ink|
    surfaces.each do |bg|
      f3_text = (mode == "light") ? mix(ink, on_surface, 82) : ink
      f3_head = mix(ink, bg, entry[:facet_strength])
      c = contrast(f3_text, f3_head)
      fail!("PLT-AC-46 F3 #{mode} #{ink} on #{bg}: #{c.round(2)}:1 < 4.5:1") if c < 4.5
    end
  end

  # F4: Unselected filter
  surfaces.each do |bg|
    c = contrast(on_variant, bg)
    fail!("PLT-AC-46 F4 unselected #{mode} on #{bg}: #{c.round(2)}:1 < 4.5:1") if c < 4.5
  end

  # F7: Action buttons
  surfaces.each do |bg|
    f7_head = mix(on_variant, bg, entry[:quiet_strength])
    c = contrast(on_surface, f7_head)
    fail!("PLT-AC-46 F7 #{mode} on #{bg}: #{c.round(2)}:1 < 4.5:1") if c < 4.5
  end

  # F8: Related "Cites / Cited by" labels
  surfaces.each do |bg|
    f8_head = mix(on_variant, bg, entry[:quiet_strength])
    c = contrast(on_variant, f8_head)
    fail!("PLT-AC-46 F8 #{mode} on #{bg}: #{c.round(2)}:1 < 4.5:1") if c < 4.5
  end
end

puts "PASS test-theme-contrast (#{foreground} on #{background} = #{ratio.round(2)}:1; #{reports.join('; ')})"
