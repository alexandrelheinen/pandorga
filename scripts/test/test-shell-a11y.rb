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

# PLT-AC-46: Menu mark follows section accent on desktop rail, mobile menu unchanged
rail_link_markup = SHELL[/<nav class="site-rail".*?<\/nav>/m]
fail!("site-rail nav not found") unless rail_link_markup
fail!("active site-rail-link must get page-accent--{{ _p.accent }}") unless rail_link_markup.include?("page-accent--{{ _p.accent }}")
fail!("active site-rail-link accent must be guarded by != 'blue'") unless rail_link_markup.include?("_p.accent != 'blue'") || rail_link_markup.include?('_p.accent != "blue"')

mobile_menu = SHELL[/<div id="mobile-menu".*?<\/div>\s*<\/div>/m]
fail!("mobile menu not found") unless mobile_menu
fail!("mobile menu must not contain page-accent (PLT-AC-46)") if mobile_menu.include?("page-accent")
fail!("mobile menu must not contain gradient/mark (PLT-AC-46)") if mobile_menu.include?("linear-gradient") || mobile_menu.include?("ledger-mark")

EXPECTED_MOBILE_MENU = <<-'HTML'.strip
        <div id="mobile-menu"
          class="hidden absolute right-0 top-full mt-1 min-w-[14rem] py-2 bg-surface border border-gentle-subtle shadow-sm z-50"
          role="menu" aria-label="Explore">
          <div class="flex flex-col px-3 gap-0">
            {% for _group in site.data.nav %}
            {% unless forloop.first %}<div class="h-px bg-outline-variant/30 my-1.5" role="separator"></div>{% endunless %}
            {% for _item in _group.pages %}
            {% assign _key = _item.key %}
            {% assign _p = _all_pages | where: "key", _key | first %}
            {% comment %}The inactive state carries no weight class: Cabin's axis starts
            at 400 and the font loader requests nothing below it, so the `font-light` this
            used to set asked for a 300 that resolves straight back to 400 and changed
            nothing on the page. The variant ink is what marks the state.{% endcomment %}
            <a href="{{ _p.url }}" role="menuitem"
              class="flex items-center gap-2.5 font-body {% if nav_active == _key %}text-primary font-semibold{% else %}text-on-surface-variant hover:text-primary{% endif %} transition-colors duration-300 py-2 px-1">
              {% if _item.icon %}<span class="material-symbols-outlined text-lg shrink-0 flex items-center justify-center" aria-hidden="true">{{ _item.icon }}</span>{% endif %}
              <span class="leading-none">{{ _p.title }}</span>
            </a>
            {% endfor %}
            {% endfor %}
          </div>
        </div>
HTML

fail!("mobile menu is not byte-identical to pre-change snapshot (PLT-AC-46)") unless mobile_menu.strip == EXPECTED_MOBILE_MENU

puts "PASS test-shell-a11y"
