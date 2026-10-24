# Section texts in Studio

## Intent

Every editorial text that introduces a section of the home page or of a listing page should be editable in Studio, from the same `content/pages/headers.yml` Studio already writes, without a rebuild of the shell. Today some of these texts exist in `headers.yml` but have no Studio form (the projects band title and note), some have a Studio field that nothing renders (the Sources / Network / Bibliography panel descriptions), and some are written into the layouts (the "View all" and "Open" labels, the home panel titles, the projects page section banners, the CV section titles). A site that leaves a field empty keeps the theme default, so existing sites render the same text as before.

## Scope

In:

- A Studio form for the projects page entry of `headers.yml`.
- Studio fields for the home calls to action, the Sources and Network panel descriptions, the projects page section banners and the CV section titles.
- A description under the title of each Sources / Network / Bibliography panel on the home page, from that page's `note`.
- The home panel title from that page's `headers.yml` title, like the page heading.
- One runtime hydrator for field-backed labels that keep a theme default, so sites built with `shell_content_agnostic` get the edited text from `pages/headers.json` too.

Out:

- Interface microcopy that is not editorial: "Read", "Read article", "Featured", "Open project", "Repository", "Article", "Source", "Open link", "Details", "Archive", "Filter", the licence rail, the network legend and hint, the timeline controls, the bibliography plate statistics and the band art captions. These stay theme strings (`_data/translations.yml` where they are localized).
- Navigation labels and the hero call to action, which come from the page registry in `_config.yml` (`pandorga.pages[].title`).
- A second language per entry. Each `headers.yml` entry is written in its page's language, as today.
- Studio app code. The new fields use existing field types (`string`), so only the schema changes.

## Data

All new fields are optional strings in the existing `content/pages/headers.yml` entries, keyed by page key (`index` is the references band):

| Entry | Field | Where it shows | Theme default when empty |
|---|---|---|---|
| any page with a home band or panel | `cta` | the "View all" link of its home band, or the "Open" link of its home panel | `pandorga.pages[].home.cta`, else "View all"; "Open" on panels |
| `resources`, `network`, `bibliography` | `note` | description under the panel title in the home references band | none: the element is removed |
| `resources`, `network`, `bibliography` | `title` | panel title in the home references band (already the page heading) | the registry page title |
| `projects` | `others_kicker`, `others_title` | banner above the project grid on the projects page | "Index", "Other projects" |
| `projects` | `repositories_kicker`, `repositories_title` | banner above the repository list on the projects page | "Open source", "Repositories" |
| `cv` | `summary_title`, `experience_title`, `products_title`, `education_title`, `languages_title`, `timeline_title`, `contact_label` | CV section headings and the contact label | "Summary", "Experience", "Products", "Education", "Languages", "Timeline", "Contact" |

`title`, `kicker` and `note` of `projects` already drive the home projects band (`PLT-AC-42`); they only gain a form.

## Acceptance criteria

