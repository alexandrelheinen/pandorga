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

puts "PASS test-shell-a11y"
