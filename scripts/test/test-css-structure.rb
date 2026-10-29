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

# PLT-AC-41 / CR-21d. Home project inventory rows use the square icon mark;
# desktop bench is a button-width track + specimen with column-gap ≤ 2×
# button gap; specimen plate is 16:9; rack titles use --type-card; below
# 900px the rack tile glyphs are calc(1.375rem + 2pt).
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
  ".home-projects-bench", ["grid-template-columns: var(--home-icon-btn-size) minmax(0, 1fr)", "column-gap: calc(var(--space-xs) * 2)", "justify-content: start"]
)
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-specimen-strip .ledger-meta", ["display: block", "white-space: normal"]
)
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-project-inventory-title", ["font-size: var(--type-card)"]
)
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-project-inventory-row .home-project-inventory-glyph", ["font-size: calc(1.375rem + 2pt)"]
)
[
  "45.6%",
  "minmax(0, 7fr)",
  "--home-inventory-min-height",
  "calc(var(--type-card) - 2pt)"
].each do |forbidden_home|
  if home_sheet.include?(forbidden_home)
    errors << "assets/css/ledger/home.css: #{forbidden_home} must be removed (PLT-AC-41)"
  end
end

# PLT-AC-60. Heading and title selectors in ledger CSS do not use text-transform: uppercase.
title_selector_pattern = /^\.(?:page-header-title|section-title|home-hero-title|card-title|ledger-card-title|text-title|home-featured-title|ledger-row-title|source-card-title|bib-card-title|home-project-inventory-title|home-index-title|article-title|article-related-title|projects-dossier-title)\b/

sheets.each do |path|
  relative = Pathname.new(path).relative_path_from(REPO_ROOT)
  cleaned = strip_noise(File.read(path))
  cleaned.scan(/([^{}]+)\{([^{}]*)\}/m) do |sel, body|
    next unless body.match?(/text-transform\s*:\s*uppercase/i)

    sel.split(",").each do |part|
      name = part.gsub(/\s+/, " ").strip
      next unless name.match?(title_selector_pattern)

      errors << "#{relative}: title selector #{name} applies text-transform: uppercase (PLT-AC-60)"
    end
  end
end

# PLT-AC-23. The home hero summary uses --color-legend, the ink of the other
# description texts.
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-hero-summary", ["color: var(--color-legend)"]
)
if declaration_bodies(home_sheet, ".home-hero-summary").any? { |body| declarations(body).include?("color:var(--color-on-surface)") }
  errors << "assets/css/ledger/home.css: .home-hero-summary must use --color-legend (PLT-AC-23)"
end

# PLT-AC-62 / PLT-AC-68. Hero cqi clamp divisors calculated for Ancizar (~6.9 / ~10.81). Cinzel and 5.55 comments removed.
if home_sheet.match?(/Cinzel/i) || home_sheet.include?("5.55")
  errors << "assets/css/ledger/home.css must not contain Cinzel or obsolete 5.55 comments/divisors (PLT-AC-68)"
end
# Phone/base keep Ancizar 6.9; desktop CR-22.1 uses the approved B3 vw clamp.
unless home_sheet.include?("calc(100cqi * 0.92 / 6.9)")
  errors << "assets/css/ledger/home.css: phone/base hero clamp must use Ancizar ~6.9 (PLT-AC-68)"
end
unless home_sheet.include?("calc(clamp(1.85rem, 2.6vw, 2.55rem) + 2pt)")
  errors << "assets/css/ledger/home.css: desktop B3 name clamp missing (CR-22.1 / PLT-AC-86)"
end

# PLT-AC-69. Inventory / project logo icon font-sizes +2pt.
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-project-inventory-glyph", ["font-size: calc(1.25rem + 2pt)"]
)
unless home_sheet.include?("calc(1.375rem + 2pt)") && home_sheet.include?("calc(1.25rem + 2pt)")
  errors << "assets/css/ledger/home.css: inventory icon sizes must be +2pt larger than 2.2.1 rem values (PLT-AC-69)"
end

# PLT-AC-70. Home section titles one step larger (--type-section / --type-section-lg).
require_declarations(
  errors, "assets/css/ledger/home.css", home_sheet,
  ".home-band .ledger-section-banner .section-title", ["font-size: var(--type-section)"]
)

# PLT-AC-71. Mobile article/post detail meta + actions redesign.
unless detail_sheet.include?("flex-direction: column") && detail_sheet.include?("detail-actions")
  errors << "assets/css/ledger/detail.css: mobile detail meta must stack and include detail-actions (PLT-AC-71)"
end

# PLT-AC-72. Detail reading-progress bar uses top: 0 (not top: 4.25rem).
if detail_sheet.include?("top: 4.25rem") || !detail_sheet.include?("top: 0")
  errors << "assets/css/ledger/detail.css: reading progress bar must use top: 0 instead of 4.25rem (PLT-AC-72)"
end

# PLT-AC-63. Page header markup must not hardcode class="italic" on title span.
page_header_html = File.read(REPO_ROOT.join("_includes/page/page-header.html"))
if page_header_html.include?('data-content-header-title class="italic"') || page_header_html.include?('class="italic" data-content-header-title')
  errors << "_includes/page/page-header.html: data-content-header-title must not hardcode class=\"italic\" (PLT-AC-63)"
end

# PLT-AC-64. Hero family drops italic.
hero_family_body = declaration_bodies(home_sheet, ".home-hero-family").join(";")
if declarations(hero_family_body).include?("font-style:italic")
  errors << "assets/css/ledger/home.css: .home-hero-family must remove font-style: italic (PLT-AC-64)"
end

# PLT-AC-65. Home specimen title must not be set to var(--type-section) at >=900px.
if home_sheet.include?(".home-project-specimen .home-specimen-title {\n    font-size: var(--type-section);\n  }") ||
   home_sheet.match?(/\.home-specimen-title\s*\{[^}]*font-size\s*:\s*var\(--type-section\)/)
  errors << "assets/css/ledger/home.css: .home-specimen-title must not be set to var(--type-section) at 900px (PLT-AC-65)"
end

# PLT-AC-66. Grouped selector for title role em felt-marker wash.
base_sheet = strip_comments(File.read(CSS_ROOT.join("base.css")))
required_marker_selector = ".section-title em, .page-header-title em, .home-index-title em, .card-title em, .ledger-card-title em"
unless base_sheet.include?(required_marker_selector)
  errors << "assets/css/base.css: missing grouped title marker selector '#{required_marker_selector}' (PLT-AC-66)"
end

dark_marker_selector = "[data-theme=\"dark\"] .section-title em, [data-theme=\"dark\"] .page-header-title em, [data-theme=\"dark\"] .home-index-title em, [data-theme=\"dark\"] .card-title em, [data-theme=\"dark\"] .ledger-card-title em"
unless base_sheet.include?(dark_marker_selector)
  errors << "assets/css/base.css: missing grouped dark title marker selector '#{dark_marker_selector}' (PLT-AC-66)"
end

fail!("CSS structure problems:\n  - #{errors.join("\n  - ")}") unless errors.empty?

puts "  #{sheets.size} stylesheet(s) balanced, no conflict markers."
puts "All CSS structure tests passed."
