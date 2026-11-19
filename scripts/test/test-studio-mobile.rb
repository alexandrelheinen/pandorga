# frozen_string_literal: true

# Studio phone layout and theme (PLT-AC-107 and later).
# Static review of studio-app source. The built bundle is checked only for
# the version string once a build has been committed.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-studio-mobile: #{message}"
  exit 1
end

def read(rel)
  path = ROOT.join(rel)
  fail!("missing #{rel}") unless path.file?
  path.read
end

main = read("studio-app/src/main.js")
css = read("studio-app/src/styles/studio.css")
html = read("studio-app/index.html")
spec = read("docs/spec.md")

fail!("spec missing PLT-AC-107") unless spec.include?("PLT-AC-107")

# --- PLT-AC-107 sign-in appearance ---
appearance = main[/const CLERK_APPEARANCE = \{.*?\n\};/m]
fail!("CLERK_APPEARANCE missing") unless appearance

%w[
  colorPrimary
  colorPrimaryForeground
  colorForeground
  colorMutedForeground
  colorBackground
  colorInput
  colorInputForeground
  colorNeutral
  colorDanger
  fontFamilyButtons
].each do |key|
  fail!("CLERK_APPEARANCE missing #{key}") unless appearance.include?(key)
end

fail!("primary must use var(--primary)") unless appearance.include?("var(--primary)")
fail!("background must use var(--background)") unless appearance.include?("var(--background)")
fail!("foreground must use var(--on-surface)") unless appearance.include?("var(--on-surface)")
fail!("card background must not be hardcoded white") if appearance.include?('colorBackground: "#ffffff"')
fail!("legacy colorText must not be the text color") if appearance.include?("colorText:")
fail!("legacy colorTextSecondary must be gone") if appearance.include?("colorTextSecondary")
fail!("social buttons must be blockButton") unless appearance.include?("blockButton")
fail!("primary button must drop the gradient") unless appearance.include?('backgroundImage: "none"')
fail!("primary button must drop the shadow") unless appearance.include?("boxShadow: \"none\"")
fail!("cardBox must drop the shadow") unless appearance.include?("cardBox")

fail!("theme key must be site-theme") unless main.include?('const THEME_CHOICE_KEY = "site-theme"')
fail!("legacy studio-theme must be migrated") unless main.include?("studio-theme")
fail!("theme change must remount SignIn") unless main.include?("remountClerkSignIn")

gate = main[/function renderAuthGate\(clerk\) \{.*?\n\}/m]
fail!("renderAuthGate missing") unless gate
fail!("sign-in gate must offer the theme menu") unless gate.include?("renderThemeMenu")
fail!("sign-in title must mark the word edit") unless gate.include?("edit")

pending = main[/function renderPendingReviewGate\(.*?\n\}/m]
fail!("renderPendingReviewGate missing") unless pending
fail!("pending gate must offer the theme menu") unless pending.include?("renderThemeMenu")
fail!("pending Sign out must be the highlighter button") unless pending.include?("btn-primary")

fail!("index.html must not hardcode data-theme=light") if html.include?('data-theme="light"')
fail!("index.html must read site-theme before paint") unless html.include?("site-theme")
fail!("index.html must migrate studio-theme") unless html.include?("studio-theme")
fail!("index.html must set color-scheme") unless html.include?("colorScheme")
fail!("index.html must set the light theme-color") unless html.include?("#ffffff")
fail!("index.html must set the dark theme-color") unless html.include?("#0c0c0e")

fail!("auth gate must not keep a framed border") if css.match?(/\.auth-gate \{[^}]*border:\s*1px/m)

# --- PLT-AC-108 phone toolbar ---
fail!("spec missing PLT-AC-108") unless spec.include?("PLT-AC-108")
fail!("toolbar must render a short crumb") unless main.include?("studio-breadcrumb--short")
fail!("toolbar must keep the desktop crumb") unless main.include?("studio-breadcrumb--full")
fail!("theme and revert must live in the phone menu") unless main.include?("studio-nav-mobile-tools")

# The short crumb is the collection label only. The full title stays on the desktop crumb.
crumb = main[/function renderStudioBreadcrumb\(.*?\n\}/m]
fail!("renderStudioBreadcrumb missing") unless crumb
compact_branch = crumb[/if \(compact\) \{.*?\n  \}/m]
fail!("compact crumb branch missing") unless compact_branch
fail!("compact crumb must not print the entry title") if compact_branch.include?("fields?.title") || compact_branch.include?("state.file")

