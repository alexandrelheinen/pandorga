#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-52. Home article cards keep tags and "Read" on one row, all use the
# band accent, and a band header whose texts are all empty is removed.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-home-article-cards: #{message}"
  exit 1
end

blocks = ROOT.join("_includes/content-runtime/43-blocks.html").read
home_layout = ROOT.join("_layouts/home.html").read
css = ROOT.join("assets/css/ledger/home.css").read
band_index = ROOT.join("_includes/home/band-index.html").read
fragments = ROOT.join("_includes/content-runtime/60-fragments.html").read

# 1. Foot row.
card = blocks[/function renderArchiveCard\(.*?\n    \}\n/m] or fail!("renderArchiveCard not found")
fail!("renderArchiveCard has no tagsInFoot option") unless card.include?("options.tagsInFoot")
chips_at = card.index("renderTagChips(")
foot_at = card.index("'<div class=\"ledger-card-foot\">'")
fail!("tag chips are not built before the foot") unless chips_at && foot_at && chips_at < foot_at
fail!("chips are not put inside the foot when tagsInFoot") unless card =~ /tagsInFoot[^\n]*\n?[^\n]*foot\s*\+?=\s*chips|foot\s*=\s*\(?options\.tagsInFoot/m
callers = Dir[ROOT.join("{_layouts,_includes}/**/*.html").to_s].select { |f| File.read(f).include?("tagsInFoot: true") }
fail!("tagsInFoot must be set by the home layout only, found #{callers.inspect}") unless callers.map { |f| File.basename(f) } == ["home.html"]
foot_rule = css[/^\.home-card-grid \.ledger-card-foot \{[^}]*\}/m] or fail!("no .home-card-grid .ledger-card-foot rule")
fail!(".home-card-grid .ledger-card-foot must space-between") unless foot_rule.include?("justify-content: space-between")
cta_rule = css[/^\.home-card-grid \.ledger-card-foot \.ledger-cta \{[^}]*\}/m]
fail!(".home-card-grid .ledger-card-foot .ledger-cta must take margin-left: auto") unless cta_rule&.include?("margin-left: auto")

# 2. One accent.
css.scan(/^([^{}\n]*\.home-card-grid[^{}\n]*)\{([^}]*)\}/m).each do |sel, body|
  if body =~ /border-top-color:\s*var\(--color-(secondary|tertiary)\)/
    fail!("#{sel.strip} rotates the card rule to --color-#{$1}")
  end
  fail!("#{sel.strip} keys a colour to :nth-child") if sel.include?("nth-child") && body =~ /color/
end
base = css[/^\.home-card-grid \.ledger-card \{[^}]*\}/m] or fail!("no .home-card-grid .ledger-card rule")
fail!("card top rule is not var(--color-primary)") unless base.include?("border-top-color: var(--color-primary)")

# 3. Build time.
fail!("band-index does not set data-home-label") unless band_index.include?("data-home-label=")
fail!("band-index does not guard the banner on empty header texts") unless band_index =~ /\{%-?\s*unless _hide_banner\s*-?%\}\s*<div class="ledger-section-banner"/m
fail!("band-index does not label the section when the banner is hidden") unless band_index =~ /_hide_banner\s*%\}\s*aria-label=/

# 4. Runtime.
apply = fragments[/function applyHomeSection\(.*?\n    \}\n/m] or fail!("applyHomeSection not found")
fail!("applyHomeSection does not drop an emptied banner") unless apply.include?("root.remove()") &&
  apply.include?("home-section-aside") && apply.include?("data-home-label")

puts "PASS test-home-article-cards"
