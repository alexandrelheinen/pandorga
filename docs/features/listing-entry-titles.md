# Listing entry titles

## Intent

The entry titles on the collection pages set at one size. The Rascunhos
rows already used the larger card step at every width, while the Articles
rows and the Sources cards used the base card step and shrank to the small
step below 768px. The Bibliography cards sat on the base step at every
width. The Rascunhos size is the reference: every listing entry title now
uses it, so a title on the Articles page reads like one on the Rascunhos
page, and a source card reads like a bibliography card.

## Scope

In:

- The listing row title `.ledger-row-title` that `renderLedgerRow` builds
  for the Articles and Rascunhos pages.
- The Sources card title `.source-card-title` and the Bibliography card
  title `.bib-card-title`.

Out:

- Page headers (`.page-header-title`), which already share one rule.
- Detail-page titles (`.text-title`), which already match between articles
  and posts.
- The home bands and the projects page, whose cards keep their own scale.

## Acceptance criteria

- `PLT-AC-55` Listing entry titles share one size.
  1. **One rule.** `assets/css/base.css` has a single rule whose selector
     list is `.ledger-row-title`, `.source-card-title` and `.bib-card-title`.
     It sets `font-size: var(--type-card-lg)` and `line-height: 1.25`, and it
     sits after the small-screen `.card-title` step, so it holds at every
     width.
  2. **No overrides.** No other stylesheet rule whose last compound selector
     is one of those three classes sets `font-size` or `line-height`. That
     includes the Rascunhos and Bibliography sheets and any media query.
  3. **Markup.** The Articles and Rascunhos rows carry `ledger-row-title`,
     the Sources cards carry `source-card-title`, and the Bibliography cards
     carry `bib-card-title`.

## Verification

- `scripts/test/test-listing-entry-titles.rb` checks the three criteria
  against the stylesheets and the runtime markup.
- In a browser at 1440px and 390px, the computed `font-size` and
  `line-height` of an entry title match on the Articles, Rascunhos, Sources
  and Bibliography pages.
