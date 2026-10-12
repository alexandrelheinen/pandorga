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

puts "PASS test-theme-contrast (#{foreground} on #{background} = #{ratio.round(2)}:1; #{reports.join('; ')})"
