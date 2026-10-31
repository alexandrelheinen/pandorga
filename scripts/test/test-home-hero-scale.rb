# frozen_string_literal: true

# PLT-AC-98…100 — hero name = band title + 4pt; overlay lighter than 2.3.7.


errors = []
home = File.read(File.expand_path("../../assets/css/ledger/home.css", __dir__))

unless home.include?("font-size: calc(var(--type-section) + 4pt)")
  errors << "home.css: base .home-hero-title must be calc(var(--type-section) + 4pt) (PLT-AC-98)"
end
unless home.include?("font-size: calc(var(--type-section-lg) + 4pt)")
  errors << "home.css: ≥768 .home-hero-title must be calc(var(--type-section-lg) + 4pt) (PLT-AC-98)"
end
if home.match?(/\.home-hero-title[^{]*\{[^}]*100cqi/) || home.include?("1.85rem, 2.6vw") || home.include?("1.9rem, 7vw")
  errors << "home.css: .home-hero-title must not size from cqi/vw (PLT-AC-98)"
end

# Band titles still on the same tokens the hero tracks.
unless home.include?(".home-band .ledger-section-banner .section-title") && home.include?("font-size: var(--type-section)")
  errors << "home.css: band .section-title must keep --type-section (PLT-AC-98)"
end
unless home.include?("font-size: var(--type-section-lg)")
  errors << "home.css: band .section-title ≥768 must keep --type-section-lg (PLT-AC-98)"
end

# Overlay still soft/edgeless, no panel on copy; lighter stops than 2.3.7 (0.92 / 0.88).
unless home.include?(".home-hero-portrait::after")
  errors << "home.css: soft ::after overlay missing (PLT-AC-100)"
end
if home.include?("rgba(0, 0, 0, calc(0.92 * var(--home-hero-vignette) / 0.6))") ||
   home.include?("rgba(0, 0, 0, calc(0.88 * var(--home-hero-vignette) / 0.6))")
  errors << "home.css: overlay still uses 2.3.7 deep stops 0.92/0.88 (PLT-AC-100)"
end
# Copy must stay transparent (no panel).
home.scan(/\.home-hero-copy\s*\{[^}]+\}/m).each do |block|
  next unless block.include?("background:")
  unless block.include?("background: transparent")
    errors << "home.css: .home-hero-copy must stay background: transparent (PLT-AC-100)"
  end
end

if errors.empty?
  puts "OK home-hero-scale (PLT-AC-98…100)"
else
  warn errors.join("\n")
  exit 1
end
