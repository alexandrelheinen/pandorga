#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-26. Listing scripts follow the page, and the runtime stays after
# it. Those scripts have to start once the runtime is assigned. The
# Lighthouse script then loads the built example home and fails when the
# project, article, or post bands are still empty.

require "pathname"
require "open3"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-home-lists: #{message}"
  exit 1
end

runtime = ROOT.join("_includes/page/content-runtime.html").read
assigned = runtime.index("window.ContentRuntime = (function () {")
dispatched = runtime.index("document.dispatchEvent(new CustomEvent('pandorga:runtime'))")
fail!("runtime does not assign ContentRuntime") unless assigned
fail!("runtime does not announce pandorga:runtime") unless dispatched
fail!("runtime announces itself before the assignment") unless dispatched > assigned
fail!("runtime moved back ahead of the page") unless ROOT.join("_layouts/shell.html").read.index("{{ content }}") <
  ROOT.join("_layouts/shell.html").read.index("page/content-runtime.html")

pages = %w[
  _layouts/home.html
  _layouts/articles.html
  _layouts/blog.html
  _layouts/projects.html
  _layouts/cv.html
  _layouts/resources.html
  _layouts/bibliography.html
  _includes/page/network-graph.html
  _includes/page/timeline-section.html
]
pages.each do |relative|
  text = ROOT.join(relative).read
  fail!("#{relative} does not wait for pandorga:runtime") unless text.include?("pandorga:runtime")
end

home = ROOT.join("_layouts/home.html").read
fail!("home paint still runs before the runtime") unless home.scan("pandorga:runtime").length >= 2
fail!("home bands still fill in one turn") unless home.include?("scheduler.yield") && home.include?("await afterPaint()")
fail!("specimen measurement does not yield") unless home.include?("await measureTallestSpecimen()")
fail!("home still fills every band inside one callback") if home.include?("sections.forEach(function (section) { fillBand(section, index); })")
fragments = ROOT.join("_includes/content-runtime/60-fragments.html").read
fail!("home section markdown still runs in one turn") unless fragments.include?("function yieldToMain()") &&
  fragments.include?("return yieldToMain().then(function () {")
listing = ROOT.join("_includes/content-runtime/40-listing.html").read
fail!("date formatting builds a new formatter per card") unless listing.include?("dateFormatters")

marked = ROOT.join("_includes/content-runtime/00-config.html").read
fail!("markdown library no longer defers") unless marked.include?("<script defer ")

shell = ROOT.join("_layouts/shell.html").read
fail!("text faces no longer wait for the first paint") unless shell.scan("requestAnimationFrame").length >= 2
fail!("icon subset link was removed") unless shell.include?("__pandorgaIconsHref")

spec = ROOT.join("docs/spec.md").read
fail!("spec is missing PLT-AC-26") unless spec.include?("PLT-AC-26")
fail!("spec no longer keeps the runtime after the page") unless spec.include?("runtime stays after the page")

lighthouse = ROOT.join("scripts/lighthouse-home.sh").read
checker = lighthouse.index("check_home_lists.mjs")
score = lighthouse.index("Lighthouse mobile (one run)")
fail!("lighthouse script does not load the home lists") unless checker
fail!("list check runs only after the score") unless score && checker < score

probe = ROOT.join("scripts/check_home_lists.mjs").read
fail!("probe ignores the project inventory") unless probe.include?("#home-projects .home-project-inventory-row")
fail!("probe ignores article cards") unless probe.include?("#home-articles .home-featured, #home-articles .ledger-card")
fail!("probe ignores the phone viewport") unless probe.include?("name: 'mobile'")
fail!("probe ignores the desktop viewport") unless probe.include?("name: 'desktop'")
fail!("probe does not pin DevTools to IPv4") unless probe.include?("--remote-debugging-address=127.0.0.1")
fail!("probe gives Chrome only a few seconds to open DevTools") unless probe.include?("attempt < 200")

_out, err, status = Open3.capture3("node", "--check", ROOT.join("scripts/check_home_lists.mjs").to_s)
fail!("home list probe is not valid JavaScript\n#{err}") unless status.success?

puts "PASS test-home-lists"
