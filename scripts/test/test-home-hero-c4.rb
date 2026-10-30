# frozen_string_literal: true

# CR-22.4 / pandorga 2.3.6 — C4 home hero gates (PLT-AC-88…94).
# One assertion block per acceptance criterion in docs/features/home-hero-c4.md.

require "pathname"

ROOT = Pathname(__dir__).join("../..").expand_path
HOME = ROOT.join("assets/css/ledger/home.css").read
LAYOUT = ROOT.join("_layouts/home.html").read
FRAGMENTS = ROOT.join("_includes/content-runtime/60-fragments.html").read
SPEC = ROOT.join("docs/features/home-hero-c4.md").read
VALIDATE = ROOT.join("scripts/validate.sh").read

failed = 0
def fail!(msg)
  warn "FAIL test-home-hero-c4: #{msg}"
  true
end

# PLT-AC-88 — Projects island centered in desktop column
unless HOME.match?(/\.home-projects-bench[\s\S]{0,800}?margin-inline:\s*auto/)
  failed = 1 if fail!("PLT-AC-88: .home-projects-bench must use margin-inline: auto")
end
unless HOME.match?(/\.home-projects-bench[\s\S]{0,800}?width:\s*max-content/)
  failed = 1 if fail!("PLT-AC-88: .home-projects-bench must use width: max-content")
end
unless HOME.include?("PLT-AC-88") || SPEC.include?("PLT-AC-88")
  failed = 1 if fail!("PLT-AC-88: spec must name PLT-AC-88")
end

# PLT-AC-89 — soft edgeless overlay, no panel behind copy
unless HOME.match?(/\.home-hero-portrait::after[\s\S]{0,800}?border-radius:\s*0/) ||
       HOME.match?(/\.home-hero-portrait::after[\s\S]{0,200}?inset:\s*0/)
  # inset 0 full-bleed is required; border-radius 0 optional if never set
  unless HOME.match?(/\.home-hero-portrait::after[\s\S]{0,120}?inset:\s*0/)
    failed = 1 if fail!("PLT-AC-89: .home-hero-portrait::after must be full-bleed (inset: 0)")
  end
end
copy_bodies = HOME.scan(/\.home-hero-copy\s*\{([^}]+)\}/m).flatten
unless copy_bodies.any? { |b| b.include?("background: transparent") || b.include?("background:transparent") }
  failed = 1 if fail!("PLT-AC-89: .home-hero-copy must stay background: transparent")
end
if HOME.match?(/\.home-hero-copy::(?:before|after)\s*\{[^}]*background:\s*(?!none)[^;]+/)
  failed = 1 if fail!("PLT-AC-89: .home-hero-copy must not paint a panel via ::before/::after")
end
# Soft overlay denser under text (stack recipe carries high bottom stop)
unless HOME.include?("0.84") || HOME.include?("0.88") || HOME.include?("rgba(0, 0, 0, 0.84)")
  failed = 1 if fail!("PLT-AC-89: soft overlay must include dense bottom darkening (≥0.84)")
end

# PLT-AC-90 — light title/summary + text-shadow for ≥7:1 (structure)
unless HOME.match?(/\.home-hero-title[\s\S]{0,200}?color:\s*#f[0-9a-fA-F]{3,5}/)
  failed = 1 if fail!("PLT-AC-90: .home-hero-title must use light ink (#f…)")
end
unless HOME.match?(/\.home-hero-summary[\s\S]{0,200}?text-shadow:/)
  failed = 1 if fail!("PLT-AC-90: .home-hero-summary must keep text-shadow on the photo")
end

# PLT-AC-91 — highlighter 1.02em / 0.14em
unless HOME.match?(/\.home-hero-family[\s\S]{0,300}?--mk-h:\s*1\.02em/)
  failed = 1 if fail!("PLT-AC-91: .home-hero-family must set --mk-h: 1.02em")
end
unless HOME.match?(/\.home-hero-family[\s\S]{0,300}?padding-inline:\s*0\.14em/)
  failed = 1 if fail!("PLT-AC-91: .home-hero-family must set padding-inline: 0.14em")
end
if HOME.match?(/\.home-hero-family[\s\S]{0,300}?--mk-h:\s*0\.72em/)
  failed = 1 if fail!("PLT-AC-91: .home-hero-family must not keep --mk-h: 0.72em")
end

# PLT-AC-92 — random when unpinned; object-position center
unless FRAGMENTS.include?("pickHeroPortrait(entries, Math.random")
  failed = 1 if fail!("PLT-AC-92: hydrate must draw with Math.random when prefer is empty")
end
unless HOME.match?(/\.home-hero-plate img[\s\S]{0,200}?object-position:\s*center/)
  failed = 1 if fail!("PLT-AC-92: .home-hero-plate img must use object-position: center")
end
unless SPEC.include?("Omit for random") || SPEC.include?("random draw")
  failed = 1 if fail!("PLT-AC-92: spec must document default random draw")
end

# PLT-AC-93 — marker CTAs, no solid box override on hero actions
hero_actions_blocks = HOME.scan(/\.home-hero-actions\s+\.ledger-cta[\s\S]{0,80}?\{([^}]+)\}/m).flatten
solid = hero_actions_blocks.any? { |b| b.match?(/background:\s*rgba\(\s*245/) }
if solid
  failed = 1 if fail!("PLT-AC-93: hero CTAs must not override marker wash with solid rgba(245…) box")
end
unless HOME.match?(/\.home-hero-actions[\s\S]{0,500}?--mark-ink:/) ||
       HOME.match?(/home-hero-cta[\s\S]{0,200}?--mark-ink:/)
  failed = 1 if fail!("PLT-AC-93: hero CTAs must set --mark-ink for marker wash on the photo")
end

# PLT-AC-94 — CV / contacts wrap groups
unless LAYOUT.include?("home-hero-actions-contacts")
  failed = 1 if fail!("PLT-AC-94: home layout must wrap contacts in .home-hero-actions-contacts")
end
unless FRAGMENTS.match?(/data-content-hero-contacts[\s\S]{0,800}?innerHTML\s*=/)
  failed = 1 if fail!("PLT-AC-94: hydrateContacts must set innerHTML on hero contact slots (keep wrapper)")
end
if FRAGMENTS.match?(/heroSlots\.forEach[\s\S]{0,120}?outerHTML\s*=/)
  failed = 1 if fail!("PLT-AC-94: hydrateContacts must not replace hero contact slot via outerHTML")
end
unless HOME.match?(/\.home-hero-actions[\s\S]{0,120}?flex-wrap:\s*wrap/)
  failed = 1 if fail!("PLT-AC-94: .home-hero-actions must allow flex-wrap: wrap")
end
unless HOME.match?(/\.home-hero-actions-contacts[\s\S]{0,120}?flex-wrap:\s*nowrap/)
  failed = 1 if fail!("PLT-AC-94: .home-hero-actions-contacts must keep flex-wrap: nowrap")
end

# Spec + validate wiring
unless SPEC.include?("PLT-AC-94") && SPEC.include?("2.3.6")
  failed = 1 if fail!("spec docs/features/home-hero-c4.md must cover PLT-AC-88…94 and 2.3.6")
end
unless VALIDATE.include?("test-home-hero-c4.rb")
  failed = 1 if fail!("scripts/validate.sh must allowlist test-home-hero-c4.rb")
end

if failed.zero?
  puts "PASS test-home-hero-c4 (PLT-AC-88…94)"
else
  exit 1
end
