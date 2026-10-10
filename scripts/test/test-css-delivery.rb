#!/usr/bin/env ruby
# frozen_string_literal: true

# Stylesheet delivery (PLT-AC-19).
# The Play CDN blocked first paint, and every page linked every ledger sheet.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-css-delivery: #{message}"
  exit 1
end

shell = ROOT.join("_layouts/shell.html").read
css = ROOT.join("assets/css/tailwind.css").read

fail!("shell still loads the Tailwind Play CDN") if shell.include?("cdn.tailwindcss.com")
fail!("shell still loads tailwind-play.js") if shell.include?("tailwind-play.js")
fail!("shell does not link the compiled utilities") unless shell.include?('href="/assets/css/tailwind.css"')
fail!("shell still links every ledger sheet") if shell.include?('sheet.path contains "/assets/css/ledger/"')
fail!("shell still links the empty cv.css") if shell.include?('href="/assets/css/cv.css"')
fail!("empty cv.css is still in the tree") if ROOT.join("assets/css/cv.css").exist?
fail!("home layout has no ledger sheet") unless shell.include?('when "home"') && shell.include?('assign _ledger = "home"')
fail!("articles layout misses the writing sheet") unless shell.include?("writing|detail")
fail!("shared chrome is not always linked") unless shell.include?("ledger/chrome.css") && shell.include?("ledger/footer.css")
fail!("compiled utilities are missing flex") unless css.include?(".flex{")
fail!("compiled utilities dropped the separator tint") unless css.include?("bg-outline-variant\\/30")
fail!("compiled utilities dropped the dev-reexport border") unless css.include?("border-tertiary\\/40")

puts "PASS test-css-delivery"
