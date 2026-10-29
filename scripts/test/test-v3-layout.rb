#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-49. Canvas and card layout (docs/features/v3-layout.md).
#
# Each check names the acceptance item it covers (49.1 … 49.14). Pass item
# numbers to run a subset: `ruby scripts/test/test-v3-layout.rb 5 7`.
# The parser understands nested @media blocks and splits selector lists only
# on top-level commas, so `:is()` / `:where()` lists stay whole.

require "pathname"
require "set"

ROOT = Pathname.new(__dir__).join("../..").expand_path
CSS = ROOT.join("assets/css")
require "set"
ONLY_ITEMS = ARGV.map { |a| a.sub(/\A(PLT-AC-)?49\./, "") }.to_set

MOBILE = "max-width:767px"
WIDE = "min-width:768px"

$failures = []

def item(id)
  return if !ONLY_ITEMS.empty? && !ONLY_ITEMS.include?(id.to_s)

  @item = id
  yield
end

def fail!(msg)
  $failures << "FAIL PLT-AC-49.#{@item}: #{msg}"
end

def strip_comments(text)
  text.gsub(%r{/\*.*?\*/}m, "")
end

def split_top(text, sep)
  parts = []
  depth = 0
  quote = nil
  buf = +""
  text.each_char do |c|
    if quote
      quote = nil if c == quote
    elsif c == '"' || c == "'"
      quote = c
    elsif c == "(" || c == "["
      depth += 1
    elsif c == ")" || c == "]"
      depth -= 1
    elsif c == sep && depth.zero?
      parts << buf
      buf = +""
      next
    end
    buf << c
  end
  parts << buf
  parts.map(&:strip).reject(&:empty?)
end

def norm_selector(sel)
  sel.gsub(/\s+/, " ").gsub(/\s*([>+~])\s*/, '\1').strip
end

def norm_media(head)
  head.sub(/\A@media/, "").gsub(/\s+/, "")
end

def parse_rules(css, media = nil, out = [])
  i = 0
  head = +""
  while i < css.length
    c = css[i]
    if c == "{"
      depth = 1
      j = i + 1
      while j < css.length && depth.positive?
        depth += 1 if css[j] == "{"
        depth -= 1 if css[j] == "}"
        j += 1
      end
      body = css[(i + 1)...(j - 1)]
      h = head.strip
      if h.start_with?("@media")
        parse_rules(body, [media, norm_media(h)].compact.join("and"), out)
      elsif h.start_with?("@supports", "@layer", "@container")
        parse_rules(body, media, out)
      elsif !h.start_with?("@")
        decls = split_top(body, ";").filter_map do |d|
          prop, val = d.split(":", 2)
          next unless val

          [prop.strip.downcase, val.gsub(/\s+/, " ").strip]
        end
        split_top(h, ",").each do |sel|
          out << { sel: norm_selector(sel), decls: decls, media: media }
        end
      end
      head = +""
      i = j
    elsif c == ";" && head.strip.start_with?("@")
      head = +""
      i += 1
    elsif c == "}"
      i += 1
    else
      head << c
      i += 1
    end
  end
  out
end

SHEETS = Hash.new do |h, rel|
  text = strip_comments(File.read(CSS.join(rel)))
  h[rel] = { text: text, rules: parse_rules(text) }
end

def media_match?(rule_media, media)
  return rule_media.nil? if media.nil?

  !rule_media.nil? && rule_media.include?(media)
end

# Ordered declarations of every rule for `selector` under `media`
# (nil = outside any @media), in source order.
def decls(rel, selector, media = nil)
  sel = norm_selector(selector)
  SHEETS[rel][:rules].select { |r| r[:sel] == sel && media_match?(r[:media], media) }.flat_map { |r| r[:decls] }
end

def value(list, prop)
  list.reverse.find { |p, _| p == prop }&.last
end

def background(list)
  list.reverse.find { |p, _| p == "background" || p == "background-color" }&.last
end

