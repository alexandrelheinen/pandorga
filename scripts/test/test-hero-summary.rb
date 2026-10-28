#!/usr/bin/env ruby
# frozen_string_literal: true

# Hero summary is HTML at build time. The empty box and the sans fallback
# were the home CLS. The font stylesheet must not precede the preload
# script: that script is parser-blocking, so a sheet above it holds first
# paint on fonts.googleapis.com. PLT-AC-23.

require "pathname"
require "tmpdir"
require "fileutils"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-hero-summary: #{message}"
  exit 1
end

require_relative "../../lib/pandorga/hero_summary"

Dir.mktmpdir("hero-summary") do |dir|
  fail!("missing file must not invent a summary") unless Pandorga::HeroSummary.markdown(dir) == ""

  path = File.join(dir, "content/pages/cv")
  FileUtils.mkdir_p(path)
  File.write(File.join(path, "summary.md"), "Ada Example designs publishing frames.\n")
  plain = Pandorga::HeroSummary.markdown(dir)
  fail!("plain summary was #{plain.inspect}") unless plain == "Ada Example designs publishing frames."

  File.write(File.join(path, "summary.md"), "---\ntitle: Summary\n---\nAfter the matter.\n")
  mattered = Pandorga::HeroSummary.markdown(dir)
  fail!("front matter leaked: #{mattered.inspect}") unless mattered == "After the matter."
end

# PLT-AC-54: the hero has its own file; absent falls back, blank hides.
Dir.mktmpdir("hero-summary-field") do |dir|
  cv = File.join(dir, "content/pages/cv")
  home = File.join(dir, "content/pages/home")
  FileUtils.mkdir_p([cv, home])
  File.write(File.join(cv, "summary.md"), "Professional summary.\n")

  fail!("absent hero file must fall back to the CV summary") unless Pandorga::HeroSummary.markdown(dir) == "Professional summary."
  fail!("absent hero file must not hide the hero summary") if Pandorga::HeroSummary.hidden?(dir)

  File.write(File.join(home, "summary.md"), "What the site holds.\n")
  own = Pandorga::HeroSummary.markdown(dir)
  fail!("hero file must win over the CV summary, got #{own.inspect}") unless own == "What the site holds."
  fail!("a hero file with text must not hide") if Pandorga::HeroSummary.hidden?(dir)

  File.write(File.join(home, "summary.md"), "---\ntitle: Hero\n---\n  \n")
  fail!("a blank hero file must hide the hero summary") unless Pandorga::HeroSummary.hidden?(dir)
  fail!("a blank hero file must not fall back to the CV summary") unless Pandorga::HeroSummary.markdown(dir) == ""

  FileUtils.rm_rf(cv)
  FileUtils.rm_f(File.join(home, "summary.md"))
  fail!("with neither file the hero must stay a fragment, not hide") if Pandorga::HeroSummary.hidden?(dir)
end

tag = ROOT.join("lib/pandorga/jekyll/plugins/hero_summary.rb").read
fail!("hero tag ignores a blank hero file") unless tag.include?("HeroSummary.hidden?")

cv_layout = ROOT.join("_layouts/cv.html").read
fail!("CV page Summary must keep the cv/summary fragment") unless cv_layout.include?('data-content-fragment="cv/summary"')
fail!("CV page must not read the hero file") if cv_layout.include?("home/summary")

schema = ROOT.join("studio/schema.yml").read
hero_entry = schema[/- name: home_summary\n(?:        .*\n)+/]
fail!("Studio has no Hero summary entry") unless hero_entry
fail!("Studio Hero summary label") unless hero_entry.include?("label: Hero summary")
fail!("Studio Hero summary path") unless hero_entry.include?("path: content/pages/home/summary.md")
fail!("Studio Hero summary is not a markdown body") unless hero_entry.include?("component: markdown_body")
presentation = schema[/- name: presentation\n.*?(?=\n  - name: )/m]
fail!("Hero summary is not in the Presentation group") unless presentation&.include?("- name: home_summary")
fail!("Studio public CV entry is not labelled CV page") unless schema.match?(/- name: cv_summary_public\n\s+label: CV page\n/)

fallback = Pandorga::HeroSummary.element("")
fail!("missing summary must stay a quiet fragment") unless fallback.include?('data-content-fragment="cv/summary" data-content-quiet')
fail!("missing summary must not claim to be static") if fallback.include?("data-content-static")

static = Pandorga::HeroSummary.element("<p>Ada Example designs publishing frames.</p>")
fail!("static summary dropped the sentence") unless static.include?("Ada Example designs publishing frames.")
fail!("static summary is not marked static") unless static.include?("data-content-static")
fail!("static summary still hydrates") if static.include?("data-content-fragment")

home = ROOT.join("_layouts/home.html").read
home_css = ROOT.join("assets/css/ledger/home.css").read
shell = ROOT.join("_layouts/shell.html").read
fonts = ROOT.join("_includes/theme/font-loader.html").read
shared = ROOT.join("_data/themes/shared.yml").read
fragments = ROOT.join("_includes/content-runtime/60-fragments.html").read

fail!("home does not render the summary tag") unless home.include?("pandorga_hero_summary")
fail!("early paint replaces a static summary") unless home.include?("el.hasAttribute('data-content-static')")
fail!("summary keeps a guessed empty box") if home_css.include?(".home-hero-summary:empty")
fail!("a static summary can still be rewritten") unless fragments.include?("data-content-static")
fail!("font stylesheet dropped display=swap") unless fonts.include?("&display=swap")

font_at = shell.index("theme/font-loader.html")
base_at = shell.index('href="/assets/css/base.css"')
script_at = shell.index("theme/critical-preload.html")
preconnect_at = shell.index("fonts.googleapis.com")
fail!("font loader missing") unless font_at && script_at && base_at
fail!("font stylesheet precedes the preload script") unless script_at < font_at
fail!("font stylesheet precedes local CSS") unless base_at < font_at
fail!("font host is not preconnected before the preload script") unless preconnect_at && preconnect_at < script_at
fail!("body fallback is not sans-serif") unless shared.include?('body_fallback: "sans-serif"')

puts "PASS test-hero-summary"
