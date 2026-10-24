# Section texts in Studio

## Intent

Every editorial text that introduces a section of the home page or of a listing page should be editable in Studio, from the same `content/pages/headers.yml` Studio already writes, without a rebuild of the shell. Today some of these texts exist in `headers.yml` but have no Studio form (the projects band title and note), some have a Studio field that nothing renders (the Sources / Network / Bibliography panel descriptions), and some are written into the layouts (the "View all" and "Open" labels, the home panel titles, the projects page section banners, the CV section titles). A site that leaves a field out keeps the theme default, so existing sites render the same text as before. A site that saves a field empty hides that text.

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
- New Studio field types. The new fields use the existing `string` type. The only Studio app change is the save rule for emptied fields (item 8).

## Data

All new fields are optional strings in the existing `content/pages/headers.yml` entries, keyed by page key (`index` is the references band):

| Entry | Field | Where it shows | When the key is absent | When the value is empty |
|---|---|---|---|---|
| any page with a home band | `cta` | the "View all" link of its home band | `pandorga.pages[].home.cta`, else "View all" | no link (the band aside is not rendered) |
| `resources`, `network`, `bibliography` | `cta` | the "Open" link of its home panel | "Open" | no link |
| `resources`, `network`, `bibliography` | `note` | description under the panel title in the home references band | no description | no description |
| `resources`, `network`, `bibliography` | `title` | panel title in the home references band (already the page heading) | the registry page title | no panel title; the panel keeps the registry title as its accessible name |
| `projects` | `others_kicker`, `others_title` | banner above the project grid on the projects page | "Index", "Other projects" | empty kicker: no kicker; empty title: no banner at all |
| `projects` | `repositories_kicker`, `repositories_title` | banner above the repository list on the projects page | "Open source", "Repositories" | empty kicker: no kicker; empty title: no banner at all, and the list keeps "Repositories" as its accessible name |
| `cv` | `summary_title`, `experience_title`, `products_title`, `education_title`, `languages_title` | CV section headings | "Summary", "Experience", "Products", "Education", "Languages" | no heading; the section keeps the default as its accessible name |
| `cv` | `timeline_title` | timeline heading | "Timeline" | no heading row; the section keeps "Timeline" as its accessible name |
| `cv` | `contact_label` | the label over the contact links | "Contact" | no label |

`title`, `kicker` and `note` of `projects` already drive the home projects band (`PLT-AC-42`); they only gain a form.

### Absent and empty

The two cases are different on purpose, for every field in the table above:

- **Absent.** The key is missing, its value is `null`, or its value is not a string. The theme default shows (for a `note`, the default is no description). A site that never sets a field renders what it renders today.
- **Empty.** The key holds a string that is empty or only whitespace. The element is not rendered at all: no empty element, no wrapper left behind, no separator, no stand-in text. A home band without its link keeps its title row; a panel without title and link has no head row; a projects banner without a title is not drawn, kicker included, because `renderSectionBanner` already returns nothing without a title (a kicker alone is not a banner, `test-absent-field-absent-element`). A non-empty value is trimmed and shown.
- **Accessible names.** A heading hidden this way does not take its region's name with it. The element that the heading named (the home panel `article`, the CV `section.cv-register`, the timeline `section`, the projects repository `section`) gets `aria-label` set to the default text. Labels and links that are not headings are dropped without a replacement.
- The rule is the same at build time (Liquid, when `site.data.page_headers` was read at build time) and at run time (the content runtime, from `pages/headers.json`, for `shell_content_agnostic` builds). Liquid must test the key against `nil` and never use `| default:` on these fields, since `default` treats an empty string as absent.

### Studio saves an emptied field as an empty string

Studio drops empty values on save today: `pruneEmptyFields` (`studio-app/src/lib/yaml-doc.js`, called for every YAML map and `root_key` save in `studio-app/src/main.js`) deletes a schema field whose value is `""`, `null`, `undefined` or `[]`. For these fields that would turn "empty" back into "absent" and bring the default back. So:

- Each field in the table carries `keep_empty: true` in the schema, next to `type: string` and without `required`.
- `pruneEmptyFields` keeps a `keep_empty` field whose value is a string, including `""`, and still drops it when the value is `null` or `undefined`. Fields without `keep_empty` keep today's behavior.
- The form writes the input's value on every edit (`target[name] = e.target.value`), so clearing an input stores `""`. An input the editor never touched writes nothing, so an absent key stays absent.
- To bring a default back after emptying a field, the editor deletes the line in the YAML source view. The field descriptions say so in one sentence.
- The schema loader already passes unknown field properties through, so `keep_empty` needs no loader change. The committed bundle in `studio/assets/` is rebuilt with the change.
- The `title` of `resources`, `network` and `bibliography` does not get `keep_empty`: it is also the page heading, which this feature does not change. An empty panel title can still be set in the YAML source view.

