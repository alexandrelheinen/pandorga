# 16:9 home hero

## Intent

The home hero shows one 16:9 photograph at every width. With a short
summary under the name, a 3:4 plate beside the copy is narrow and tall,
and the phone needed a second, landscape file and a second draw. One
frame shape removes the second file, the width switch and the picture
source. On a wide page the name sets on two lines, so the photograph
takes the width the one-line name used to hold, and the band is as tall
as its text, like the featured article.

## Scope

In:

- The hero plate, its layout from 1024px, and the hero name from 1024px.
- `pages/home/portraits.json` entries and their width variants.
- The runtime draw, the home layout and the shell preload.
- `pandorga.home.hero_landscape` and the `landscape` entry field, which go.

Out:

- The name below 1024px (`PLT-AC-15` is unchanged).
- The featured article poster and project thumbnails, apart from sharing
  the variant generator.
- Studio. It has no hero upload or crop form.

## Acceptance criteria

- `PLT-AC-51` The home hero plate is 16:9 at every width, and the hero
  photographs are 16:9 files.
  1. **Plate.** `.home-hero-plate` is `aspect-ratio: 16 / 9` outside any
     media query. No hero rule in `home.css` sets `3 / 4` or `4 / 3`,
     and no `.home-hero-plate--landscape` rule is left.
  2. **Phone.** Below 768px the plate keeps running edge to edge.
  3. **768px to 1023px.** The copy and the plate stack, and the plate
     takes the full column width. No hero rule caps `.home-hero-portrait`
     with a `max-width` in rem.
  4. **From 1024px.** The copy and the photograph sit side by side. The
     copy column is `flex: 0 0 46%`; `.home-hero-portrait` is
     `flex: 1 1 0`, `min-height: 15rem` and has no `max-width`. The plate
     wrapper and the plate are `position: absolute; inset: 0` with
     `aspect-ratio: auto`, so the band height follows the copy and the
     photograph covers the box (`object-fit: cover`,
     `object-position: center`). The crosshairs and the corner marks stay.
  5. **Cascade.** The 1024px rules come after the base hero rules in
     `home.css`, so a base `max-width`, `position: relative` or
     `aspect-ratio` cannot undo them.
  6. **Name from 1024px.** `.home-ledger .home-hero-title` is
     `white-space: normal` with `font-size:
     min(calc(100cqi / var(--hero-name-fit, 8.4)), var(--hero-name-max, 4.5rem))`,
     and the given and family names are `inline-block` and `nowrap`, so the
     only break is between them. `--hero-name-fit` is the width of the
     longer name part in em; a site with a longer word sets it.
  7. **Markup.** The home layout renders one
     `<img width="1600" height="900" data-content-hero-portrait>` with no
     `<picture>`, no `<source>` and no `data-hero-landscape`. Neither the
     layout nor the shell reads `hero_landscape`, and the shell preloads
     no hero image.
  8. **Runtime.** The runtime draws once per load from
     `pages/home/portraits.json` at every width. It has no `landscape`
     field, no `matchMedia` watch and none of `heroLandscapeEntries`,
     `paintNarrowHero`, `showConfiguredLandscape`, `showHeroLandscape`,
     `applyHeroLandscapeFile`, `setNarrowSource` or `watchHeroFrame`.
     `heroPortraitEntries` drops a `landscape` key it is given.
  9. **Export.** Each image in `content/media/images/hero/` gets
     `variants/<stem>-{480,960,1440}.jpg` from the project thumbnail
     generator (`PLT-AC-44`): a 16:9 center crop, no upscaling. An
     existing variant that is not 16:9 is written again even when it is
     newer than its original. A `portraits.json` entry lists only the
     variants that are 16:9 (`srcset`) with `sizes`
     `(max-width: 1023px) 100vw, 50vw`, and never a `landscape` key.
  10. **Registry.** `pandorga.home.hero_landscape` is not in the registry
      schema or in `docs/configuration.md`.

## Constraints

This is a breaking change: the `landscape` field, `hero_landscape` and the
3:4 variants stop working. `docs/upgrading.md` says what a site changes.
The gem does not ship photographs; a site uploads 16:9 originals (1920 px
wide or more is enough for the 1440 variant).

## Design notes

The 1024px block used to sit before the base `.home-hero-portrait`,
`.home-hero-plate-wrap` and `.home-hero-plate` rules, which set
`max-width: 16rem`, `position: relative` and `aspect-ratio: 3 / 4` and
won on source order. The block now follows them.

The name rule uses `.home-ledger .home-hero-title` so it outranks a site
override of the one-line size written with the same selector earlier in
the page.

Variants reuse `Pandorga::ThumbnailVariants`. The old 3:4 hero variants
had the same names, so the generator checks the size of an existing
variant before it trusts its timestamp, and the export reads JPEG and PNG
headers to keep any non-16:9 file out of `srcset` when ImageMagick is
missing.

## Gate

`scripts/test/test-hero-16x9.rb` and `scripts/test/test-hero-portraits.rb`
(with `test-hero-portraits.mjs`).
