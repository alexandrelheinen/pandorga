#!/usr/bin/env ruby
# frozen_string_literal: true

# Hero LCP, listing/CV shift, revision contrast, inventory button.
# PLT-AC-16, PLT-AC-17, PLT-AC-18. The subtitle size is PLT-AC-13.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-hydrate-reserve: #{message}"
  exit 1
end

shell = ROOT.join("_layouts/shell.html").read
preload = ROOT.join("_includes/theme/critical-preload.html").read
home = ROOT.join("_layouts/home.html").read
articles = ROOT.join("_layouts/articles.html").read
cv = ROOT.join("_layouts/cv.html").read
fragments = ROOT.join("_includes/content-runtime/60-fragments.html").read
listing = ROOT.join("_includes/content-runtime/41-listing-helpers.html").read
blocks = ROOT.join("_includes/content-runtime/43-blocks.html").read
home_css = ROOT.join("assets/css/ledger/home.css").read
writing_css = ROOT.join("assets/css/ledger/writing.css").read
cv_css = ROOT.join("assets/css/ledger/cv.css").read

fail!("shell does not preload critical JSON") unless shell.include?("theme/critical-preload.html")
fail!("home preload misses the hero summary") unless preload.include?("pages/cv/summary.json")
fail!("home preload misses the subtitle") unless preload.include?("pages/home/subtitle.json")
fail!("articles preload misses the writing index") unless preload.include?("data/writing_index.json")
fail!("preload must run before stylesheets") unless shell.index("critical-preload.html") < shell.index('href="/assets/css/base.css"')

fail!("loadJson ignores the preload cache") unless fragments.include?("window.__pandorgaPreload")
fail!("quiet fragments still write Loading...") unless fragments.include?("data-content-quiet")
fail!("a painted fragment is written twice") unless fragments.include?("data-content-painted")

fail!("hero summary is not quiet") unless home.include?('data-content-fragment="cv/summary" data-content-quiet')
fail!("hero subtitle is not quiet") unless home.include?('data-content-fragment="home/subtitle" data-content-quiet')
fail!("hero does not paint the summary early") unless home.include?("paint('home-cv-summary'")
fail!("hero subtitle size left --type-body") unless home_css.include?("font-size: var(--type-body);")
tagline = home_css[/\.home-hero-tagline \{[^}]*\}/m]
fail!("tagline rule missing") unless tagline
fail!("tagline is not body size") unless tagline.include?("font-size: var(--type-body);")
fail!("hero summary has no reserved box") unless home_css.include?(".home-hero-summary:empty")

fail!("articles listing has no row reserve") unless articles.include?("writing-reserve-row")
fail!("articles lead has no reserved box") unless writing_css.include?("#articles-lead.is-pending:empty")
fail!("articles lead reserve stays after the listing decides") if writing_css.match?(/^#articles-lead:empty/m)
fail!("articles lead is not pending until the listing decides") unless articles.include?('id="articles-lead" class="is-pending"')
fail!("page 2 does not drop the lead reserve before paint") unless articles.include?("!(page > 1)")
fail!("listing never clears the lead reserve") unless articles.include?("leadRoot.classList.remove('is-pending')")
fail!("CV experience has no reserve") unless cv.include?('id="cv-experience-list"') && cv.include?("data-content-reserve")
fail!("CV summary still ships Loading...") if cv.include?("Loading...")
fail!("showLoadingState collapses a reserve") unless listing.include?("data-content-reserve")
fail!("CV reserve card has no height") unless cv_css.include?(".cv-reserve-card")

revised = writing_css[/\.writing-index \.writing-revised \{[^}]+\}/m]
fail!("writing-revised rule missing") unless revised
fail!("writing-revised still fades the ink") if revised.include?("color-mix") || revised.include?("transparent")
fail!("writing-revised is not the variant ink") unless revised.include?("color: var(--color-on-surface-variant);")

selectable = blocks[/function renderProjectInventoryRow.*?function renderSystemCard/m]
fail!("inventory renderer missing") unless selectable
fail!("selectable inventory row is still an article with role=button") if selectable.include?("role', 'button'") || selectable.include?('role", "button"') || selectable.include?("setAttribute('role'")
fail!("selectable inventory row is not a button") unless selectable.include?("createElement(selectable ? 'button' : 'article')")

puts "PASS test-hydrate-reserve"