mobile_at = css.index("@media (max-width: 960px)")
fail!("960px studio rules missing") unless mobile_at
mobile_css = css[mobile_at..]
fail!("960px studio rules missing") unless mobile_css
fail!("phone bar must hide the full crumb") unless mobile_css.include?(".studio-breadcrumb--full") && mobile_css.match?(/\.studio-breadcrumb--full\s*\{[^}]*display:\s*none/m)
fail!("phone bar must show the short crumb on one line") unless mobile_css.match?(/\.studio-breadcrumb--short\s*\{[^}]*white-space:\s*nowrap/m)
fail!("phone bar must hide toolbar theme and revert") unless mobile_css.include?('[data-studio-action="discard"]')
fail!("phone menu must show the moved tools") unless mobile_css.include?(".studio-nav-mobile-tools")
fail!("phone bar must show the Studio word") unless mobile_css.match?(/\.studio-brand-name\s*\{[^}]*display:\s*inline/m)

# --- PLT-AC-109 phone list ---
fail!("spec missing PLT-AC-109") unless spec.include?("PLT-AC-109")
fail!("missing thumbnail must use the image icon") unless main.include?('text: "image"')
fail!("list meta must join date and language") unless main.include?('join(" · ")')
fail!("pager must use arrow buttons") unless main.include?("list-pager-arrow")
fail!("list controls must share a row") unless main.include?("list-controls-row")
fail!("page size must be marked for the phone hide") unless main.include?("list-page-size")
editor = main[/function renderEditorPane\(\) \{.*?\n\}/m]
fail!("renderEditorPane missing") unless editor
fail!("delete must be available in the editor") unless editor.include?("deleteEntry")
fail!("phone list must hide row actions") unless mobile_css.match?(/\.ledger-ops\s*\{[^}]*display:\s*none/m)
fail!("phone list must hide the status pill") unless mobile_css.match?(/\.ledger-status\s*\{[^}]*display:\s*none/m)
fail!("phone list must hide the page-size select") unless mobile_css.match?(/\.list-page-size\s*\{[^}]*display:\s*none/m)
fail!("phone titles must clamp to two lines") unless mobile_css.include?("-webkit-line-clamp: 2")
fail!("phone thumbs must be 56 by 42") unless mobile_css.include?("56px") && mobile_css.include?("42px")

# --- PLT-AC-110 phone editor ---
fail!("spec missing PLT-AC-110") unless spec.include?("PLT-AC-110")
fail!("editor must offer a Fields tab") unless main.include?('text: "Fields"')
fail!("editor must show an unsaved path marker") unless main.include?("editor-path-unsaved")
fail!("editor must pin a phone format bar") unless main.include?("editor-format-bar-mobile")
editor = main[/function renderEditorPane\(\) \{.*?\n\}/m]
fail!("renderEditorPane missing") unless editor
fail!("front matter must not stay an accordion in the editor") if editor.include?("front-matter")
fail!("phone format bar must pin to the bottom") unless mobile_css.match?(/\.editor-format-bar-mobile\s*\{[^}]*position:\s*fixed/m) && mobile_css.include?("bottom: 0")
fail!("phone editor must hide the top insert row") unless mobile_css.match?(/\.editor-chrome-actions\s*\{[^}]*display:\s*none/m)
fail!("phone body must drop the nested frame") unless mobile_css.match?(/\.editor-surface\s*\{[^}]*border:\s*0/m)

# --- PLT-AC-111 phone preview and version ---
fail!("spec missing PLT-AC-111") unless spec.include?("PLT-AC-111")
preview_doc = read("studio-app/src/preview/document.js")
preview_version = read("studio-app/src/preview/pandorga-version.js")
vite = read("studio-app/vite.config.js")
fail!("preview shell must include the article title") unless preview_doc.include?('id="preview-title"')
fail!("preview shell must include the article dates") unless preview_doc.include?('id="preview-dates"')
fail!("preview shell must include the standfirst") unless preview_doc.include?('id="preview-standfirst"')
fail!("preview must fill the article header") unless main.include?("fillPreviewArticleHeader")
fail!("narrow preview must default to mobile") unless main.include?('max-width: 960px') && main.include?('previewWidth:')
fail!("phone preview iframe must use the container width") unless mobile_css.match?(/\.preview-folio--mobile\s*>\s*\.preview-iframe\s*\{[^}]*width:\s*100%/m)
fail!("phone preview must hide the empty editor body") unless mobile_css.match?(/\.studio-body\.view-preview\s+\.editor-pane-fill\s*\{[^}]*display:\s*none/m)
fail!("Vite must read lib/pandorga/version.rb") unless vite.include?("lib/pandorga/version.rb")
fail!("Vite must inject __PANDORGA_VERSION__") unless vite.include?("__PANDORGA_VERSION__")
fail!("preview version must not hardcode a release number") if preview_version.match?(/PANDORGA_VERSION\s*=\s*"/)
fail!("preview version must use the injected constant") unless preview_version.include?("__PANDORGA_VERSION__")
version = read("lib/pandorga/version.rb")[/VERSION = "([^"]+)"/, 1]
studio_html = read("studio/index.html")
bundle_name = studio_html[%r{/studio/assets/(index-[A-Za-z0-9_-]+\.js)}, 1]
fail!("studio bundle missing") unless bundle_name
bundle = read("studio/assets/#{bundle_name}")
fail!("studio bundle must bake Pandorga::VERSION #{version}") unless bundle.include?(%("#{version}"))

