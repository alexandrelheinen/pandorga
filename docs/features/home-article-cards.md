# Home article cards and an emptied band header

## Intent

The listed article cards on the home read like the featured one: tags and
the "Read" link share the card's last row. Every listed card carries the
Articles page accent on its top rule instead of rotating through the
palette, so one card no longer shows the secondary (ochre) hue inside a
green band. And a band whose header texts are all saved empty in
`content/pages/headers.yml` drops the whole header, rule included, instead
of keeping an empty ruled strip.

## Scope

In:

- The home Articles band list (`.home-card-grid`) and the card markup
  `renderArchiveCard` builds for it.
- The home band header (`.ledger-section-banner`) of the index band and the
  listing bands, at build time and in the runtime filler.

Out:

- The featured card, the Rascunhos cards, the projects band and the
  Articles page, whose archive cards keep their layout.

## Acceptance criteria

- `PLT-AC-52` Home article cards and emptied band headers.
  1. **Foot row.** `renderArchiveCard` takes a `tagsInFoot` option. When it
     is set, the tag chips render inside `.ledger-card-foot`, before the
     call to action, and not above it. The home Articles band passes
     `tagsInFoot: true`; no other caller does. `.home-card-grid
     .ledger-card-foot` uses `justify-content: space-between`, and its
     `.ledger-cta` takes `margin-left: auto`, so "Read" stays at the right
     end of the row even when it wraps.
  2. **One accent.** `.home-card-grid .ledger-card` draws its 2px top rule
     in `var(--color-primary)`, which the band's `page-accent--<accent>`
     sets. No `.home-card-grid` rule sets `border-top-color` to
     `--color-secondary` or `--color-tertiary`, and none keys a colour to
     `:nth-child`.
  3. **Emptied header, build time.** When `headers.yml` was read at build
     time and the index band's entry has no non-blank kicker, title or
     note, `home/band-index.html` emits no `.ledger-section-banner`, and
     the band's `<section>` carries an `aria-label` naming its panels.
  4. **Emptied header, runtime.** After `applyHomeSection` fills or removes
     the slots, a banner left with no slot and no `.home-section-aside` is
     removed, and its band `<section>` takes its `data-home-label` as
     `aria-label`. `home/band-index.html` sets `data-home-label` to its
     panels' default titles joined with ", ".
