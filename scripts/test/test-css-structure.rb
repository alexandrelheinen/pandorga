#!/usr/bin/env ruby
# frozen_string_literal: true

# An unbalanced brace in CSS does not fail a build and does not error in a
# browser. The parser simply swallows everything after it into the open block,
# so a stylesheet keeps loading with a 200 while an arbitrary number of its
# rules silently stop applying. That is exactly what a bad merge resolution
# produced here: the page rendered, the console was clean, and a third of one
# sheet had quietly stopped existing.
#
# Also catches conflict markers, which are valid-enough text to survive a
# build and are far easier to spot here than on a rendered page.

require "pathname"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
CSS_ROOT = REPO_ROOT.join("assets/css")

CONFLICT_MARKERS = /^(?:<{7}|={7}|>{7})(?:\s|$)/.freeze

def fail!(message)
  warn message
  exit 1
end

# Strip comments and strings so braces inside them are not counted.
def strip_noise(source)
  out = source.gsub(%r{/\*.*?\*/}m, "")
  out.gsub(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/, '""')
end

puts "Testing CSS structure..."

sheets = Dir.glob(CSS_ROOT.join("**", "*.css")).sort
fail!("no stylesheets found under #{CSS_ROOT}") if sheets.empty?

errors = []

sheets.each do |path|
  relative = Pathname.new(path).relative_path_from(REPO_ROOT)
  source = File.read(path)

  source.each_line.with_index(1) do |line, number|
    next unless line.match?(CONFLICT_MARKERS)

    errors << "#{relative}:#{number}: unresolved conflict marker"
  end

  cleaned = strip_noise(source)
  depth = 0
  negative_at = nil

  cleaned.each_line.with_index(1) do |line, number|
    depth += line.count("{") - line.count("}")
    if depth.negative? && negative_at.nil?
      negative_at = number
      break
    end
  end

  if negative_at
    errors << "#{relative}:#{negative_at}: closing brace with no matching opener"
  elsif depth.positive?
    errors << "#{relative}: #{depth} unclosed brace(s) — every rule after the " \
              "offending block is swallowed and silently stops applying"
  end
end

fail!("CSS structure problems:\n  - #{errors.join("\n  - ")}") unless errors.empty?

puts "  #{sheets.size} stylesheet(s) balanced, no conflict markers."
puts "All CSS structure tests passed."
