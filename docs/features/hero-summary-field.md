# Hero summary, separate from the CV summary

## Intent

The home hero paragraph and the CV page "Summary" section both read
`content/pages/cv/summary.md`, so the site's presentation and the
professional summary could not differ. The hero gets its own file,
`content/pages/home/summary.md`; the CV page keeps `cv/summary.md`.

## Scope

In:

- The home hero summary (`{% pandorga_hero_summary %}`,
  `Pandorga::HeroSummary`).
- A Studio entry for `content/pages/home/summary.md`.

Out:

- The CV page, which keeps rendering `cv/summary` in its Summary section,
  and the print-only summaries (`cv/summary-extended`,
  `cv/summary-single-page`).
- The runtime fallback for a build without either file: the hero stays a
  quiet `cv/summary` fragment, as before.

## Acceptance criteria

- `PLT-AC-54` Hero summary field.
  1. **Own file.** When `content/pages/home/summary.md` exists and has a
     non-blank body, the hero renders that body as static HTML
     (`data-content-static`), and `cv/summary.md` does not reach the hero.
  2. **Absent falls back.** When `home/summary.md` is absent, the hero
     renders `cv/summary.md` exactly as before, so a site that never adds
     the file sees no change.
  3. **Empty hides.** When `home/summary.md` exists with a blank body (front
     matter aside), the hero renders no summary element at all.
  4. **CV unchanged.** The CV page Summary section still reads the
     `cv/summary` fragment; the hero file never feeds it.
  5. **Studio.** The Presentation group has a "Hero summary" file entry for
     `content/pages/home/summary.md` (`format: raw`, `markdown_body`), next
     to the catch phrase. The public CV entry is labelled "CV page".

## Verification

`scripts/test/test-hero-summary.rb` covers the four file states (home
present, home absent, home blank, neither) and the Studio entry.