def where(rel, selector, media)
  "#{rel} #{selector}#{media ? " @media (#{media})" : ''}"
end

def expect(rel, selector, expected, media: nil)
  list = decls(rel, selector, media)
  if list.empty?
    fail!("#{where(rel, selector, media)} has no rule")
    return
  end
  expected.each do |prop, want|
    got = prop == :background ? background(list) : value(list, prop)
    next if got == want

    fail!("#{where(rel, selector, media)} #{prop}: expected `#{want}`, found `#{got || 'unset'}`")
  end
end

def expect_unset(rel, selector, props, media: nil)
  list = decls(rel, selector, media)
  props.each do |prop|
    got = value(list, prop)
    fail!("#{where(rel, selector, media)} must not set #{prop} (found `#{got}`)") if got
  end
end

# `border` must come before `border-top` so the shorthand does not reset it.
def expect_top_after_border(rel, selector)
  list = decls(rel, selector)
  b = list.rindex { |p, _| p == "border" }
  t = list.rindex { |p, _| p == "border-top" }
  return if b && t && t > b

  fail!("#{rel} #{selector}: `border-top` must follow the `border` shorthand")
end

def expect_clamp(rel, selector, lines, media: nil, display: true)
  want = { "-webkit-line-clamp" => lines.to_s, "line-clamp" => lines.to_s }
  want.merge!("display" => "-webkit-box", "-webkit-box-orient" => "vertical", "overflow" => "hidden") if display
  expect(rel, selector, want, media: media)
end

def no_contrast_surface(rel, pattern)
  SHEETS[rel][:rules].each do |r|
    next unless r[:sel].match?(pattern)

    r[:decls].each do |_, v|
      next unless v.match?(/--color-surface-(card|high)-contrast\b/)

      fail!("#{rel} #{r[:sel]} still paints #{v[/--color-surface-\w+-contrast/]}")
    end
  end
end

def read(rel)
  File.read(ROOT.join(rel))
end

# 49.1 Canvas -----------------------------------------------------------------
item(1) do
  unless read("_includes/theme/theme-vars-block.liquid").include?("--color-canvas: {{ tn.canvas | default: tn.panel_contrast")
    fail!("theme-vars-block must emit --color-canvas from neutrals.canvas, else panel_contrast")
  end
  expect("base.css", "html body", { background: "var(--color-canvas)" })
  expect("ledger/home.css", ".home-band--hero", { background: "transparent" })
  expect("ledger/home.css", ".home-band--contrast", { background: "transparent" })
  no_contrast_surface("base.css", /./)
end

# 49.2 Cards ------------------------------------------------------------------
item(2) do
  %w[.ledger-card .ledger-system-card].each do |sel|
    expect("base.css", sel, {
      background: "var(--color-surface-card)",
      "border" => "1px solid var(--border-ink)",
      "border-radius" => "var(--radius-card)"
    })
  end
  SHEETS["base.css"][:rules].each do |r|
    next unless r[:sel].match?(/\[data-theme=["']?light|:not\(\[data-theme=["']?dark/)
    next unless r[:sel].match?(/\.ledger-(system-)?card\z/)

    fail!("base.css #{r[:sel]}: remove the light-only card border override")
  end
  expect("ledger/home.css", ".home-featured", {
    background: "var(--color-surface-card)",
    "border" => "1px solid var(--border-ink)",
    "border-top" => "2px solid var(--color-primary)"
  })
  expect_top_after_border("ledger/home.css", ".home-featured")
end

# 49.3 Decoration -------------------------------------------------------------
RETIRED_SHARDS = %w[
  home-hero-shard home-featured-shard projects-lead-shard projects-hero-shard
  writing-lead-shard rascunhos-shard bib-masthead-shard bib-foot-shard
  sources-masthead-shard sources-foot-shard cv-dossier-shard
].freeze

item(3) do
  home = SHEETS["ledger/home.css"][:text]
  # CR-22 reintroduces a functional spotlight radial on .home-hero-portrait::after
  # (text contrast). Ban any other radial-gradient / blur pool in home.css.
  home_wo_spotlight = home.gsub(/\.home-hero-portrait::after\s*\{.*?\}/m, "")
  fail!("home.css still draws a radial-gradient pool") if home_wo_spotlight.include?("radial-gradient(")
  fail!("home.css still blurs a pool (filter: blur)") if home.match?(/(?<![-\w])filter:\s*blur\(/)
  keep = %w[_includes/page/site-footer.html _includes/home/band-index.html]
  Dir[ROOT.join("{_layouts,_includes}/**/*.html").to_s].sort.each do |path|
    rel = Pathname.new(path).relative_path_from(ROOT).to_s
    next if keep.include?(rel)

    fail!("#{rel} still renders a decorative shard") if File.read(path).include?("shard-accent")
  end
  Dir[CSS.join("**/*.css").to_s].sort.each do |path|
    text = strip_comments(File.read(path))
    RETIRED_SHARDS.each do |cls|
      fail!("#{Pathname.new(path).relative_path_from(ROOT)} still styles .#{cls}") if text.match?(/\.#{cls}\b/)
    end
  end
  if read("_includes/content-runtime/43-blocks.html").include?("ledger-frame-corners")
    fail!("43-blocks.html still emits ledger-frame-corners on cards")
  end
  unless read("_includes/page/site-footer.html").include?("shard-accent")
    fail!("the footer must keep its shards")
  end
end

# 49.4 Top bar ----------------------------------------------------------------
item(4) do
  shell = read("_layouts/shell.html")
  fail!("shell.html top bar must be <header class=\"site-topbar sticky top-0 z-50\">") unless shell.include?('<header class="site-topbar sticky top-0 z-50">')
  fail!("shell.html still draws the tonal separator under the top bar") if shell.include?("bg-surface-container-low h-[1px]")
  expect("ledger/chrome.css", ".site-topbar", {
    "background-color" => "color-mix(in srgb, var(--color-canvas) 92%, transparent)",
    "backdrop-filter" => "blur(10px)",
    "-webkit-backdrop-filter" => "blur(10px)",
    "border-bottom" => "1px solid var(--border-gentle-divider)"
  })
  %w[#theme-toggle-btn #mobile-menu-btn].each do |sel|
    expect("ledger/chrome.css", sel, {
      "width" => "2.25rem",
      "height" => "2.25rem",
      "border" => "1px solid var(--color-outline-variant)",
      "background-color" => "var(--color-surface-card)",
      "color" => "var(--color-on-surface)"
    })
  end
end

# 49.5 Band header ------------------------------------------------------------
item(5) do
  h = "ledger/home.css"
  expect(h, ".home-band:not(.home-band--hero) .ledger-section-banner", {
    "display" => "grid", "grid-template-columns" => "auto auto 1fr"
  })
  expect(h, ".home-band .ledger-section-lead", { "display" => "contents" })
  expect(h, ".home-band .ledger-section-banner .ledger-kicker", { "grid-column" => "1 / -1", "grid-row" => "1" })
  expect(h, ".home-band .ledger-kicker:empty", { "display" => "none" })
  expect(h, ".home-band .ledger-section-banner .section-title", {
    "grid-column" => "1", "grid-row" => "2", "font-size" => "var(--type-section)"
  })
  expect(h, ".home-band .ledger-section-banner .section-title", { "font-size" => "var(--type-section-lg)" }, media: WIDE)
  expect(h, ".home-band .home-section-aside", { "grid-column" => "2", "grid-row" => "2" })
  expect(h, ".home-band .home-section-note", {
    "grid-column" => "1 / -1", "grid-row" => "3", "font-size" => "var(--type-dek)"
  })
end

# 49.6 Card type --------------------------------------------------------------
item(6) do
  b = "base.css"
  expect(b, ".ledger-meta", {
    "font-family" => "var(--font-mono)", "letter-spacing" => "0", "font-size" => "var(--type-micro)"
  })
  %w[.card-title .ledger-card-title].each do |sel|
    expect(b, sel, { "font-weight" => "var(--weight-emphasis)" })
    expect(b, sel, { "font-size" => "var(--type-card-sm)", "line-height" => "1.25" }, media: MOBILE)
  end
  %w[.ledger-card-body .ledger-system-card].each do |sel|
    expect(b, sel, { "padding" => "var(--space-md)" }, media: MOBILE)
  end
  expect_clamp(b, ".ledger-card-copy", 3)
  expect_clamp(b, ".ledger-card-copy", 4, media: WIDE, display: false)
  expect(b, ".ledger-card-copy", { "font-size" => "var(--type-dek)" }, media: MOBILE)
end

# 49.7 Featured article -------------------------------------------------------
item(7) do
  h = "ledger/home.css"
  expect(h, ".home-featured", {
    "display" => "flex", "flex-direction" => "column", "padding" => "0"
  }, media: MOBILE)
  expect(h, ".home-featured > .ledger-poster", {
    "order" => "-1", "width" => "100%", "margin" => "0", "aspect-ratio" => "16 / 9", "border" => "0"
  }, media: MOBILE)
  expect(h, ".home-featured-lead", { "padding" => "var(--space-md)" }, media: MOBILE)
  expect_clamp(h, ".home-featured-copy", 3)
  expect_clamp(h, ".home-featured-copy", 4, media: WIDE, display: false)
end

# 49.8 Index panels -----------------------------------------------------------
item(8) do
  band = read("_includes/home/band-index.html")
  fail!("band-index.html still renders a shard") if band.include?("shard-accent")
  head = band.index('class="home-index-panel-head"')
  figure = band.index('<figure class="home-index-plate"')
  if head.nil? || figure.nil?
    fail!("band-index.html needs .home-index-panel-head before figure.home-index-plate")
  else
    block = band[head...figure]
    unless figure > head && block.include?('class="home-index-title"') && block.include?("ledger-cta") && block.include?("</div>")
      fail!("band-index.html: .home-index-panel-head must hold the h3 title and the Open link, before the plate")
    end
  end
  h = "ledger/home.css"
  expect(h, ".home-index-panel", {
    "padding" => "0", "gap" => "0",
    background: "var(--color-surface-card)", "border" => "1px solid var(--border-ink)"
  })
  expect(h, ".home-index-panel-head", {
    "display" => "flex", "justify-content" => "space-between", "align-items" => "center",
    "padding" => "var(--space-sm) var(--space-md)"
  })
  expect(h, ".home-index-plate", { "border-top" => "1px solid var(--border-gentle-divider)" })
  fail!("home.css still styles .home-index-shard") if SHEETS[h][:text].include?(".home-index-shard")
  no_contrast_surface(h, /home-index-panel/)
end

# 49.9 Rascunhos --------------------------------------------------------------
item(9) do
  h = "ledger/home.css"
  rules = SHEETS[h][:rules]
  wide = ->(r) { r[:media]&.include?(WIDE) }
  # Selectors with `:nth-child()` are matched without whitespace, so
  # `nth-child(4n + 1)` and `nth-child(4n+1)` count as the same rule.
  loose = ->(sel) { sel.gsub(/\s+/, "") }
  find = lambda do |sel, media|
    rules.select { |r| loose.(r[:sel]) == loose.(sel) && media_match?(r[:media], media) }.flat_map { |r| r[:decls] }
  end
  want = lambda do |sel, media, expected|
    list = find.(sel, media)
    if list.empty?
      fail!("#{where(h, sel, media)} has no rule")
      next
    end
    expected.each do |prop, v|
      got = value(list, prop)
      fail!("#{where(h, sel, media)} #{prop}: expected `#{v}`, found `#{got || 'unset'}`") unless got == v
    end
  end

  # Desktop keeps the dropped-sheet tilt; phones never rotate a card.
  %w[4n+1 4n+2 4n+3 4n].each do |n|
    t = value(find.(".home-draft-list>*:nth-child(#{n})", WIDE), "transform")
    next if t&.match?(/\Arotate\(\s*-?(?!0(\.0+)?deg)[\d.]+deg\s*\)\z/)

    fail!("#{where(h, ".home-draft-list>*:nth-child(#{n})", WIDE)} must keep a non-zero rotate(), found `#{t || 'unset'}`")
  end
  rules.each do |r|
    next if wide.(r)

    r[:decls].each do |p, v|
      fail!("#{r[:sel]}#{r[:media] ? " @media (#{r[:media]})" : ''} sets #{p}: #{v}; rotate() only from 768px") if v.include?("rotate(")
    end
  end

  # Phones: two cards side by side, the third a landscape card across both
  # columns, the rest hidden.
  third = ".home-draft-list>.home-draft-card:nth-child(3)"
  want.(third, MOBILE, { "grid-column" => "1 / -1", "flex-direction" => "row" })
  want.("#{third} .ledger-poster", MOBILE, {
    "flex" => "0 0 38%", "aspect-ratio" => "auto", "align-self" => "stretch"
  })
  want.("#{third} .ledger-poster img", MOBILE, { "position" => "absolute", "inset" => "0" })
  want.("#{third} .ledger-card-body", MOBILE, { "flex" => "1 1 auto", "min-width" => "0" })
  want.(".home-draft-list>.home-draft-card:nth-child(n + 4)", MOBILE, { "display" => "none" })
  rules.each do |r|
    next unless r[:sel].include?("home-draft") && r[:sel].include?("nth-child(3)") && wide.(r)
    next unless r[:decls].any? { |p, _| %w[grid-column flex-direction].include?(p) }

    fail!("#{r[:sel]} @media (#{r[:media]}) reshapes the third card from 768px; phones only")
  end
  rules.each do |r|
    next unless loose.(r[:sel]).include?("nth-child(n+4)") && r[:sel].include?("home-draft") && !r[:media]&.include?(MOBILE)

    fail!("#{r[:sel]} hides drafts outside phones") if r[:decls].any? { |p, v| p == "display" && v == "none" }
  end

  expect(h, ".home-draft-card .ledger-poster", { "aspect-ratio" => "4 / 3" }, media: MOBILE)
  expect(h, ".home-draft-card .ledger-meta", {
    "flex-wrap" => "nowrap", "white-space" => "nowrap", "overflow" => "hidden"
  }, media: MOBILE)
  expect(h, ".home-draft-card .ledger-card-title", { "font-size" => "var(--type-dek)" }, media: MOBILE)
  expect(h, ".home-draft-card .ledger-card-copy", { "font-size" => "var(--type-label)" }, media: MOBILE)
  expect_clamp(h, ".home-draft-card .ledger-card-title", 3)
  expect_clamp(h, ".home-draft-card .ledger-card-copy", 3)
  expect_clamp(h, ".home-draft-card .ledger-card-copy", 4, media: WIDE, display: false)
  rules.each do |r|
    next unless r[:sel].include?("home-draft-card .ledger-card-copy")

    r[:decls].each do |p, v|
      fail!("#{r[:sel]} still clamps to #{v}") if p.end_with?("line-clamp") && %w[5 6].include?(v)
      fail!("#{r[:sel]} keeps the 5-6 line filler (#{p}: #{v})") if (p == "min-height" && v.include?("--type-subtitle")) || (p == "height" && v == "0")
    end
  end
end

# 49.10 Projects --------------------------------------------------------------
item(10) do
  h = "ledger/home.css"
  expect(h, ".home-project-inventory-row", {
    background: "var(--color-surface-card)", "border" => "1px solid var(--border-gentle)"
  })
  no_contrast_surface(h, /home-project/)
  p = "ledger/projects.css"
  expect(p, ".projects-page .projects-lead", {
    "border" => "1px solid var(--border-ink)", "border-top" => "2px solid var(--color-primary)"
  })
  expect_top_after_border(p, ".projects-page .projects-lead")
  expect_unset(p, ".projects-page .projects-lead", %w[border-left border-left-color])
  expect_unset(p, ".projects-page .projects-lead:hover", %w[border-left border-left-color])
  expect(p, ".projects-page .projects-lead-body", { "padding" => "var(--space-md)" }, media: MOBILE)
  expect(p, ".projects-page .projects-grid", { "gap" => "var(--space-md)" }, media: MOBILE)
  expect(p, ".projects-page .ledger-system-card > .ledger-poster", {
    "margin" => "calc(var(--space-md) * -1) calc(var(--space-md) * -1) 0"
  }, media: MOBILE)
end

# 49.11 Reading view ----------------------------------------------------------
item(11) do
  d = "ledger/detail.css"
  side = [".text-detail-sidebar", ".text-detail-sidebar .article-sidebar-heading", ".text-detail-sidebar .article-meta"]
  side.each do |sel|
    expect(d, sel, { background: "var(--color-surface-card)" })
    expect(d, sel, { background: "transparent" }, media: MOBILE)
  end
  expect(d, ".text-detail-sidebar", { "border" => "0" }, media: MOBILE)
  a = "article.css"
  expect(a, ".text-page-main", {
    background: "var(--color-surface-card)", "border" => "1px solid var(--border-ink)"
  })
  expect(a, ".text-page-main", {
    background: "transparent", "border" => "0", "padding" => "0"
  }, media: MOBILE)
end

# 49.12 Text calls to action --------------------------------------------------
PLAIN_CTA = ".ledger-cta:where(:not(.ledger-cta--emphasis):not(.ledger-cta--emphasis-alt))"
CTA_INK = "color-mix(in srgb, var(--color-primary) var(--action-ink-mix), var(--color-on-surface))"

item(12) do
  b = "base.css"
  shared = SHEETS[b][:rules].find do |r|
    r[:sel] == PLAIN_CTA && r[:media].nil? && background(r[:decls]).to_s.include?("var(--mark-1)")
  end
  fail!("base.css: #{PLAIN_CTA} must join the shared highlighter mark rule") unless shared
  expect(b, PLAIN_CTA, {
    "--mark-1" => "var(--mark-strong-a)", "--mark-2" => "var(--mark-strong-b)", "--mark-3" => "var(--mark-strong-c)",
    "color" => CTA_INK
  })
  expect(b, "#{PLAIN_CTA}:hover", {
    "--mark-1" => "var(--mark-hover-a)", "--mark-2" => "var(--mark-hover-b)", "--mark-3" => "var(--mark-hover-c)",
    "color" => CTA_INK
  })
  Dir[CSS.join("**/*.css").to_s].sort.each do |path|
    rel = Pathname.new(path).relative_path_from(CSS).to_s
    SHEETS[rel][:rules].each do |r|
      next unless r[:sel].include?(".ledger-cta")

      r[:decls].each do |p, v|
        next unless p.start_with?("text-decoration") && v.include?("underline")

        fail!("#{rel} #{r[:sel]} still underlines a call to action")
      end
    end
  end
end

# 49.13 Guards ----------------------------------------------------------------
IMPORTANT_BASELINE = {
  "article.css" => 5, "tailwind.css" => 9, "ledger/bibliography.css" => 1,
  "ledger/detail.css" => 4, "ledger/sources.css" => 1
}.freeze

item(13) do
  Dir[CSS.join("**/*.css").to_s].sort.each do |path|
    rel = Pathname.new(path).relative_path_from(CSS).to_s
    count = SHEETS[rel][:text].scan("!important").size
    allowed = IMPORTANT_BASELINE.fetch(rel, 0)
    fail!("#{rel} has #{count} !important (baseline #{allowed})") if count > allowed
  end
end

# 49.14 Top bar fit -----------------------------------------------------------
RAIL_FROM = "min-width:1280px"

item(14) do
  chrome = "ledger/chrome.css"
  expect(chrome, ".site-rail", { "display" => "none" })
  expect(chrome, ".site-rail", { "display" => "flex" }, media: RAIL_FROM)
  expect(chrome, "#site-menu", { "display" => "none" }, media: RAIL_FROM)
  SHEETS[chrome][:rules].each do |r|
    next unless r[:media]
    next unless %w[.site-rail #site-menu].include?(r[:sel])
    next unless r[:decls].any? { |p, _| p == "display" }
    next if r[:media] == "(#{RAIL_FROM})"

    fail!("#{chrome} #{r[:sel]} sets display under @media #{r[:media]}; only (#{RAIL_FROM}) may")
  end
  expect(chrome, ".site-rail", { "gap" => "var(--space-sm)" }, media: "min-width:1280px)and(max-width:1439px")
  expect(chrome, ".site-rail", { "gap" => "var(--space-lg)" })
end

if $failures.empty?
  puts "PLT-AC-49 v3 layout: OK"
else
  puts $failures
  warn "#{$failures.size} PLT-AC-49 check(s) failed"
  exit 1
end
