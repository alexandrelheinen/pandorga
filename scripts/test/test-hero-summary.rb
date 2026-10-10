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
fail!("body fallback is still a sans") unless shared.include?('body_fallback: "Georgia, serif"')

puts "PASS test-hero-summary"
