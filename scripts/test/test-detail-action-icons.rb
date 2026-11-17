# frozen_string_literal: true

# CR-23 / pandorga 2.3.9 — detail action glyphs + TOC gap (PLT-AC-95…97).

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

# PLT-AC-113 supersedes the phone icon-only row of PLT-AC-95.
# Desktop glyphs stay 1rem. Phones show the words and hide the icons.
unless DETAIL.match?(/max-width:\s*767px[\s\S]*detail-action \.material-symbols-outlined\s*\{[^}]*display:\s*none/m)
  failed = 1 if fail!("PLT-AC-113: phone detail actions must hide the icon")
end
unless DETAIL.match?(/max-width:\s*767px[\s\S]*detail-action-label\s*\{[^}]*position:\s*static/m)
  failed = 1 if fail!("PLT-AC-113: phone detail action labels must be visible")
end
unless DETAIL.include?('content: "· Updated "')
  failed = 1 if fail!("PLT-AC-113: phone dates must join with · Updated")
end
# Desktop base stays 1rem (labeled pills)
unless DETAIL.match?(/\.detail-action\s+\.material-symbols-outlined\s*\{[^}]*font-size:\s*1rem;/m)
  failed = 1 if fail!("PLT-AC-95: desktop .detail-action icons must keep font-size: 1rem")
end
# Phone actions are text. They keep a 44px touch target.
unless DETAIL.match?(/max-width:\s*767px[\s\S]*\.detail-action\s*\{[^}]*min-height:\s*44px/m)
  failed = 1 if fail!("PLT-AC-113: phone detail actions must keep a 44px target")
end
# Padding on base .detail-action must stay 0.35rem 0.85rem (2.3.5)
unless DETAIL.match?(/\.detail-action\s*\{[^}]*padding:\s*0\.35rem\s+0\.85rem;/m)
  failed = 1 if fail!("PLT-AC-95: base .detail-action padding must remain 0.35rem 0.85rem")
end

# PLT-AC-113 — the phone row starts at the left edge.
unless DETAIL.match?(/max-width:\s*767px[\s\S]*\.detail-actions\s*\{[^}]*justify-content:\s*flex-start/m)
  failed = 1 if fail!("PLT-AC-113: phone detail actions must start at the left")
end

# PLT-AC-97 — gap via space-sm + space-xs under actions / above TOC rule
unless DETAIL.match?(/padding-bottom:\s*calc\(\s*var\(--space-sm\)\s*\+\s*var\(--space-xs\)\s*\)/)
  failed = 1 if fail!("PLT-AC-97: article-meta with TOC must use padding-bottom: calc(var(--space-sm) + var(--space-xs))")
end
# Must not zero the padding under TOC anymore
if DETAIL.match?(/:has\(\.article-toc--disclosure\)\s+\.article-meta[\s\S]{0,120}?padding-bottom:\s*0;/)
  failed = 1 if fail!("PLT-AC-97: must not zero article-meta padding-bottom when TOC is present")
end

unless SPEC.include?("PLT-AC-95") && SPEC.include?("PLT-AC-97") && SPEC.include?("2.3.9")
  failed = 1 if fail!("spec docs/features/detail-action-icons.md must cover PLT-AC-95…97 and 2.3.9")
end
unless VALIDATE.include?("test-detail-action-icons.rb")
  failed = 1 if fail!("scripts/validate.sh must allowlist test-detail-action-icons.rb")
end

if failed.zero?
  puts "PASS test-detail-action-icons (PLT-AC-95…97)"
else
  exit 1
end