## Acceptance criteria

- `PLT-AC-50` Section texts on the home page, the projects page and the CV page come from `content/pages/headers.yml` and are editable in Studio, with theme defaults when a field is absent and nothing rendered when it is empty (see "Absent and empty"). Each item names the gate section that checks it (`test-studio-section-texts`):
  1. **Schema.** `studio/schema.yml`, group `pages`, shall hold a `page_projects` file item (`path: content/pages/headers.yml`, `format: yaml`, `root_key: projects`) with the fields `title`, `kicker`, `note`, `cta`, `others_kicker`, `others_title`, `repositories_kicker`, `repositories_title`, `accent` and `tags`. `page_articles` and `page_rascunhos` shall add `cta`; `page_sources` and `page_network` shall add `note` and `cta`; `page_bibliography` shall add `cta`; `page_cv` shall add `summary_title`, `experience_title`, `products_title`, `education_title`, `languages_title`, `timeline_title` and `contact_label`. Every new field shall be `type: string`, not `required`, `keep_empty: true`, with a `description` that names where it shows, its default and what an emptied field does. The `page_home` item (`root_key: index`) shall be labeled `Home references band`. `templates/network/studio.yml` shall carry the same `note` and `cta` fields as `page_network`, also with `keep_empty: true`. The schema shall still load as YAML and compose (`test-studio-schema-composition`).
  2. **Runtime.** The content runtime shall define `headerText(headers, key, field, fallback)`: it returns `fallback` when `headers` is not an object, `headers[key]` is not a plain object, or `headers[key][field]` is not a string (absent, `null`, number, array), and the trimmed string otherwise, which may be `""`. It shall define `hydrateHeaderTexts(root)`: for every element under `root` with `data-content-header-text="<key>.<field>"` (split on the first dot), `headerText(headers, key, field, null)` decides. `null` leaves the element as built. A non-empty string replaces its content through `parseInlineMarkdown` and `stripSingleParagraph`. `""` removes the element, or its nearest ancestor-or-self carrying `data-content-header-wrap` when there is one; when the element is a heading (`h1`-`h6`), first the nearest ancestor carrying `data-content-header-name` gets `aria-label` from the element's built text, unless it already has `aria-label` or `aria-labelledby`; then, when the removed node's parent carries `data-content-header-group` and has no element child left, the parent is removed too. On a fetch failure every element stays as built. It shall define `hydratePanelNotes(root)`: an element with `data-content-panel-note="<key>"` shows `<key>.note` the same way and is unhidden; when that note is absent or empty, or when the fetch fails and the element is empty, the element is removed. Both return without a fetch when `root` holds no such element, and use only `querySelectorAll`, `closest`, `getAttribute`, `hasAttribute`, `setAttribute`, `remove`, `parentElement`, `childElementCount`, `tagName`, `textContent`, `innerHTML`, `hidden` and `classList` (the gate runs them on a stub DOM under Node). `hydratePageFragments` shall run both after the page headers, alongside `hydrateHomeSections`. The runtime shall export `loadPageHeaders`, `hydrateHeaderTexts` and `headerText`. `renderSectionBanner` (`43-blocks.html`) is unchanged: it returns `''` without a title.
  3. **Home band call to action.** In `_includes/home/band-listing.html` the "View all" label span shall carry `data-content-header-text="{{ band.section_key }}.cta"`. Its built text shall be `band.home.cta`, else "View all", replaced by `site.data.page_headers[band.section_key].cta` (stripped) when that key is not `nil`. When the result is empty, the `.home-section-aside` (which carries `data-content-header-wrap`) is not rendered.
  4. **Home panels.** In `_includes/home/band-index.html` each panel title `h3.home-index-title` shall carry `data-content-header-text="{{ panel.key }}.title"` and be built from `site.data.page_headers[panel.key].title` (stripped) when that key is not `nil`, else the current registry title; the Open link `a.ledger-cta` shall carry `data-content-header-wrap` and its label span `data-content-header-text="{{ panel.key }}.cta"`, with "Open" as the default and the headers `cta` (stripped) when not `nil`. An empty title or label is not rendered, and `.home-index-panel-head` (which carries `data-content-header-group`) is not rendered when both are empty. The `article.home-index-panel` carries `data-content-header-name` and, when its title is empty, `aria-label` with the registry title. Each panel shall render `<p class="home-index-note font-body" data-content-panel-note="{{ panel.key }}">` after `.home-index-panel-head` and before `figure.home-index-plate`, prefilled from `site.data.page_headers[panel.key].note` when it was read at build time and `hidden` when it is absent or empty. `assets/css/ledger/home.css` shall style `.home-index-note` with tokens only (no color literal, no `!important`).
  5. **Projects page banners.** `_layouts/projects.html` shall read the headers with `runtime.loadPageHeaders()` and build its two section banners with `runtime.headerText` from the page key's `others_kicker`, `others_title`, `repositories_kicker` and `repositories_title`, with the defaults "Index", "Other projects", "Open source" and "Repositories". It shall not pass a literal kicker or title string straight to `renderSectionBanner`. When the repositories title is empty, `section.projects-repos` gets `aria-label="Repositories"` (on the same source line that opens the section).
  6. **CV labels.** `_includes/cv/cv-box.html` shall accept an optional `text_key` and put it on the `h2.cv-register-title` as `data-content-header-text`, and an optional `label` (the default heading). The `section.cv-register` carries `data-content-header-name`; when `include.title` is empty it renders no `h2` and carries `aria-label="{{ include.label }}"`. `_layouts/cv.html` shall build each section title as the current English title, replaced by `site.data.page_headers[page.key].<name>_title` (stripped) when that key is not `nil`, and pass it with `text_key` `<page key>.<name>_title` and `label` the English title, for summary, experience, products, education and languages. The "Contact" label shall carry `data-content-header-text="{{ page.key }}.contact_label"`, built the same way from `contact_label`, and is not rendered when empty. The timeline heading in `_includes/page/timeline-section.html` shall carry `data-content-header-text="{{ page.key }}.timeline_title"`, built the same way from `timeline_title` with "Timeline" as the default; its `.cv-band-head` carries `data-content-header-wrap` and is not rendered when the title is empty, and the `section#timeline-section` carries `data-content-header-name` and, when the title is empty, `aria-label="Timeline"`.
  7. **Docs and guards.** `docs/pages-and-templates.md` shall list the `headers.yml` fields of the data table above and state the absent and empty rule and `keep_empty`. No layout or include named in 3-6 shall carry an owner-specific string, and `assets/css/ledger/home.css` shall hold no `!important`.
  8. **Studio keeps an emptied field.** `pruneEmptyFields` in `studio-app/src/lib/yaml-doc.js` shall keep a known field declared with `keep_empty: true` when its value is a string, `""` included, and drop it when it is `null` or `undefined`; other known fields keep today's pruning (`""`, `null`, `undefined`, `[]` dropped) and unknown keys are kept. It stays self-contained (the gate runs it alone under Node). The bundle that `studio/index.html` loads shall contain `keep_empty`, so the committed build carries the change.

