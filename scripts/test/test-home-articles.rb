#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-27. Home Articles band: titles are 2pt larger, and on a phone the
# featured card has more room above its text. Listed cards keep their padding.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-home-articles: #{message}"
  exit 1
end

home = ROOT.join("assets/css/ledger/home.css").read

fail!("featured article title is not 2pt larger") unless home.include?(
  '[data-home-kind="articles"] .home-featured-title'
) && home.include?("calc(var(--home-featured-title-size) + 2pt)")

fail!("listed article titles are not 2pt larger") unless home.include?(
  "calc(var(--type-card) + 2pt)"
) && home.include?('[data-home-kind="articles"] .home-card-grid .card-title')

phone = home[/^@media \(max-width: 767px\) \{\n  \[data-home-kind="articles"\] \.home-featured \{.*?\n  \}/m]
fail!("phone featured card has no extra top padding") unless phone && phone.include?("padding-top:")
fail!("phone featured padding changes the listed cards") if phone.include?("ledger-card") || phone.include?("home-card-grid")

puts "PASS test-home-articles"
