# frozen_string_literal: true

# PLT-AC-102 — strength/pool independence, caps < 1, pool charcoal, strength true-black.
# PLT-AC-103 (structure half) — strength peak coeff ≥ 0.50; strength-cap ≥ 0.50; no shade on ::after.

require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
errors = []

css = ROOT.join("assets/css/ledger/home.css").read

unless css.include?("--home-hero-strength-cap")
  errors << "home.css must define --home-hero-strength-cap (PLT-AC-102)"
end
unless css.include?("--home-hero-pool-cap")
  errors << "home.css must define --home-hero-pool-cap (PLT-AC-102)"
end
unless css.include?("--home-hero-shade")
  errors << "home.css must define charcoal --home-hero-shade (PLT-AC-102)"
end

# Caps must be strictly below 1 (dead-config: alpha never reaches pure black).
cap_s = css[/--home-hero-strength-cap:\s*([\d.]+)/, 1]
cap_p = css[/--home-hero-pool-cap:\s*([\d.]+)/, 1]
unless cap_s && cap_s.to_f > 0 && cap_s.to_f < 1
  errors << "strength-cap must be in (0,1), got #{cap_s.inspect} (PLT-AC-102)"
end
unless cap_p && cap_p.to_f > 0 && cap_p.to_f < 1
  errors << "pool-cap must be in (0,1), got #{cap_p.inspect} (PLT-AC-102)"
end

# PLT-AC-103: strength-cap high enough for perceptible darkening
if cap_s && cap_s.to_f < 0.50
  errors << "strength-cap must be ≥ 0.50 for perceptible strength range, got #{cap_s} (PLT-AC-103)"
end

# Independence: pool only on ::before backgrounds; vignette only on ::after; mask on ::after.
pool_before = css.scan(/\.home-hero-portrait::before \{.*?^\}/m)
vig_after = css.scan(/\.home-hero-portrait::after \{.*?^\}/m)
before_paint = pool_before.find { |c| c.include?("linear-gradient") && c.include?("--home-hero-pool") }
after_paint = vig_after.find { |c| c.include?("linear-gradient") && c.include?("--home-hero-vignette") }
unless before_paint
  errors << "::before must use --home-hero-pool (absolute text-band alpha) (PLT-AC-102)"
end
if before_paint&.include?("var(--home-hero-vignette)")
  errors << "::before must not scale with --home-hero-vignette (independence) (PLT-AC-102)"
end
unless after_paint
  errors << "::after must use --home-hero-vignette (strength) (PLT-AC-102)"
end
if after_paint&.include?("var(--home-hero-pool)")
  errors << "::after must not use --home-hero-pool (independence) (PLT-AC-102)"
end
unless css.match?(/\.home-hero-portrait::after[\s\S]*?mask-image:\s*linear-gradient/)
  errors << "::after must mask off the text band (PLT-AC-102)"
end
unless css.include?("PLT-AC-100…103: stack") && css.include?("var(--home-hero-pool)") && css.include?("var(--home-hero-vignette)")
  errors << "stack overlay marker + pool/strength vars required (PLT-AC-102)"
end
pool_paints = css.scan(/--home-hero-pool\)/).length
vig_paints = css.scan(/--home-hero-vignette\)/).length
if pool_paints < 4
  errors << "expected multiple pool stops (desk+stack), got #{pool_paints} (PLT-AC-102)"
end
if vig_paints < 4
  errors << "expected multiple strength stops (desk+stack), got #{vig_paints} (PLT-AC-102)"
end

unless css.include?("min(var(--home-hero-strength-cap)")
  errors << "strength stops must use min(strength-cap, …) (PLT-AC-102)"
end
unless css.include?("min(var(--home-hero-pool-cap)")
  errors << "pool stops must use min(pool-cap, …) (PLT-AC-102)"
end

if css.match?(%r{var\(--home-hero-vignette\)\s*/\s*0\.6})
  errors << "home.css must not use vignette/0.6 overscale (PLT-AC-102)"
end

# Pool shade is not pure black RGB(0,0,0)
shade = css[/--home-hero-shade:\s*([^;]+);/, 1].to_s.strip
parts = shade.split(",").map { |x| x.strip.to_i }
if parts.length != 3 || parts.all?(&:zero?)
  errors << "--home-hero-shade must be non-zero charcoal RGB, got #{shade.inspect} (PLT-AC-102)"
end
unless before_paint&.include?("rgba(var(--home-hero-shade)")
  errors << "pool ::before stops must paint with rgba(var(--home-hero-shade), …) (PLT-AC-102)"
end

# PLT-AC-103: strength MUST use true black rgba(0, 0, 0, …) — charcoal brightens dark photos.
strength_paints = vig_after.select { |c| c.include?("linear-gradient") && c.include?("--home-hero-vignette") }
strength_paints.each_with_index do |body, i|
  if body.include?("rgba(var(--home-hero-shade)")
    errors << "::after strength paint ##{i} must NOT use charcoal shade (brightens dark photos) (PLT-AC-103)"
  end
  unless body.match?(/rgba\(\s*0\s*,\s*0\s*,\s*0\s*,/)
    errors << "::after strength paint ##{i} must use rgba(0, 0, 0, …) (PLT-AC-103)"
  end
end

# Peak strength coefficient (largest multiplier of vignette) must be ≥ 0.50
coeffs = css.scan(/calc\(\s*([\d.]+)\s*\*\s*var\(--home-hero-vignette\)\s*\)/).map { |m| m[0].to_f }
peak = coeffs.max || 0
if peak < 0.50
  errors << "peak strength coefficient must be ≥ 0.50 for perceptible range, got #{peak} (PLT-AC-103)"
end

home_layout = ROOT.join("_layouts/home.html").read
unless home_layout.include?("--home-hero-pool:")
  errors << "home.html must emit --home-hero-pool (PLT-AC-102)"
end

docs = ROOT.join("docs/features/home-hero-scale-overlay.md").read
unless docs.include?("PLT-AC-102")
  errors << "docs/features/home-hero-scale-overlay.md must document PLT-AC-102"
end
unless docs.include?("PLT-AC-103")
  errors << "docs/features/home-hero-scale-overlay.md must document PLT-AC-103"
end

schema = ROOT.join("lib/pandorga/registry/schema.yml").read
unless schema.include?("strength") && schema.include?("pool")
  errors << "schema hero_overlay must document strength and pool"
end

if errors.empty?
  puts "OK home-hero-overlay-split (PLT-AC-102/103 structure)"
else
  warn "FAIL test-home-hero-overlay-split:\n#{errors.join("\n")}"
  exit 1
end