## Design notes

The fields live in `headers.yml` because that file already carries every page title, kicker and band note, Studio already edits it through `root_key` file items, and the content export already publishes it as `pages/headers.json`. A new data file or a new Studio field type would add a second mechanism for the same kind of text.

An absent field and an empty field mean different things. Absent means the owner never wrote the text, so the theme default stands in and existing sites do not change. Empty means the owner chose to have no text there, so nothing stands in: a page can drop its "View all" link, a CV heading or a description. Earlier drafts kept the default for an empty label so a page never lost its heading; the owner preferred control, and the accessible name fallback covers the part of that concern that matters to screen readers. Because Studio used to delete empty values on save, the empty case needs `keep_empty` to survive a save.

The projects page banners are drawn by script, so they read the headers through the runtime instead of a `data-content-header-text` slot.

## Constraints

No new Studio field type. One Studio app change (item 8) and a rebuild of the committed bundle. No Node build for the public shell. Tokens only in CSS, no `!important`. Existing hooks (`data-content-home-section`, `data-content-section-*`, `data-content-band-art`, `home-bib-plate`) keep their names. The new hooks are `data-content-header-text`, `data-content-header-wrap`, `data-content-header-group`, `data-content-header-name` and `data-content-panel-note`. A site whose `headers.yml` has none of the new fields renders the same text as before, except that a Sources, Network or Bibliography `note` already present in `headers.yml` now shows on its home panel.