# --- PLT-AC-112 token cleanup ---
fail!("spec missing PLT-AC-112") unless spec.include?("PLT-AC-112")
require "yaml"
light = YAML.safe_load(read("_data/themes/light.yml"))
dark = YAML.safe_load(read("_data/themes/dark.yml"))
{
  "--primary" => [light.dig("colors", "primary"), dark.dig("colors", "primary")],
  "--background" => [light.dig("neutrals", "background"), dark.dig("neutrals", "background")],
  "--on-surface" => [light.dig("neutrals", "on_surface"), dark.dig("neutrals", "on_surface")],
  "--outline" => [light.dig("neutrals", "outline"), dark.dig("neutrals", "outline")],
  "--error" => [light.dig("colors", "error") || light.dig("static", "error"), dark.dig("colors", "error") || dark.dig("static", "error")]
}.each do |token, pair|
  pair.each do |hex|
    fail!("#{token} missing theme value #{hex}") if hex && !css.include?("#{token}: #{hex}")
  end
end

mono_ok = /
  \.ledger-meta |
  textarea\.body-source |
  \.liquid-block |
  textarea\.yaml-source |
  \.yaml-preview-pre |
  \.media-breadcrumb |
  \.editor-path |
  \.studio-map-card-meta |
  \.list-error-detail |
  \.media-row-meta |
  \.pending-signed-in |
  \.tiptap\s+\.ProseMirror\s+code
/x
css.scan(/([^{}]+)\{([^{}]*)\}/m).each do |selector, body|
  next unless body.include?("var(--font-mono)")
  flat = selector.gsub(/\s+/, " ").strip
  fail!("monospace is not a date, path, or code face: #{flat}") unless flat.match?(mono_ok)
end

css.scan(/box-shadow:\s*([^;]+);/).each do |value|
  v = value[0].strip
  fail!("drop shadow remains: #{v}") unless v == "none" || v == "none !important"
end

