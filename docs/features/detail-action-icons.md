# CR-23 — Detail action icons + TOC gap (pandorga 2.3.8)

Status: shipping in 2.3.8  
Version target: pandorga 2.3.8  
Prerequisite: CR-22.4 (2.3.6/2.3.7) shipped.

## Intent

On article/post detail pages, the four meta action controls (Back, Share, Cite, reading size) keep their **exact** marker-button box size from 2.3.5, while the **icons/glyphs alone** grow by +2pt and stay centered on both axes inside each button. Add a clear vertical gap between the bottom of that action row and the horizontal rule that leads the “IN THIS TEXT” contents disclosure (the rule that currently kisses the buttons on mobile dark).

## Acceptance criteria (EARS)

- `PLT-AC-95` The Material Symbol glyphs inside `.detail-action` and `.detail-type-size-trigger` (excluding the expand caret) use `font-size: calc(1rem + 2pt)`; width, height, padding, and margin declarations on `.detail-action` / `.detail-type-size-trigger` (including the mobile `height: 2.5rem; padding: 0` rules) remain identical to 2.3.5 (`test-detail-action-icons`).
- `PLT-AC-96` On the mobile icon-only action row (`max-width: 767px`, labels clipped), each visible action glyph’s rendered bounding-box center (via `Range.getBoundingClientRect` on the icon’s text contents) lies within ±0.5px of its button’s center on both X and Y; buttons keep `display: inline-flex; justify-content: center; align-items: center` (`test-detail-action-icons`; live verify at 390). Desktop keeps labeled pills — glyph centering is not required when the label is visible.
- `PLT-AC-97` When the stacked contents disclosure is present below `.article-meta`, the gap from the bottom of `.detail-actions` to the horizontal rule above “IN THIS TEXT” is at least `calc(var(--space-sm) + var(--space-xs))` (0.75rem ≈ 12px at a 16px root): composed from the spacing scale as `space-sm + space-xs`, the smallest step that reads as clear separation without jumping a full `--space-md` (`test-detail-action-icons`).

## Spacing choice

`--space-xs` (0.25rem) was the previous TOC `margin-top` and left the meta `border-bottom` flush under the buttons once `padding-bottom` was zeroed. `--space-md` (1rem) is a full meta rhythm step and feels loose for a rule that only needs breathing room. `calc(var(--space-sm) + var(--space-xs))` = 0.75rem (~12px) matches the requested separation and stays on the token ladder.

## Non-goals

- Do not enlarge the marker button hit boxes or change their padding.
- Do not cite the private website repository in pandorga docs or commits.