- `PLT-AC-50` Section texts on the home page, the projects page and the CV page come from `content/pages/headers.yml` and are editable in Studio, with theme defaults when a field is empty. Each item names the gate section that checks it (`test-studio-section-texts`):
  1. **Schema.** `studio/schema.yml`, group `pages`, shall hold a `page_projects` file item (`path: content/pages/headers.yml`, `format: yaml`, `root_key: projects`) with the fields `title`, `kicker`, `note`, `cta`, `others_kicker`, `others_title`, `repositories_kicker`, `repositories_title`, `accent` and `tags`. `page_articles` and `page_rascunhos` shall add `cta`; `page_sources` and `page_network` shall add `note` and `cta`; `page_bibliography` shall add `cta`; `page_cv` shall add `summary_title`, `experience_title`, `products_title`, `education_title`, `languages_title`, `timeline_title` and `contact_label`. Every new field shall be `type: string`, not `required`, with a `description` that names where it shows and its default. The `page_home` item (`root_key: index`) shall be labeled `Home references band`. `templates/network/studio.yml` shall carry the same `note` and `cta` fields as `page_network`. The schema shall still load as YAML and compose (`test-studio-schema-composition`).
  2. **Runtime.** The content runtime shall define `hydrateHeaderTexts(root)`: for every element under `root` with `data-content-header-text="<key>.<field>"` (split on the first dot), when `pages/headers.json` holds a non-blank string at `<key>.<field>`, the element shows it through `parseInlineMarkdown` and `stripSingleParagraph`; otherwise, and when the fetch fails, the element keeps the text it was built with. It shall define `hydratePanelNotes(root)`: an element with `data-content-panel-note="<key>"` shows `<key>.note` the same way and is unhidden; when that note is blank, or when the fetch fails and the element is empty, the element is removed. `hydratePageFragments` shall run both after the page headers, alongside `hydrateHomeSections`. The runtime shall export `loadPageHeaders`, `hydrateHeaderTexts` and `headerText(headers, key, field, fallback)`, which returns the trimmed string at `headers[key][field]` when it is a non-blank string and `fallback` otherwise.
  3. **Home band call to action.** In `_includes/home/band-listing.html` the "View all" label span shall carry `data-content-header-text="{{ band.section_key }}.cta"`, and its built text shall be `site.data.page_headers[band.section_key].cta`, else `band.home.cta`, else "View all".
  4. **Home panels.** In `_includes/home/band-index.html` each panel title `h3.home-index-title` shall carry `data-content-header-text="{{ panel.key }}.title"` and be built from `site.data.page_headers[panel.key].title`, else the current registry title; the Open label span shall carry `data-content-header-text="{{ panel.key }}.cta"` with "Open" as its default. Each panel shall render `<p class="home-index-note font-body" data-content-panel-note="{{ panel.key }}">` after `.home-index-panel-head` and before `figure.home-index-plate`, prefilled from `site.data.page_headers[panel.key].note` when it was read at build time and `hidden` when it is empty. `assets/css/ledger/home.css` shall style `.home-index-note` with tokens only (no color literal, no `!important`).
  5. **Projects page banners.** `_layouts/projects.html` shall read the headers with `runtime.loadPageHeaders()` and build its two section banners with `runtime.headerText` from the page key's `others_kicker`, `others_title`, `repositories_kicker` and `repositories_title`, with the defaults "Index", "Other projects", "Open source" and "Repositories". It shall not pass a literal kicker or title string straight to `renderSectionBanner`.
  6. **CV labels.** `_includes/cv/cv-box.html` shall accept an optional `text_key` and put it on the `h2.cv-register-title` as `data-content-header-text`. `_layouts/cv.html` shall pass each section title from `site.data.page_headers[page.key].<name>_title`, else the current English title, with `text_key` `<page key>.<name>_title`, for summary, experience, products, education and languages. The "Contact" label shall carry `data-content-header-text="{{ page.key }}.contact_label"` and the timeline heading in `_includes/page/timeline-section.html` `data-content-header-text="{{ page.key }}.timeline_title"`, both with their current text as the default.
  7. **Docs and guards.** `docs/pages-and-templates.md` shall list the `headers.yml` fields of the data table above. No layout or include named in 3-6 shall carry an owner-specific string, and `assets/css/ledger/home.css` shall hold no `!important`.

## Design notes

The fields live in `headers.yml` because that file already carries every page title, kicker and band note, Studio already edits it through `root_key` file items, and the content export already publishes it as `pages/headers.json`. A new data file or a new Studio field type would add a second mechanism for the same kind of text.

Two empty-field rules exist on purpose. A description (`note`) is content: when the owner deletes it the element goes away, as band notes already do (`PLT-AC-42`). A label or heading (`cta`, section titles, panel titles) is structure: when the field is empty the theme default stays, so a page never loses its heading or its link text.

The projects page banners are drawn by script, so they read the headers through the runtime instead of a `data-content-header-text` slot.

## Constraints

No new Studio field type and no Studio app rebuild. No Node build for the public shell. Tokens only in CSS, no `!important`. Existing hooks (`data-content-home-section`, `data-content-section-*`, `data-content-band-art`, `home-bib-plate`) keep their names. A site whose `headers.yml` has none of the new fields renders the same text as before, except that a Sources, Network or Bibliography `note` already present in `headers.yml` now shows on its home panel.