# --- PLT-AC-113 phone article, restored to 2.3.37 in 2.3.40 ---
fail!("spec missing PLT-AC-113") unless spec.include?("PLT-AC-113")
chrome = read("assets/css/ledger/chrome.css")
shell = read("_layouts/shell.html")
detail = read("assets/css/ledger/detail.css")
base = read("assets/css/base.css")
fail!("phone wordmark must stay hidden") unless chrome.match?(/\.site-wordmark\s*\{[^}]*display:\s*none;/m)
fail!("wordmark must return at 640px") unless chrome.match?(/min-width:\s*640px[\s\S]{0,80}\.site-wordmark\s*\{[^}]*display:\s*inline;/m)
fail!("wordmark size must stay calc(var(--type-dek) * 1.25)") unless chrome.match?(/\.site-wordmark\s*\{[^}]*font-size:\s*calc\(var\(--type-dek\)\s*\*\s*1\.25\);/m)
fail!("wordmark must use the title face") unless chrome.match?(/\.site-wordmark\s*\{[^}]*font-family:\s*var\(--font-title\);/m)
fail!("Explore must stay visually hidden") unless shell.include?('<span class="sr-only">Explore</span>')
fail!("Explore must not be a visible top-bar label") if shell.include?("site-explore-label")
fail!("menu control must keep its accessible name") unless shell.include?('aria-label="Explore site pages"') && shell.include?('title="Menu"')
fail!("menu control must show the menu glyph at text-xl") unless shell.include?('class="material-symbols-outlined text-xl" aria-hidden="true">menu</span>')
fail!("Explore must not be hardcoded as a person's name") if shell.include?("Alexandre")
fail!("phone menu glyph must stay visible") if chrome.match?(/#mobile-menu-btn \.material-symbols-outlined\s*\{[^}]*display:\s*none/m)
fail!("phone top-bar controls must keep the 2.25rem box") if chrome.match?(/max-width:\s*767px[\s\S]*#(?:theme-toggle-btn|mobile-menu-btn)[\s\S]{0,240}width:\s*auto/m)
fail!("menu glyph size must stay 1.25rem") unless base.include?(".material-symbols-outlined.text-xl { font-size: 1.25rem; }")
fail!("theme glyph size must stay var(--type-card)") unless base.match?(/#theme-toggle-icon\.material-symbols-outlined\s*\{[^}]*font-size:\s*var\(--type-card\);/m)
fail!("phone dates must stay stacked dossier rows") if detail.include?('content: "· Updated "')
fail!("date values must use the mono meta size") unless detail.match?(/\.text-detail-sidebar \.article-meta\s*\{[^}]*font-family:\s*var\(--font-mono\);[^}]*font-size:\s*var\(--type-meta\);/m)
fail!("date labels must use --type-label") unless detail.match?(/date-evolution>span\[title\]::before\s*\{[^}]*font-size:\s*var\(--type-label\);/m)
fail!("phone action glyphs must stay calc(1rem + 2pt)") unless detail.match?(/max-width:\s*767px[\s\S]*detail-action \.material-symbols-outlined,[\s\S]{0,220}?font-size:\s*calc\(1rem \+ 2pt\)/m)
fail!("phone action labels must stay clipped") unless detail.match?(/max-width:\s*767px[\s\S]*detail-action-label,[\s\S]{0,500}?clip:\s*rect\(0,\s*0,\s*0,\s*0\);/m)
fail!("phone actions must keep their icons") if detail.match?(/max-width:\s*767px[\s\S]*detail-action \.material-symbols-outlined\s*\{[^}]*display:\s*none/m)
fail!("phone action boxes must stay 2.5rem with no padding") unless detail.match?(/max-width:\s*767px[\s\S]*\.detail-action,\s*\n\s*\.text-detail-sidebar \.article-meta \.detail-type-size-trigger\s*\{[^}]*height:\s*2\.5rem;[^}]*padding:\s*0;/m)
fail!("desktop action glyphs must stay 1rem") unless detail.match?(/\.detail-action \.material-symbols-outlined\s*\{[^}]*font-size:\s*1rem;/m)
fail!("desktop action labels must keep the label face and size") unless detail.match?(/\.detail-action\s*\{[^}]*font-family:\s*var\(--font-label\);[^}]*font-size:\s*var\(--type-label-lg\);/m)

# --- PLT-AC-114 phone follow-up ---
fail!("spec missing PLT-AC-114") unless spec.include?("PLT-AC-114")
fail!("search field must not grow on the column axis") if css.include?("flex: 1 1 14rem")
search_rule = css[/\.list-search-input\s*\{[^}]*\}/m]
fail!("list search rule missing") unless search_rule
fail!("search field must be 44px") unless search_rule.include?("height: 44px")
fail!("search field needs a search icon") unless main.include?('className: "list-search"') && main.include?('materialIcon("search"')
fail!("phone toolbar spacer must not eat the crumb") unless mobile_css.match?(/\.studio-toolbar \.spacer\s*\{[^}]*flex:\s*0\s+0\s+auto/m)
fail!("short crumb must take free space") unless mobile_css.match?(/\.studio-breadcrumb--short\s*\{[^}]*flex:\s*1\s+1\s+auto/m)
editor = main[/function renderEditorPane\(\) \{.*?\n\}/m]
fail!("renderEditorPane missing") unless editor
fail!("Visual must not mount the front-matter form") unless editor.include?("showFields ? form : null")
fail!("editor mast must not keep a frame") if css.match?(/\.editor-mast\s*\{[^}]*border:\s*1px/m)
fail!("phone format bar must be one 44px row") unless mobile_css.match?(/\.editor-format-bar-mobile\s*\{[^}]*height:\s*44px/m)
fail!("Correct and Refine must be bar buttons") unless main.include?("editor-format-bar-proof")
fail!("Preview tab must hide the body stack") unless css.match?(/\.studio-body\.view-preview \.body-editor-stack\s*\{[^}]*display:\s*none/m)
fail!("Preview tab must hide the counter") unless css.match?(/\.studio-body\.view-preview \.editor-body-stats\s*\{[^}]*display:\s*none/m)
fail!("drop cap must treat a truthy drop_cap like the live article") unless main.include?("function dropCapRequested")
fail!("Clerk fields must draw all four sides") unless css.include?("border-left-width: 1px") && css.include?("border-right-width: 1px")
fail!("Continue must drop the Clerk overlay") unless css.include?(".cl-formButtonPrimary::after")
fail!("pending email line must be mono") unless css.match?(/\.pending-signed-in\s*\{[^}]*font-family:\s*var\(--font-mono\)/m)
fail!("Sign out must include a logout icon") unless main.include?('materialIcon("logout")')

puts "PASS test-studio-mobile"
