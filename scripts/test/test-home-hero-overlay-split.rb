# frozen_string_literal: true

# PLT-AC-102 — strength/pool independence, caps < 1, charcoal shade, no /0.6 overscale.

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

# Independence: pool only on ::before backgrounds; vignette only on ::after; mask on ::after.
pool_before = css.scan(/\.home-hero-portrait::before \{.*?^\}/m)
vig_after = css.scan(/\.home-hero-portrait::after \{.*?^\}/m)
# Prefer the rule bodies that actually paint gradients (skip the shared content/inset rule).
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
# Stack media also keeps the split (comment marker from home.css)
unless css.include?("PLT-AC-100…102: stack") && css.include?("var(--home-hero-pool)") && css.include?("var(--home-hero-vignette)")
  errors << "stack overlay marker + pool/strength vars required (PLT-AC-102)"
end
# At least two pool ::before paints (desk + stack) and two strength ::after paints
pool_paints = css.scan(/--home-hero-pool\)/).length
vig_paints = css.scan(/--home-hero-vignette\)/).length
if pool_paints < 4
  errors << "expected multiple pool stops (desk+stack), got #{pool_paints} (PLT-AC-102)"
end
if vig_paints < 4
  errors << "expected multiple strength stops (desk+stack), got #{vig_paints} (PLT-AC-102)"
end

# Every stop clamped
unless css.include?("min(var(--home-hero-strength-cap)")
  errors << "strength stops must use min(strength-cap, …) (PLT-AC-102)"
end
unless css.include?("min(var(--home-hero-pool-cap)")
  errors << "pool stops must use min(pool-cap, …) (PLT-AC-102)"
end

# No historic overscale that pushed alpha > 1
if css.match?(%r{var\(--home-hero-vignette\)\s*/\s*0\.6})
  errors << "home.css must not use vignette/0.6 overscale (PLT-AC-102)"
end

# Shade is not pure black RGB(0,0,0)
shade = css[/--home-hero-shade:\s*([^;]+);/, 1].to_s.strip
parts = shade.split(",").map { |x| x.strip.to_i }
if parts.length != 3 || parts.all?(&:zero?)
  errors << "--home-hero-shade must be non-zero charcoal RGB, got #{shade.inspect} (PLT-AC-102)"
end
unless css.include?("rgba(var(--home-hero-shade)")
  errors << "overlay stops must paint with rgba(var(--home-hero-shade), …) (PLT-AC-102)"
end

# Layout still emits both vars
home_layout = ROOT.join("_layouts/home.html").read
unless home_layout.include?("--home-hero-pool:")
  errors << "home.html must emit --home-hero-pool (PLT-AC-102)"
end

# Docs + schema mention independence / caps
docs = ROOT.join("docs/features/home-hero-scale-overlay.md").read
unless docs.include?("PLT-AC-102")
  errors << "docs/features/home-hero-scale-overlay.md must document PLT-AC-102"
end

schema = ROOT.join("lib/pandorga/registry/schema.yml").read
unless schema.include?("strength") && schema.include?("pool")
  errors << "schema hero_overlay must document strength and pool"
end

if errors.empty?
  puts "OK home-hero-overlay-split (PLT-AC-102)"
else
  warn "FAIL test-home-hero-overlay-split:\n#{errors.join("\n")}"
  exit 1
end
