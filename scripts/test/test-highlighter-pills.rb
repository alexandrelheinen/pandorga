#!/usr/bin/env ruby
# frozen_string_literal: true

# Highlighter pills test gate.
# PLT-AC-46

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-highlighter-pills: #{message}"
  exit 1
end

def parse_css_rules(css_text)
  clean = css_text.gsub(/\/\*.*?\*\//m, "")
  rules = []
  i = 0
  len = clean.length
  selector_buf = +""
  media_context = nil
  while i < len
    char = clean[i]
    if char == "{"
      sel = selector_buf.strip
      if sel.start_with?("@")
        media_context = sel
        selector_buf.clear
        i += 1
        next
      end
      depth = 1
      j = i + 1
      while j < len && depth > 0
        depth += 1 if clean[j] == "{"
        depth -= 1 if clean[j] == "}"
        j += 1
      end
      decl_text = clean[(i + 1)...(j - 1)]
      i = j
      decls = {}
      decl_text.split(";").each do |part|
        part = part.strip
        next if part.empty?
        prop, val = part.split(":", 2)
        next unless prop && val
        decls[prop.strip.downcase] = val.strip
      end
      sel.split(",").each do |s|
        rules << { selector: s.strip, declarations: decls, raw_body: decl_text, media: media_context }
      end
      selector_buf.clear
      next
    elsif char == "}"
      media_context = nil
      selector_buf.clear
      i += 1
      next
    else
      selector_buf << char
      i += 1
    end
  end
  rules
end

# 1. Tokens (criterion 2)
base_css = ROOT.join("assets/css/base.css").read
fail!("missing base.css") if base_css.empty?

expected_light_tokens = {
  "--mark-a" => "18%",
  "--mark-b" => "14%",
  "--mark-c" => "5%",
  "--mark-strong-a" => "28%",
  "--mark-strong-b" => "22%",
  "--mark-strong-c" => "8%",
  "--mark-facet-a" => "14%",
  "--mark-facet-b" => "11%",
  "--mark-facet-c" => "4%",
  "--mark-hover-a" => "30%",
  "--mark-hover-b" => "24%",
  "--mark-hover-c" => "9%",
  "--mark-quiet-a" => "12%",
  "--mark-quiet-b" => "9%",
  "--mark-quiet-c" => "3%"
}

expected_dark_tokens = {
  "--mark-a" => "14%",
  "--mark-b" => "10%",
  "--mark-c" => "4%",
  "--mark-strong-a" => "22%",
  "--mark-strong-b" => "17%",
  "--mark-strong-c" => "6%",
  "--mark-facet-a" => "14%",
  "--mark-facet-b" => "11%",
  "--mark-facet-c" => "4%",
  "--mark-hover-a" => "24%",
  "--mark-hover-b" => "18%",
  "--mark-hover-c" => "7%",
  "--mark-quiet-a" => "10%",
  "--mark-quiet-b" => "7%",
  "--mark-quiet-c" => "3%"
}

expected_light_tokens.each do |k, v|
  fail!("missing light token #{k}: #{v}") unless base_css.match?(/#{Regexp.escape(k)}\s*:\s*#{Regexp.escape(v)}/)
end

expected_dark_tokens.each do |k, v|
  fail!("missing dark token #{k}: #{v}") unless base_css.match?(/\[data-theme=["']dark["']\].*?#{Regexp.escape(k)}\s*:\s*#{Regexp.escape(v)}/m)
end

# 2. Borders and rings (criterion 1)
files_to_check = {
  "base.css" => ROOT.join("assets/css/base.css").read,
  "chrome.css" => ROOT.join("assets/css/ledger/chrome.css").read,
  "writing.css" => ROOT.join("assets/css/ledger/writing.css").read,
  "sources.css" => ROOT.join("assets/css/ledger/sources.css").read,
  "bibliography.css" => ROOT.join("assets/css/ledger/bibliography.css").read,
  "cv.css" => ROOT.join("assets/css/ledger/cv.css").read,
  "detail.css" => ROOT.join("assets/css/ledger/detail.css").read,
  "home.css" => ROOT.join("assets/css/ledger/home.css").read
}

parsed_files = files_to_check.transform_values { |css| parse_css_rules(css) }

# Selector checks across files for families F1-F8 and M (excluding unchanged F4c)
modified_selectors = [
  # F1
  { file: "base.css", selector: ".ledger-chip" },
  { file: "base.css", selector: "a.ledger-chip" },
  # F3
  { file: "base.css", selector: ".lang-pill" },
  { file: "sources.css", selector: ".source-facets .source-facet" },
  { file: "sources.css", selector: ".source-facets .ledger-chip" },
  { file: "sources.css", selector: ".source-facets .lang-pill" },
  { file: "bibliography.css", selector: ".bib-facet" },
  { file: "bibliography.css", selector: ".bib-facets .lang-pill" },
  # F4a
  { file: "writing.css", selector: ".writing-rail .listing-filter-chip" },
  # F4b
  { file: "base.css", selector: ".listing-filter-chip" },
  # F5
  { file: "base.css", selector: ".ledger-cta--emphasis" },
  { file: "base.css", selector: ".ledger-cta--emphasis-alt" },
  # F7
  { file: "detail.css", selector: ".detail-action" },
  { file: "detail.css", selector: ".detail-type-size-trigger" },
  { file: "base.css", selector: ".listing-filter-trigger" },
  # F8
  { file: "detail.css", selector: ".article-related-section-pill" },
  # M
  { file: "chrome.css", selector: ".site-rail-link.is-active" }
]

modified_selectors.each do |item|
  matching = parsed_files[item[:file]].select { |r| r[:selector] == item[:selector] }
  fail!("selector #{item[:selector]} not found in #{item[:file]}") if matching.empty?

  matching.each do |r|
    decls = r[:declarations]
    # Check borders: border should be 0, none, or border-color transparent
    if decls.key?("border")
      val = decls["border"]
      unless val == "0" || val == "none" || val.start_with?("0") || val.include?("transparent")
        fail!("unexpected non-zero border '#{val}' in #{item[:file]} for #{item[:selector]}")
      end
    end
    if decls.key?("border-color")
      val = decls["border-color"]
      fail!("border-color not transparent in #{item[:file]} for #{item[:selector]}") unless val == "transparent"
    end
    # Check inset ring
    if decls.key?("box-shadow")
      val = decls["box-shadow"]
      fail!("inset ring found in #{item[:file]} for #{item[:selector]}: #{val}") if val.include?("inset")
    end
  end
end

# 3. Filter states (criterion 3)
writing_rules = parsed_files["writing.css"]
writing_filter = writing_rules.find { |r| r[:selector] == ".writing-rail .listing-filter-chip" }
fail!("missing .writing-rail .listing-filter-chip in writing.css") unless writing_filter
fail!(".writing-rail .listing-filter-chip still has border-left") if writing_filter[:declarations].key?("border-left")
fail!(".writing-rail .listing-filter-chip needs align-self: flex-start") unless writing_filter[:declarations]["align-self"] == "flex-start"

# F4c in cv.css must be unchanged
cv_css = files_to_check["cv.css"]
fail!("F4c .cv-timeline-option must stay unchanged") unless cv_css.include?(".cv-timeline-option") && cv_css.include?("border-left: 2px solid transparent")

# Selected filters set color: var(--color-on-surface)
active_panel_filter = parsed_files["base.css"].find { |r| r[:selector] == ".listing-filter-chip.is-active" }
fail!("missing .listing-filter-chip.is-active in base.css") unless active_panel_filter
fail!(".listing-filter-chip.is-active must have color: var(--color-on-surface)") unless active_panel_filter[:declarations]["color"] == "var(--color-on-surface)"

active_rail_filter = parsed_files["writing.css"].find { |r| r[:selector] == ".writing-rail .listing-filter-chip.is-active" }
fail!("missing .writing-rail .listing-filter-chip.is-active in writing.css") unless active_rail_filter
fail!(".writing-rail .listing-filter-chip.is-active must have color: var(--color-on-surface)") unless active_rail_filter[:declarations]["color"] == "var(--color-on-surface)"

# 4. Solid mark (criterion 4 and §2.2)
home_f6 = parsed_files["home.css"].find { |r| r[:selector] == ".home-featured-foot .home-featured-cta" }
fail!("missing .home-featured-foot .home-featured-cta in home.css") unless home_f6
fail!("home F6 CTA must have color: var(--color-on-primary)") unless home_f6[:declarations]["color"] == "var(--color-on-primary)"
fail!("home F6 CTA must use solid mark recipe with calc(100% - 0.8rem)") unless home_f6[:declarations]["background"]&.include?("calc(100% - 0.8rem)")

home_f6_hover = parsed_files["home.css"].find { |r| r[:selector] == ".home-featured-foot .home-featured-cta:hover" }
fail!("missing .home-featured-foot .home-featured-cta:hover in home.css") unless home_f6_hover
fail!("home F6 CTA hover must be solid var(--color-primary)") unless home_f6_hover[:declarations]["background"] == "var(--color-primary)"

writing_f6 = parsed_files["writing.css"].find { |r| r[:selector] == ".writing-index .writing-lead-foot .writing-lead-cta" }
fail!("missing .writing-index .writing-lead-foot .writing-lead-cta in writing.css") unless writing_f6
fail!("writing F6 CTA must have color: var(--color-on-primary)") unless writing_f6[:declarations]["color"] == "var(--color-on-primary)"
fail!("writing F6 CTA must use solid mark recipe with calc(100% - 0.8rem)") unless writing_f6[:declarations]["background"]&.include?("calc(100% - 0.8rem)")

writing_f6_hover = parsed_files["writing.css"].find { |r| r[:selector] == ".writing-index .writing-lead-cta:hover" }
fail!("missing .writing-index .writing-lead-cta:hover in writing.css") unless writing_f6_hover
fail!("writing F6 CTA hover must be solid var(--color-primary)") unless writing_f6_hover[:declarations]["background"] == "var(--color-primary)"

# 5. Strong buttons & Action margins (criterion 4)
f5_emp = parsed_files["base.css"].find { |r| r[:selector] == ".ledger-cta--emphasis" }
fail!("missing .ledger-cta--emphasis") unless f5_emp
fail!(".ledger-cta--emphasis must set margin: 1px") unless f5_emp[:declarations]["margin"] == "1px"

f5_alt = parsed_files["base.css"].find { |r| r[:selector] == ".ledger-cta--emphasis-alt" }
fail!("missing .ledger-cta--emphasis-alt") unless f5_alt
fail!(".ledger-cta--emphasis-alt must set margin: 1px") unless f5_alt[:declarations]["margin"] == "1px"

f5_hover = parsed_files["base.css"].find { |r| r[:selector] == ".ledger-cta--emphasis:hover" }
fail!("missing .ledger-cta--emphasis:hover") unless f5_hover
fail!(".ledger-cta--emphasis:hover must keep background: var(--color-primary)") unless f5_hover[:declarations]["background"] == "var(--color-primary)"

f5_alt_hover = parsed_files["base.css"].find { |r| r[:selector] == ".ledger-cta--emphasis-alt:hover" }
fail!("missing .ledger-cta--emphasis-alt:hover") unless f5_alt_hover
fail!(".ledger-cta--emphasis-alt:hover must keep background: var(--color-secondary)") unless f5_alt_hover[:declarations]["background"] == "var(--color-secondary)"

detail_action = parsed_files["detail.css"].find { |r| r[:selector] == ".detail-action" }
fail!("missing .detail-action in detail.css") unless detail_action
fail!(".detail-action must set margin: 1px") unless detail_action[:declarations]["margin"] == "1px"

detail_type_size = parsed_files["detail.css"].find { |r| r[:selector] == ".detail-type-size-trigger" }
fail!("missing .detail-type-size-trigger in detail.css") unless detail_type_size
fail!(".detail-type-size-trigger must set margin: 1px") unless detail_type_size[:declarations]["margin"] == "1px"

filter_trigger = parsed_files["base.css"].find { |r| r[:selector] == ".listing-filter-trigger" }
fail!("missing .listing-filter-trigger in base.css") unless filter_trigger
fail!(".listing-filter-trigger must set margin: 1px") unless filter_trigger[:declarations]["margin"] == "1px"

# 6. Variants (criterion 8 and §2.3)
base_rules = parsed_files["base.css"]
var_a = base_rules.find { |r| r[:selector].include?(":nth-child(3n+1)") }
var_b = base_rules.find { |r| r[:selector].include?(":nth-child(3n+2)") }
var_c = base_rules.find { |r| r[:selector].include?(":nth-child(3n)") && !r[:selector].include?("3n+") }

fail!("missing nth-child(3n+1) variant rule") unless var_a
fail!("missing nth-child(3n+2) variant rule") unless var_b
fail!("missing nth-child(3n) variant rule") unless var_c

[var_a, var_b, var_c].each do |rule|
  rule[:declarations].each_key do |prop|
    fail!("variant rule #{rule[:selector]} modifies non-mk property #{prop}") unless prop.start_with?("--mk-")
  end
end

fail!("variant A angle must be 104deg") unless var_a[:declarations]["--mk-angle"] == "104deg"
fail!("variant A s0 must be 0.9%") unless var_a[:declarations]["--mk-s0"] == "0.9%"
fail!("variant A s1 must be 2.6%") unless var_a[:declarations]["--mk-s1"] == "2.6%"
fail!("variant A mid must be 58%") unless var_a[:declarations]["--mk-mid"] == "58%"
fail!("variant A end must be 98%") unless var_a[:declarations]["--mk-end"] == "98%"
fail!("variant A h must be 100%") unless var_a[:declarations]["--mk-h"] == "100%"

fail!("variant B angle must be 97deg") unless var_b[:declarations]["--mk-angle"] == "97deg"
fail!("variant B s0 must be 1.8%") unless var_b[:declarations]["--mk-s0"] == "1.8%"
fail!("variant B s1 must be 4%") unless var_b[:declarations]["--mk-s1"] == "4%"
fail!("variant B mid must be 66%") unless var_b[:declarations]["--mk-mid"] == "66%"
fail!("variant B end must be 96%") unless var_b[:declarations]["--mk-end"] == "96%"
fail!("variant B h must be 88%") unless var_b[:declarations]["--mk-h"] == "88%"
fail!("variant B y must be 85%") unless var_b[:declarations]["--mk-y"] == "85%"

fail!("variant C angle must be 111deg") unless var_c[:declarations]["--mk-angle"] == "111deg"
fail!("variant C s0 must be 0.4%") unless var_c[:declarations]["--mk-s0"] == "0.4%"
fail!("variant C s1 must be 1.8%") unless var_c[:declarations]["--mk-s1"] == "1.8%"
fail!("variant C mid must be 48%") unless var_c[:declarations]["--mk-mid"] == "48%"
fail!("variant C end must be 92%") unless var_c[:declarations]["--mk-end"] == "92%"
fail!("variant C h must be 90%") unless var_c[:declarations]["--mk-h"] == "90%"
fail!("variant C y must be 20%") unless var_c[:declarations]["--mk-y"] == "20%"

# 7. Focus (criterion 5 and §3.1)
focus_rule = base_rules.find do |r|
  r[:selector].include?(":focus-visible") &&
    r[:declarations]["outline"]&.include?("2px solid") &&
    r[:declarations]["outline-offset"] == "2px"
end
fail!("missing 2px outline :focus-visible rule covering interactive pills") unless focus_rule

# 8. Menu rule reads tokens (criterion 1)
rail_active = parsed_files["chrome.css"].find { |r| r[:selector] == ".site-rail-link.is-active" }
fail!("missing .site-rail-link.is-active in chrome.css") unless rail_active
fail!(".site-rail-link.is-active must read var(--mark-a)") unless rail_active[:declarations]["background"]&.include?("var(--mark-a)")
fail!(".site-rail-link.is-active must read var(--mark-b)") unless rail_active[:declarations]["background"]&.include?("var(--mark-b)")
fail!(".site-rail-link.is-active must read var(--mark-c)") unless rail_active[:declarations]["background"]&.include?("var(--mark-c)")

puts "PASS test-highlighter-pills"
