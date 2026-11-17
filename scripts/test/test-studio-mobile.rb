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

puts "PASS test-studio-mobile"
