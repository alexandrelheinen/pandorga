#!/usr/bin/env ruby
# frozen_string_literal: true

# Shell accessibility (skip link and home-link name).
# The top bar and footer used site.author alone, so a site with no author
# exposed the accessible name " – Home" and hid the visible wordmark.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
SHELL = ROOT.join("_layouts/shell.html").read
FOOTER = ROOT.join("_includes/page/site-footer.html").read
CSS = ROOT.join("assets/css/ledger/chrome.css").read

def fail!(message)
  warn "FAIL test-shell-a11y: #{message}"
  exit 1
end

fail!("missing skip link") unless SHELL.include?('class="skip-link"') && SHELL.include?('href="#page-content"')
fail!("missing skip target") unless SHELL.include?('id="page-content"')
fail!("skip link is not shown on focus") unless CSS.include?(".skip-link:focus")

bare = 'aria-label="{{ site.author }} – Home"'
fail!("shell home link still uses site.author alone") if SHELL.include?(bare)
fail!("footer home link still uses site.author alone") if FOOTER.include?(bare)
fail!("shell home link needs an identity.name fallback") unless SHELL.include?("site.pandorga.identity.name")
fail!("footer home link needs an identity.name fallback") unless FOOTER.include?("site.pandorga.identity.name")

fail!("top bar is still a nav") if SHELL.include?('<nav class="sticky')
fail!("top bar is not a header") unless SHELL.include?('<header class="sticky top-0 z-50 bg-surface">')
fail!("section links lost their name") unless SHELL.include?('aria-label="Sections"')
navs = SHELL.scan(/<nav\b/).size
fail!("shell should have one nav landmark, found #{navs}") unless navs == 1

# Decorative Material Symbols sit beside a text label. Without aria-hidden
# the ligature ("arrow_left_alt", "shuffle", an icon name) is read aloud.
ICON_FILES = [
  ROOT.join("_layouts/text.html"),
  ROOT.join("_includes/content-runtime/50-detail.html"),
  ROOT.join("_includes/content-runtime/60-fragments.html"),
  ROOT.join("_includes/content-runtime/30-includes.html")
].freeze

ICON_FILES.each do |path|
  path.read.each_line.with_index(1) do |line, number|
    next unless line.include?("material-symbols-outlined")
    next if line.include?("querySelector")
    next if line.include?("aria-hidden")
    # Class token handed to a later span that already sets aria-hidden.
    next if line.include?("cls:")

    fail!("#{path.relative_path_from(ROOT)}:#{number}: decorative icon is exposed")
  end
end

# PLT-AC-37. The listing shell keeps its index h1 in the document. A detail
# URL then adds the entry title, so the page has two h1 elements. The runtime
# demotes the index heading and sets the document title and lang from the entry.
DETAIL = ROOT.join("_includes/content-runtime/50-detail.html").read
BOOT = ROOT.join("_includes/content-runtime/90-bootstrap.html").read
fail!("detail runtime does not demote the listing h1") unless DETAIL.include?("data-listing-heading") && DETAIL.include?("concealListingHeader")
fail!("detail runtime does not restore the listing document") unless DETAIL.include?("function restoreListingDocument")
fail!("detail runtime does not set html lang") unless DETAIL.include?("document.documentElement.lang")
fail!("detail runtime dropped the entry title h1") unless DETAIL.include?('<h1 class="text-title">')
fail!("restoreListingDocument is not on the runtime") unless BOOT.include?("restoreListingDocument: restoreListingDocument")

%w[articles blog projects cv].each do |layout|
  source = ROOT.join("_layouts/#{layout}.html").read
  fail!("#{layout} listing does not restore the document") unless source.include?("restoreListingDocument()")
end

puts "PASS test-shell-a11y"
