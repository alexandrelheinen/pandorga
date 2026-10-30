# frozen_string_literal: true

# CR-23 / pandorga 2.3.8 — detail action glyphs + TOC gap (PLT-AC-95…97).

require "pathname"

ROOT = Pathname(__dir__).join("../..").expand_path
DETAIL = ROOT.join("assets/css/ledger/detail.css").read
SPEC = ROOT.join("docs/features/detail-action-icons.md").read
VALIDATE = ROOT.join("scripts/validate.sh").read

failed = 0
def fail!(msg)
  warn "FAIL test-detail-action-icons: #{msg}"
  true
end

# PLT-AC-95 — glyph +2pt; box rules unchanged vs 2.3.5
unless DETAIL.match?(/\.detail-action\s+\.material-symbols-outlined\s*\{[^}]*font-size:\s*calc\(1rem\s*\+\s*2pt\)/m)
  failed = 1 if fail!("PLT-AC-95: .detail-action icons must use font-size: calc(1rem + 2pt)")
end
unless DETAIL.match?(/\.detail-type-size-trigger\s+\.material-symbols-outlined:not\(\.detail-type-size-caret\)\s*\{[^}]*font-size:\s*calc\(1rem\s*\+\s*2pt\)/m)
  failed = 1 if fail!("PLT-AC-95: type-size trigger icon (not caret) must use calc(1rem + 2pt)")
end
# Button box declarations from 2.3.5 must remain
unless DETAIL.match?(/\.text-detail-sidebar\s+\.article-meta\s+\.detail-action,\s*\n\s*\.text-detail-sidebar\s+\.article-meta\s+\.detail-type-size-trigger\s*\{[^}]*height:\s*2\.5rem;[^}]*padding:\s*0;/m) ||
       DETAIL.match?(/height:\s*2\.5rem;[\s\S]{0,120}?padding:\s*0;/)
  failed = 1 if fail!("PLT-AC-95: mobile detail-action boxes must keep height: 2.5rem and padding: 0")
end
if DETAIL.match?(/\.detail-action\s+\.material-symbols-outlined\s*\{[^}]*font-size:\s*1rem;/m)
  failed = 1 if fail!("PLT-AC-95: .detail-action icons must not keep bare font-size: 1rem")
end
# Padding on base .detail-action must stay 0.35rem 0.85rem (2.3.5)
unless DETAIL.match?(/\.detail-action\s*\{[^}]*padding:\s*0\.35rem\s+0\.85rem;/m)
  failed = 1 if fail!("PLT-AC-95: base .detail-action padding must remain 0.35rem 0.85rem")
end

# PLT-AC-96 — flex centering on mobile icon buttons
unless DETAIL.match?(/\.text-detail-sidebar\s+\.article-meta\s+\.detail-action,[\s\S]{0,200}?justify-content:\s*center;[\s\S]{0,80}?align-items:\s*center;/m)
  failed = 1 if fail!("PLT-AC-96: mobile detail-action boxes must justify-content/align-items center")
end

# PLT-AC-97 — gap via space-sm + space-xs under actions / above TOC rule
unless DETAIL.match?(/padding-bottom:\s*calc\(\s*var\(--space-sm\)\s*\+\s*var\(--space-xs\)\s*\)/)
  failed = 1 if fail!("PLT-AC-97: article-meta with TOC must use padding-bottom: calc(var(--space-sm) + var(--space-xs))")
end
# Must not zero the padding under TOC anymore
if DETAIL.match?(/:has\(\.article-toc--disclosure\)\s+\.article-meta[\s\S]{0,120}?padding-bottom:\s*0;/)
  failed = 1 if fail!("PLT-AC-97: must not zero article-meta padding-bottom when TOC is present")
end

unless SPEC.include?("PLT-AC-95") && SPEC.include?("PLT-AC-97") && SPEC.include?("2.3.8")
  failed = 1 if fail!("spec docs/features/detail-action-icons.md must cover PLT-AC-95…97 and 2.3.8")
end
unless VALIDATE.include?("test-detail-action-icons.rb")
  failed = 1 if fail!("scripts/validate.sh must allowlist test-detail-action-icons.rb")
end

if failed.zero?
  puts "PASS test-detail-action-icons (PLT-AC-95…97)"
else
  exit 1
end
