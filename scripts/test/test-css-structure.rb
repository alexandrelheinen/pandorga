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

  if cleaned.match?(/\{[ \t\r\n]*\}/)
    errors << "#{relative}: empty ruleset (a block that matches nothing)"
  end

  if source.include?("home-profile-summary")
    errors << "#{relative}: .home-profile-summary is unused"
  end

  # Selectors that matched no template, runtime string, or current content.
  # A comment may still name one; a ruleset may not.
  retired = %w[
    page-title
    ledger-marker--primary
    ledger-card--edge-primary
    ledger-card--edge-secondary
    ledger-card--edge-tertiary
    ledger-section-rule
    home-band--ruled
    home-index-shard--gamma
    home-index-note
    post-content
    home-hero-pandorga-svg
    table-csv
  ]
  if cleaned.include?("span.text-secondary:not(.font-bold)")
    errors << "#{relative}: author byline suppressor matches no markup"
  end
  retired.each do |name|
    next unless cleaned.match?(/[.#]#{Regexp.escape(name)}\b/)

    errors << "#{relative}: .#{name} is unused"
  end
end

# PLT-AC-36. A display equation scrolls inside the article column. Overflow
# on html or body would scroll the sticky header off the viewport.
def declaration_bodies(css, selector)
  wanted = selector.gsub(/\s+/, " ").strip
  bodies = []
  css.scan(/([^{}]+)\{([^{}]*)\}/m) do |sel, body|
    parts = sel.split(",").map { |part| part.gsub(/\s+/, " ").strip }
    bodies << body if parts.include?(wanted)
  end
  bodies
end

def declarations(body)
  body.downcase.gsub(/\s+/, "")
end

def require_declarations(errors, label, css, selector, required)
  bodies = declaration_bodies(css, selector)
  if bodies.empty?
    errors << "#{label}: missing #{selector}"
    return
  end

  blob = bodies.map { |body| declarations(body) }.join(";")
  required.each do |decl|
    needle = decl.downcase.gsub(/\s+/, "")
    next if blob.include?(needle)

    errors << "#{label}: #{selector} missing #{decl}"
  end
end

def strip_comments(source)
  source.gsub(%r{/\*.*?\*/}m, "")
end

article_sheet = strip_comments(File.read(CSS_ROOT.join("article.css")))
detail_sheet = strip_comments(File.read(CSS_ROOT.join("ledger/detail.css")))
math_box = ["max-width: 100%", "overflow-x: auto", "overflow-y: hidden"]

require_declarations(
  errors, "assets/css/article.css", article_sheet,
  ".article-content .math-display", math_box
)
require_declarations(
  errors, "assets/css/article.css", article_sheet,
  '.article-content .math-display mjx-container[jax][display="true"]', math_box
)
require_declarations(
  errors, "assets/css/article.css", article_sheet,
  '.article-content mjx-container[display="true"]', math_box
)
require_declarations(
  errors, "assets/css/article.css", article_sheet,
  '.article-content mjx-container[jax][display="true"]', math_box
)

if article_sheet.match?(/mjx-container[^{]*\{[^}]*overflow\s*:\s*visible/m)
  errors << "assets/css/article.css: display math sets overflow: visible"
end

# PLT-AC-38. Inline formulas scroll inside the column below 768px. The
# unscoped rule stays display:inline so a short formula on a wide column
# remains in the line.
inline_selector = '.article-content mjx-container:not([display="true"])'
inline_jax = '.article-content mjx-container[jax]:not([display="true"])'
inline_bodies = declaration_bodies(article_sheet, inline_selector)
inline_base = inline_bodies.find { |body| body.match?(/display:\s*inline\s*;/) && !body.match?(/inline-block/) }
unless inline_base
  errors << "assets/css/article.css: #{inline_selector} must stay display:inline outside the phone query"
end

mobile_inline = nil
article_sheet.scan(/@media\s*\(\s*max-width:\s*767px\s*\)\s*\{((?:[^{}]|\{[^{}]*\})*)\}/m) do |inner,|
  mobile_inline = inner if inner.include?(inline_selector)
end
if mobile_inline.nil?
  errors << "assets/css/article.css: inline math scroll is not limited to max-width 767px"
else
  require_declarations(errors, "assets/css/article.css", mobile_inline, inline_selector, math_box + ["display: inline-block"])
  require_declarations(errors, "assets/css/article.css", mobile_inline, inline_jax, math_box + ["display: inline-block"])
end

require_declarations(
  errors, "assets/css/article.css", article_sheet,
  ".article-content figure", ["max-width: 100%"]
)
require_declarations(
  errors, "assets/css/article.css", article_sheet,
  ".article-content svg", ["max-width: 100%"]
)
require_declarations(
  errors, "assets/css/article.css", article_sheet,
  ".article-content .mermaid", math_box
)
require_declarations(
  errors, "assets/css/article.css", article_sheet,
  ".article-content .mermaid svg", ["max-width: none"]
)
require_declarations(
  errors, "assets/css/article.css", article_sheet,
  ".article-content table", ["max-width: 100%"]
)
require_declarations(
  errors, "assets/css/ledger/detail.css", detail_sheet,
  ".article-content table", ["max-width: 100%", "overflow-x: auto", "overflow-y: hidden"]
)
require_declarations(
  errors, "assets/css/ledger/detail.css", detail_sheet,
  ".grid.text-detail-grid > *", ["min-width: 0"]
)

sheets.each do |path|
  relative = Pathname.new(path).relative_path_from(REPO_ROOT)
  cleaned = strip_noise(File.read(path))
  cleaned.scan(/([^{}]+)\{([^{}]*)\}/m) do |sel, body|
    next unless body.match?(/overflow/i)

    sel.split(",").each do |part|
      name = part.gsub(/\s+/, " ").strip
      next unless name == "html" || name == "body" || name == "html body"

      errors << "#{relative}: #{name} sets overflow and would break the sticky header"
    end
  end
end

# PLT-AC-41. Home project inventory rows use the square icon mark, two-line
# code + title body, and no tagline preview or attached-resource icons; on
# desktop the specimen and rack split the band 7:5 across one --space-xl gap,
# the specimen sets the bench height, rack titles use --type-card, and the
# specimen strip wraps instead of clipping.
home_sheet = strip_comments(File.read(CSS_ROOT.join("ledger/home.css")))
%w[
  home-project-inventory-copy
  home-project-inventory-resources
  home-project-inventory-resource
].each do |retired_home|
  if home_sheet.match?(/[.#]#{Regexp.escape(retired_home)}\b/)
    errors << "assets/css/ledger/home.css: .#{retired_home} must be removed (PLT-AC-41)"
  end
end
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-project-inventory-media", ["aspect-ratio: 1 / 1"]
)
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-projects-bench", ["grid-template-columns: minmax(0, 7fr) minmax(0, 5fr)", "column-gap: var(--space-xl)", "--home-inventory-row-max: calc(1.6 * var(--home-inventory-row-min))"]
)
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-specimen-strip .ledger-meta", ["display: block", "white-space: normal"]
)
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-project-inventory-title", ["font-size: var(--type-card)"]
)
[
  "45.6%",
  "--home-inventory-min-height",
  "calc(var(--type-card) - 2pt)"
].each do |forbidden_home|
  if home_sheet.include?(forbidden_home)
    errors << "assets/css/ledger/home.css: #{forbidden_home} must be removed (PLT-AC-41)"
  end
end

fail!("CSS structure problems:\n  - #{errors.join("\n  - ")}") unless errors.empty?

puts "  #{sheets.size} stylesheet(s) balanced, no conflict markers."
puts "All CSS structure tests passed."
