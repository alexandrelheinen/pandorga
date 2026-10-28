#!/usr/bin/env ruby
# frozen_string_literal: true

# Acceptance tests for Mobile density + home measure (pandorga theme UI).
#
# 1. Article page top on mobile: meta date row and action buttons share one band,
#    and TOC disclosure / reading column gaps are bounded.
# 2. Fixed top bar on mobile: shorter vertical padding (≤56-60px height) and
#    hide-on-scroll functionality.
# 3. Home hero summary measure on desktop: constrained to ~60-70ch (e.g. 65ch).
# 4. Home section "View all" next to title: grid-template-columns places CTA
#    beside section title, not at far right of wide band.

require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
CSS = ROOT.join("assets/css")

$failures = []

def fail!(msg)
  $failures << "FAIL test-mobile-density-home-measure: #{msg}"
end

def strip_comments(text)
  text.gsub(%r{/\*.*?\*/}m, "")
end

def parse_css_rules(css_text)
  rules = []
  i = 0
  head = +""
  while i < css_text.length
    c = css_text[i]
    if c == "{"
      depth = 1
      j = i + 1
      while j < css_text.length && depth.positive?
        depth += 1 if css_text[j] == "{"
        depth -= 1 if css_text[j] == "}"
        j += 1
      end
      body = css_text[(i + 1)...(j - 1)]
      h = head.strip
      if h.start_with?("@media")
        media_cond = h.sub(/\A@media\s*/, "").gsub(/\s+/, "")
        sub_rules = parse_css_rules(body)
        sub_rules.each do |r|
          m = r[:media] ? "#{media_cond} and #{r[:media]}" : media_cond
          rules << r.merge(media: m)
        end
      elsif h.start_with?("@supports", "@layer", "@container")
        rules.concat(parse_css_rules(body))
      elsif !h.start_with?("@")
        decls = body.split(";").filter_map do |d|
          prop, val = d.split(":", 2)
          next unless val

          [prop.strip.downcase, val.gsub(/\s+/, " ").strip]
        end
        h.split(",").each do |sel|
          s = sel.gsub(/\s+/, " ").strip
          rules << { sel: s, decls: decls, media: nil }
        end
      end
      head = +""
      i = j
    elsif c == "}"
      i += 1
    else
      head << c
      i += 1
    end
  end
  rules
end

# 1. Article page top on mobile
detail_css = strip_comments(File.read(CSS.join("ledger/detail.css")))
detail_rules = parse_css_rules(detail_css)

meta_mobile_rules = detail_rules.select do |r|
  r[:media] && r[:media].include?("max-width:767px") && r[:sel] == ".text-detail-sidebar .article-meta"
end

has_row_layout = meta_mobile_rules.any? do |r|
  r[:decls].any? { |p, v| p == "flex-direction" && v == "row" }
end

unless has_row_layout
  fail!("detail.css must set flex-direction: row on .text-detail-sidebar .article-meta under @media (max-width: 767px)")
end

has_wrap_layout = meta_mobile_rules.any? do |r|
  r[:decls].any? { |p, v| p == "flex-wrap" && v == "wrap" }
end

has_nowrap = meta_mobile_rules.any? do |r|
  r[:decls].any? { |p, v| p == "flex-wrap" && v == "nowrap" }
end

unless has_wrap_layout && !has_nowrap
  fail!("detail.css must set flex-wrap: wrap (and not nowrap) on .text-detail-sidebar .article-meta under @media (max-width: 767px)")
end

toc_disclosure_mobile = detail_rules.select do |r|
  r[:media] && r[:media].include?("max-width:767px") && r[:sel].include?("article-toc--disclosure")
end

has_bounded_toc_margin = toc_disclosure_mobile.any? do |r|
  r[:decls].any? { |p, v| (p == "margin-top" || p == "margin-bottom" || p == "margin") && (v.include?("var(--space-xs)") || v.include?("var(--space-sm)") || v.include?("0")) }
end

unless has_bounded_toc_margin
  fail!("detail.css must bound margins on .article-toc--disclosure under @media (max-width: 767px)")
end

# 2. Fixed top bar on mobile
chrome_css = strip_comments(File.read(CSS.join("ledger/chrome.css")))
chrome_rules = parse_css_rules(chrome_css)

topbar_mobile_padding = chrome_rules.any? do |r|
  r[:media] && r[:media].include?("max-width:767px") && (r[:sel] == ".site-topbar > div" || r[:sel] == ".site-topbar") &&
    r[:decls].any? { |p, v| (p == "padding-top" || p == "padding-bottom" || p == "padding" || p == "padding-block") && (v.include?("0.625rem") || v.include?("0.5rem") || v.include?("0.75rem") || v.include?("10px") || v.include?("12px")) }
end

unless topbar_mobile_padding
  fail!("chrome.css must reduce vertical padding on .site-topbar under @media (max-width: 767px)")
end

topbar_hide_rule = chrome_rules.any? do |r|
  (r[:sel].include?(".site-topbar.topbar--hidden") || r[:sel].include?(".site-topbar[data-topbar-hidden]")) &&
    r[:decls].any? { |p, v| p == "transform" && v.include?("translateY(-100%)") }
end

unless topbar_hide_rule
  fail!("chrome.css must define transform: translateY(-100%) on .site-topbar.topbar--hidden")
end

shell_html = File.read(ROOT.join("_layouts/shell.html"))
unless shell_html.include?("topbar--hidden") || shell_html.include?("data-topbar-hidden")
  fail!("_layouts/shell.html must contain hide-on-scroll logic for .site-topbar")
end

# 3. Home hero summary measure on desktop
home_css = strip_comments(File.read(CSS.join("ledger/home.css")))
home_rules = parse_css_rules(home_css)

hero_summary_desktop = home_rules.any? do |r|
  r[:media] && r[:media].include?("min-width:768px") && r[:sel] == ".home-hero-summary" &&
    r[:decls].any? { |p, v| p == "max-width" && (v == "65ch" || v == "60ch" || v == "70ch") }
end

unless hero_summary_desktop
  fail!("home.css must constrain .home-hero-summary max-width to ~65ch under @media (min-width: 768px)")
end

# 4. Home section "View all" next to title
banner_grid_col = home_rules.any? do |r|
  r[:sel] == ".home-band:not(.home-band--hero) .ledger-section-banner" &&
    r[:decls].any? { |p, v| p == "grid-template-columns" && (v.start_with?("auto auto") || v.start_with?("minmax(0, auto) auto") || v.start_with?("max-content max-content")) }
end

unless banner_grid_col
  fail!("home.css must set grid-template-columns on .ledger-section-banner to place CTA beside title (e.g. auto auto 1fr)")
end

if $failures.empty?
  puts "PASS test-mobile-density-home-measure"
else
  $failures.each { |f| puts f }
  exit 1
end
