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

puts "PASS test-theme-contrast (#{foreground} on #{background} = #{ratio.round(2)}:1)"
