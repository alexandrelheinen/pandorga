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
  1. **Own file (content-coupled).** When `shell_content_agnostic` is off and
     `content/pages/home/summary.md` exists with a non-blank body, the hero
     renders that body as static HTML (`data-content-static`), and
     `cv/summary.md` does not reach the hero (PLT-AC-23 / Lighthouse example).
  2. **Own file (content-agnostic).** When `shell_content_agnostic` is on and
     `home/summary.md` exists (blank aside), the hero is a quiet
     `home/summary` fragment hydrated from `pages/home/summary.json` on R2.
     Studio edits publish through the content pipeline; the shell does not
     need a redeploy.
  3. **Absent falls back.** When `home/summary.md` is absent, the hero
     renders `cv/summary` (static when content-coupled and the CV file has
     text; quiet fragment otherwise).
  4. **Empty hides.** When `home/summary.md` exists with a blank body (front
     matter aside), the hero renders no summary element at all.
  5. **CV unchanged.** The CV page Summary section still reads the
     `cv/summary` fragment; the hero file never feeds it.
  6. **Studio.** The Presentation group has a "Hero summary" file entry for
     `content/pages/home/summary.md` (`format: raw`, `markdown_body`), next
     to the catch phrase. The public CV entry is labelled "CV page".

## Verification

`scripts/test/test-hero-summary.rb` covers the file states (home present,
home absent, home blank, neither), the agnostic quiet slot, and the Studio
entry.
