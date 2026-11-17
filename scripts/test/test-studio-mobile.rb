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

puts "PASS test-studio-mobile"
