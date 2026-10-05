#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate: text-entry controls must be painted in theme tokens, by a selector
# that outranks the Tailwind forms plugin.
#
# The forms plugin ships its own base layer for `[type='text']`,
# `[type='search']`, `textarea` and `select`, setting a white background and a
# near-black colour. That layer is injected after assets/css/base.css, and an
# attribute selector scores the same as a single class, so a one-class rule
# loses the tie on source order. In dark mode the keyword box then renders as
# a white hole — which is exactly what happened, on every listing page at
# once, while the build stayed green and no screenshot was taken in dark mode.
#
# Two defences, both checked here:
#   1. the rule that paints the control uses at least two classes (or an
#      equivalent compound), so it wins the cascade outright;
#   2. it sets background and colour from custom properties, so both palettes
#      follow. A literal colour is how one theme gets broken silently.
#
# Checkboxes and radios are out of scope: the plugin styles those through
# `accent-color`/`currentColor`, which already tracks the theme.

require "pathname"
require "set"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
MARKUP_DIRS = [ROOT.join("_layouts"), ROOT.join("_includes")].freeze
CSS_DIR = ROOT.join("assets/css")

# Input types the forms plugin paints as a text field. `<input>` with no type
# defaults to text, so a missing type counts too.
TEXT_ENTRY_TYPES = %w[text search email url tel number password date datetime-local month week time].freeze

# The printed CV is hard-coded to the light palette by design, and carries no
# interactive controls; studio/ is the self-hosted SPA.
SKIP = /cv-print|print-/.freeze

def fail!(message)
  warn message
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

# Specificity that matters against `[type='search']` (0,1,0): count classes,
# attributes and ids in one selector of the group.
def weight(selector)
  selector.scan(/\.[\w-]+/).length +
    selector.scan(/\[[^\]]+\]/).length +
    selector.scan(/#[\w-]+/).length * 100
end

def css_rules
  Dir.glob(CSS_DIR.join("**/*.css")).sort.flat_map do |path|
    next [] if File.basename(path).match?(SKIP)

    text = File.read(path).gsub(%r{/\*.*?\*/}m, "")
    text.scan(/([^{}]+)\{([^{}]*)\}/m).map do |selector_group, body|
      { file: Pathname.new(path).relative_path_from(ROOT).to_s,
        selectors: selector_group.split(",").map(&:strip).reject(&:empty?),
        body: body }
    end
  end
end

def text_entry_controls
  found = []
  MARKUP_DIRS.each do |dir|
    Dir.glob(dir.join("**/*.{html,liquid}")).sort.each do |path|
      next if File.basename(path).match?(SKIP)

      File.read(path).scan(/<(input|textarea|select)\b([^>]*)>/m) do |tag, attrs|
        type = attrs[/\btype\s*=\s*["']([\w-]+)["']/, 1]
        next if tag == "input" && !type.nil? && !TEXT_ENTRY_TYPES.include?(type)

        classes = attrs[/\bclass\s*=\s*["']([^"']*)["']/, 1].to_s.split(/\s+/)
        found << {
          file: Pathname.new(path).relative_path_from(ROOT).to_s,
          tag: tag,
          type: type || (tag == "input" ? "text" : tag),
          classes: classes
        }
      end
    end
  end
  found
end

puts "Testing form control theming..."

rules = css_rules
check!(rules.length > 100, "only parsed #{rules.length} CSS rules; the parser has drifted")

controls = text_entry_controls
check!(
  controls.any?,
  "found no text-entry controls in #{MARKUP_DIRS.map { |d| d.basename.to_s }.join(', ')}; " \
  "the listing pages each carry a keyword box, so the scan has drifted"
)

controls.each do |control|
  label = "#{control[:file]} <#{control[:tag]} type=#{control[:type]}>"
  check!(
    control[:classes].any?,
    "#{label} carries no class, so nothing can outrank the forms plugin base layer"
  )

  painting = rules.select do |rule|
    next false unless rule[:body].match?(/(?<![-\w])background(?:-color)?\s*:/)
    next false unless rule[:body].match?(/(?<![-\w])color\s*:/)

    rule[:selectors].any? do |selector|
      control[:classes].any? { |cls| selector.include?(".#{cls}") } && weight(selector) >= 2
    end
  end

  check!(
    painting.any?,
    "#{label} (class=#{control[:classes].join(' ')}) has no CSS rule that sets both " \
    "background and color with at least two classes of specificity. The Tailwind " \
    "forms plugin paints it white from a later stylesheet, so dark mode shows a white hole."
  )

  painting.each do |rule|
    %w[background color].each do |property|
      value = rule[:body][/(?<![-\w])#{property}(?:-color)?\s*:([^;]+);/, 1].to_s.strip
      next if value.empty?

      check!(
        value.include?("var(--"),
        "#{rule[:file]}: #{rule[:selectors].join(', ')} sets #{property}: #{value}. " \
        "Use a theme custom property — a literal colour is correct in one palette and wrong in the other."
      )
    end
  end

  puts "  #{label}: painted by #{painting.map { |r| r[:selectors].first }.uniq.join(' / ')}"
end

puts "All form control theming checks passed (#{controls.length} control(s))."
