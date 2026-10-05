# Platform and website separation migration plan

Status: **v1.0 platform shipped**; Phase 6 items (`pandorga new`, RubyGems,
Android Studio) deferred. Phase 0 spikes and §13 defaults are recorded in
[decisions.md](decisions.md) (`PLT-0.1`–`PLT-0.5`). Sites use the page registry
plus Jekyll layouts today; full §5.3 template packages and Studio `studio.yml`
coverage remain thin and are still evolving. The phase narrative below is the
migration plan that produced this cut.

This repository currently holds two mixed concepts. It contains a publishing platform, which includes a Jekyll shell, a browser runtime, an R2 exporter, the Studio, and testing gates. It also contains the website of a specific person, which includes content, a private CV, studies, visual identity, and Cloudflare configuration. This document outlines a plan to extract the platform into a public, polished, and documented repository. The `website` repository will remain as a content manager and specific site implementation that consumes the platform as a versioned dependency.

Traceability prefix is `PLT`. See `[.guidelines/workflow/sdd.md](../../.guidelines/workflow/sdd.md)`.

## 1. Repository name

The proposed name is **pandorga**.

Pandorga is the word for kite in Southern Brazil, representing a light frame of sticks that only flies when someone glues the paper, chooses the colors, and releases the line. The metaphor represents exactly the boundary of this plan. The platform is the frame (templates, runtime, pipeline, Studio), while the website is the paper (content, identity, palette). The name is short, pronounceable in English, does not collide with any known tool in the Jekyll ecosystem, and provides natural names to the artifacts.

| Artifact | Name |
|---|---|
| Repository | `pandorga` |
| Gem (theme + plugins + CLI) | `pandorga` |
| CLI commands | `pandorga export`, `pandorga publish`, `pandorga doctor`, `pandorga new` |
| Reusable workflow | `<owner>/pandorga/.github/workflows/content-pipeline.yml@v1` |
| Editor | Pandorga Studio |

Alternatives, in case the owner prefers a descriptive name over a brand name, include `ledger-press` (referencing the "Architectural Ledger" design system) or `headless-folio`. Before settling on a name, phase 0 will verify availability on GitHub, RubyGems, and npm (§11, `PLT-0.4`).

The asset file `assets/images/pandorga-*.svg` and the include `page/hero-pandorga.html` belong to the website art, not the platform, and will remain in the `website` repository (§4). The platform name must not drag the specific art along with it.

## 2. Intent

The target audience includes anyone who wants a personal writing and portfolio website with a static shell, content served as JSON, and a custom CMS, without a Node pipeline for the public site. The first user is this website.

**Expected results**

1. A public `pandorga` repository that anyone can clone, configure, and publish without reading the code, containing examples that run without a Cloudflare account.
2. The `website` repository reduced to content, configuration, visual identity, and the few extensions that only make sense locally (private CV in PDF, studies, homepage art).
3. Modular pages where a page equals a template plus a collection. Declaring a page in the configuration is enough to make it appear in the navigation, on the homepage, in the routes, in the exporter, and in the Studio.

**Out of scope**

- Replacing Jekyll, Tailwind CDN, or R2. The platform inherits the current constraints (no Node build for the public site, no JS bundler, field-oriented rendering).
- Changing public URLs of this website. Every existing URL will continue to resolve after the migration (`PLT-AC-9`).
- Publishing the private CV, not even as an example (§6.4).

**Constraints**

- No Node build for the public site, no JS bundler, and Tailwind loaded via CDN (`AGENTS.md` § Constraints). The Studio remains the only piece compiled with Vite, and compilation happens in the platform CI, not during the website deployment.
- The runtime in `_includes/content-runtime/` remains a single module, concatenated in order.
- The names of editorial includes (`figure.html`, `xcite.html`, etc.) do not change and do not move from the root of `_includes/`, as they appear in published Markdown.
- Target stack is Ruby 3.3+ and Jekyll 4.3, with Cloudflare Pages and R2 as the documented deployment target.
- Field-oriented rendering ensures a template does not draw an element without a supporting field.
- No phase can leave production with a broken URL or expose private content, not even temporarily.

## 3. Boundary principles

1. The platform does not know the owner. No name, email, URL, bucket ID, Clerk ID, GitHub repository, tag vocabulary, or editorial text exists inside `pandorga`. All of this comes from the website configuration. A privacy gate (§6.3) fails the CI if anything leaks.
2. The website does not contain platform code. If a file in the `website` repository implements something that another site would also use, it is in the wrong repository. Local extensions exist, but through documented extension points (§5.6), not by copying and editing layouts.
3. Pages have a single source of truth. Navigation, homepage, routes, export, and Studio schema all derive from the same page registry (§5.2). Currently, this information is scattered across `_data/nav.yml`, `pages/*/index.html`, `_layouts/home.html`, `_redirects`, `export-content-json.rb`, `content_site_adapter.rb`, `tag_validator.rb`, and `studio/schema.yml`.
4. The platform is versioned, not copied. The `website` repository pins a version (`~> 0.x`) and updates via pull request. No hand-edited submodules are allowed.

## 4. Inventory of artifact destinations

This inventory is based on the current tree. "Platform" means moving the file to `pandorga` and generalizing what is coupled. "Website" means keeping the file in `website`.

| Current path | Destination | Note |
|---|---|---|
| `_layouts/shell.html`, `text.html`, `article.html`, `post.html`, `project.html`, `product.html` | Platform | Remove `Alexandre L. Heinen` from title suffix and default author. Read from `site.pandorga.identity`. |
| `_layouts/articles.html`, `blog.html`, `projects.html`, `resources.html`, `network.html`, `bibliography.html`, `cv.html` | Platform as templates (§5.3) | Each layout becomes a template module. |
| `_layouts/home.html` | Platform | Fixed bands become a loop over the page registry (§5.4). The hero becomes a module. |
| `_layouts/cv-print.html`, `_includes/cv/cv-print-*`, `_private/`, `_config_private.yml` | **Website** | Private CV with embedded contact data in `cv-print-header.html`. |
| `_includes/content-runtime/*` (15 fragments) | Platform | It remains a monolithic module and gains a template registry. |
| `_includes/page/*`, `_includes/theme/*` | Platform | Except `hero-pandorga.html` which goes to the website. |
| `_includes/figure.html`, `xcite.html`, `plotly.html`, `youtube*.html`, `video.html`, `tweet.html`, `mathjax.html` | Platform | Names stay in the root of `_includes/` because they appear in published Markdown. |
| `_includes/chord-tab.html`, `transcription.html`, `dict-card.html`, `cut-in.html`, `ongoing-product.html` | Platform as optional includes | These are generic. Phase 1 will check if any depend on data from this website. |
| `_plugins/*` | Platform (`lib/pandorga/`) | `tag_validator.rb` loses the embedded vocabulary (§5.2). `content_site_adapter.rb` and `timeline.rb` lose the fixed list of collections. |
| `_plugins/job_sections.rb`, `timeline.rb` | Platform (`cv` template) | |
| `_data/themes/*.yml`, `_data/translations.yml` | Platform as default, website overrides | The Architectural Ledger theme becomes the default theme. |
| `_data/nav.yml` | Removed | Generated by the page registry. |
| `pages/*/index.html` | Removed | Generated, except `pages/license/` which stays in the website. |
| `_redirects` | Split | Detail rules are generated by the platform. Legacy slugs and the content-key redirects block remain in the website. |
| `assets/css/base.css`, `article.css`, `global-link.css`, `assets/css/ledger/*` | Platform | Per-page CSS moves to the corresponding template. |
| `assets/css/cv-print.css` | Website | |
| `assets/tailwind-play.js` | Platform | |
| `assets/icons/favicon.svg`, `assets/images/*`, `favicon.ico` | Website | The platform provides a neutral favicon and OG assets. |
| `scripts/content/*`, `scripts/lib/*` | Platform (`pandorga` CLI) | `export-content-json.rb` will read the registry instead of the fixed list on lines 643 to 652. |
| `scripts/content/hero_portraits.rb`, `band_art.rb` | Platform | Generic mechanisms. The photos and palette belong to the website. |
| `scripts/pdf/*` | Platform (optional) | PDF generation from Markdown is useful for any website. |
| `scripts/cv/*` | **Website** | Generates the private CV PDFs. |
| `scripts/visual/*` | Platform | The list of pages to photograph comes from the registry. |
| `scripts/guidelines/*` | Website | The guidelines package belongs to the owner. The platform only reads a configurable URL. |
| `scripts/test/*` (35 gates) | Split (§8) | |
| `studio-app/`, `studio/` (build), `functions/api/studio/` | Platform | Remove `alexandrelheinen/website` as default `GITHUB_REPO` and the `origin.includes("alexandrelheinen")` from CORS. |
| `studio/schema.yml` | Generated | Composed of template schemas plus website overrides (§5.5). |
| `studio-mobile/` | Platform (optional, phase 6) | `dev.alexandrelheinen.studio` and the default URL become configuration variables. |
| `content/**` | **Website** | All editorial content. |
| `studies/**` | **Website** | Study data and scripts. |
| `docs/editorial/*`, `docs/content/taxonomy.md`, `docs/projects-illustration.md`, `docs/features/reimagined-borders.md` | Website | Editorial and design decisions for this website. |
| `docs/content/architecture.md`, `elements.md`, `studio.md`, `docs/ops/cloudflare.md`, feature specs | Platform, rewritten in English | `docs/ops/cloudflare.md` keeps a summary in the website repository using real IDs. |
| `DESIGN.md` | Platform (default theme) and a note in the website | |
| `.guidelines/` (private SSH submodule) | Website | The platform does not depend on it and documents its own conventions in `CONTRIBUTING.md`. |
| `.github/workflows/content-pipeline.yml`, `content-detail-url-gate.yml`, `visual-inspection.yml`, `python-quality.yml` | Platform as reusable workflows. Website calls with `uses:` | |
| `.github/workflows/generate-private-cv.yml`, `guidelines-pipeline.yml` | Website | |
| `LICENSE` (MIT) | Platform as MIT, holder to be decided (§13) | |
| `LICENSE-CONTENT` (CC BY 4.0), `pages/license/` | Website | The platform provides the `content_license` mechanism without a holder. |

## 5. Platform architecture

### 5.1 Distribution

The platform is a single gem that acts simultaneously as a Jekyll theme (`_layouts`, `_includes`, `assets`), a plugin (`lib/pandorga/**`, registered via `plugins:`), and a CLI (`exe/pandorga`). The website declares it as follows.

```ruby
# website/Gemfile
gem "pandorga", github: "<owner>/pandorga", tag: "v0.3.0"
```

```yaml
# website/_config.yml
theme: pandorga
plugins: [pandorga]
```

Using a Git source instead of RubyGems in the early versions avoids publishing too soon. Cloudflare Pages already runs `bundle install` during the build, so the Git source works without infrastructure changes. This will be verified in phase 0 (`PLT-0.1`).

During joint development, running `bundle config local.pandorga ../pandorga` points the website to the local checkout without editing the `Gemfile`.

The Studio and Pages Functions present the most difficult challenge. Cloudflare Pages reads `functions/` from the project root, not from inside a gem. There are two options to be decided by the `PLT-0.2` spike.

Option A is preferred. The Pages build command runs `bundle exec pandorga install-functions && jekyll build`, which copies `functions/` and the already compiled `studio/` from inside the gem to the root before Pages compiles the Functions. Nothing is vendored in the website Git repository.

Option B is the fallback. The command `pandorga sync` copies the files to the website and saves the version in `functions/.pandorga-version`. A gate in the website fails if the copy diverges from the version pinned in `Gemfile.lock`.

The Vite `studio-app` is compiled in the platform CI and published as a release artifact. The gem embeds the compiled `studio/` directory. The website remains without a Node build.

### 5.2 Page registry

A single configuration key describes the website pages. An example with the seven pages of this website is shown below.

```yaml
# website/_config.yml
pandorga:
  identity:
    name: "…"                # title, <title> suffix, default author, BibTeX
    url: "https://…"
    locale: en
  content:
    backend: r2              # r2 | static (static = JSON served from _site itself)
    base_url: "https://…"
  studio:
    repo: "<owner>/website"
    allowed_origins: ["https://…"]

  pages:
    - key: cv
      template: cv
      collections: { jobs: jobs, products: products, profile: data }
      path: /pages/cv/
      nav:  { group: Profile, icon: article_person }
      home: { band: hero }

    - key: projects
      template: portfolio
      collection: projects
      path: /pages/projects/
      detail: /projects/:slug/
      nav:  { group: Profile, icon: terminal }
      home: { limit: 4 }

    - key: articles
      template: articles
      collection: articles
      path: /pages/articles/
      detail: /articles/:slug/
      language: en
      accent: green
      taxonomy: { tags: [Aesthetics, AI, Data, DevOps, Mathematics, Robotics, Social], max: 3, min: 1 }
      nav:  { group: Writing, icon: newsmode }
      home: { featured: true, limit: 3 }

    - key: blog
      template: blog
      collection: posts
      path: /pages/blog/
      detail: /posts/:slug/
      language: pt-BR
      accent: ochre
      taxonomy: { tags: [arte, brasilidade, carme, …], max: 3 }
      nav:  { group: Writing, icon: stylus_note }
      home: { limit: 4 }

    - key: resources
      template: media
      collection: resources
      path: /pages/sources/
      detail: /sources/:slug/
      nav:  { group: References, icon: media_link }
      home: { band: index, group: references }

    - key: network
      template: network
      sources: [articles, blog]          # pages, not collections
      path: /pages/network/
      nav:  { group: References, icon: flowchart }
      home: { band: index, group: references }

    - key: bibliography
      template: bibliography
      collection: bibliography
      cited_by: [articles, blog]
      path: /pages/bibliography/
      home: { band: index, group: references }
```

Registry rules are as follows.

The `template` attribute selects the module (§5.3). The `collection` attribute (or `collections`, when the template has more than one slot) points to folders inside `content/collections/`. Two pages can use the same template with different collections, such as two blogs in different languages.

The list order defines the navigation and homepage order. Setting `nav: false` removes the page from the menu. Setting `home: false` removes it from the homepage. If omitted, template defaults apply, meaning every declared page enters the tree and the homepage.

Everything that is currently editorial text, like titles, kickers, and band notes, remains in `content/pages/headers.yml`, indexed by `key`. The registry only states what exists. The content dictates how it is presented.

The `taxonomy` attribute replaces the `VOCABULARY` embedded in `tag_validator.rb`. The platform validates against what the website declares.

The registry is validated during the build using the schema in `lib/pandorga/registry/schema.yml`. A duplicate key, unknown template, non-existent collection, or conflicting route will fail the build with a message pointing to the line.

**Artifacts generated from the registry**

| Maintained manually today | Generated by the platform |
|---|---|
| `pages/<name>/index.html` | A Jekyll generator creates a `PageWithoutAFile` per entry. |
| `_data/nav.yml` | Available at `site.data.pandorga_nav`, grouped by `nav.group`. |
| Fixed bands in `_layouts/home.html` | A loop over pages with an active `home` attribute (§5.4). |
| Detail rules in `_redirects` | A generated block. The website keeps only legacy redirects. |
| Collection list in `export-content-json.rb` and `content_site_adapter.rb` | The exporter iterates over the registry. |
| `studio/schema.yml` | Composed dynamically (§5.5). |
| Page list for `visual-inspection` | Read directly from the registry. |

### 5.3 Templates

A template is a self-contained directory with an explicit contract.

```text
templates/<name>/
├── template.yml      # collection slots, mandatory and optional fields, nav and home defaults, detail routes
├── layout.html       # becomes _layouts/pandorga/<name>.html
├── home-band.html    # homepage band (optional)
├── runtime.js.html   # registers listing and detail logic in ContentRuntime.templates
├── style.css         # currently found in assets/css/ledger/<page>.css
├── studio.yml        # Studio fields for each collection slot
├── fixtures/         # minimal collection used by tests and examples
└── README.md         # contract, configuration, screenshot
```

The central runtime in `_includes/content-runtime/` remains a single module, as required by `AGENTS.md`. It gains `ContentRuntime.templates.register(name, {...})`. The listing code that currently lives in inline `<script>` tags inside each layout (400 to 460 lines of script in each of `articles.html`, `blog.html`, and `projects.html`) moves to the `runtime.js.html` of the template. Each layout loads only its own script.

The seven templates mapped to their current equivalents are listed below.

| Template | Current page | Collection slots | Detail | Default homepage band |
|---|---|---|---|---|
| `cv` | `/pages/cv/` | `jobs`, `products`, `profile` (data) | `/products/:slug/` | `hero` (summary + contacts + optional portrait) |
| `articles` | `/pages/articles/` | one writing collection | yes | grid of cards with featured item |
| `blog` | `/pages/blog/` | one writing collection | yes | dense list (ledger) |
| `media` | `/pages/sources/` | `resources` | `?resource=` | panel in the references group |
| `network` | `/pages/network/` | none. Derives from pages in `sources` | no | panel with graph art |
| `bibliography` | `/pages/bibliography/` | `bibliography` plus pages in `cited_by` | no | panel in the references group |
| `portfolio` | `/pages/projects/` | `projects` | yes | grid of system cards |

The `articles` and `blog` templates share the writing contract (`title`, `key`, `date`, `tags`, `language`, `thumbnail`, Markdown body with includes) and feed the `writing_index`, the network, and the citations. The only difference is the presentation. Any writing template page automatically enters the writing index. The `network` and `bibliography` templates declare which pages they read from.

The `cv` template only exports `body_public`. The rule currently in `PRIVATE_JOB_EXPORT_FIELDS` (`export-content-json.rb`, line 279) is reversed. The contract lists the exportable fields, and any other field (`body_extended`, `body_single_page`, or whatever the website invents) never leaves the repository. It becomes an allowlist, not a blocklist.

### 5.4 Homepage

The homepage becomes a composition.

The Hero is a standalone module. It reads identity data, the `home/subtitle` and `cv/summary` fragments (when a `cv` page exists), contact info, and the `hero-portraits` set if available. Decorative art is a slot (`pandorga.home.hero_art: page/hero-pandorga.html`) that the website fills.

Bands are rendered one per page for any page with an active `home` attribute. They appear in registry order, each rendered by the `home-band.html` of its specific template.

Groups are formed by pages sharing the same `home.group` attribute. They share a panel band, like the current "Sources, Network & Bibliography" band. The band text for the group comes from `headers.yml` using the group key.

Background alternation (`home-band--contrast`) and accents (`page-accent--*`) derive from the registry `accent` attribute and the list position, rather than manually written classes.

### 5.5 Studio

The composed schema is built by the `pandorga studio-schema` command. It generates `studio/schema.yml` from the `studio.yml` of each used template, instantiated with the registry collections and taxonomy, plus an optional website `studio.overrides.yml`. This happens during the build process. The `test-studio-content-files` gate will compare the generated output with the expected output.

The Function operates without an embedded owner. `GITHUB_REPO` becomes mandatory without a default. CORS is read from `STUDIO_ALLOWED_ORIGINS` with exact equality instead of the current `origin.includes("pages.dev")` which accepts any Pages project.

Correct and Refine behaviors are updated. The guidelines package becomes a configurable URL (`STUDIO_GUIDELINES_URL`). Without it, Refine is disabled while Correct continues to function as outlined in `studio-proof.md`.

Android support is planned for phase 6. The `applicationId`, URL, and app name will come from EAS variables. The platform will document how to generate the APK with custom identity.

### 5.6 Website extension points

The website does not edit platform layouts. It uses the mechanisms listed below.

| Extension point | Usage in this website |
|---|---|
| Overriding an include by the same path (native Jekyll theme mechanism) | `page/hero-pandorga.html` |
| `pandorga.home.hero_art` | Kite art in the hero |
| `_data/themes/*.yml` in the website overriding the default theme | Custom palette, if it diverges |
| `_data/translations.yml` in the website overriding the default | Labels in Portuguese |
| `assets/css/site/*.css` (loaded after platform styles) | Local adjustments |
| Local templates in `_templates/<name>/` with the same contract | None today, but the door is open |
| Export hooks (`Pandorga::Export.register_derived`) | Custom band art, if the website wants a different one |
| Custom workflows alongside the reusable ones | Private CV and guidelines pipeline |

## 6. Privacy and polish

### 6.1 Occurrences found in platform code

A search for names, emails, domains, and bucket IDs outside of `content/`, `studies/`, and `docs/editorial/` revealed items that must become configuration before extraction.

| File | Occurrence | Destination |
|---|---|---|
| `_layouts/shell.html` | `Alexandre L. Heinen` in the `<title>` | `identity.name` |
| `_layouts/text.html` | default author in BibTeX | `identity.name` |
| `_includes/content-runtime/50-detail.html` | default author in BibTeX and `siteSuffix` | `ContentRuntimeConfig.defaultAuthor` (already exists) and `identity.name` |
| `_layouts/projects.html` | comment citing `alexandrelheinen/freshy` | Rewrite the comment with a neutral example |
| `functions/api/studio/_lib/github.js` | default `alexandrelheinen/website` | Mandatory `GITHUB_REPO` |
| `functions/api/studio/[[path]].js` | `origin.includes("alexandrelheinen")` | `STUDIO_ALLOWED_ORIGINS` |
| `studio-app/src/main.js` | R2 bucket public URL as default | `content.base_url`, injected in the Studio build |
| `studio-mobile/app.config.ts`, `eas.json`, `resolve-web-app-url.cjs`, tests | `dev.alexandrelheinen.studio` and URL | EAS variables. Tests use the `example.com` domain |
| `.dev.vars.example` | real Clerk issuer and real repo | Placeholders |
| `_config.yml` | R2 bucket ID, author, social, collection defaults with author | Stays in the website. The platform provides an example `_config.yml` |
| `scripts/lib/content_license.rb` | default license holder | `content_license.rights_holder` without a default |
| `scripts/pdf/md-to-pdf.mjs` | default author and domain (lines 454, 807, 812, 1359) | `identity` |
| `assets/icons/favicon.svg`, `assets/images/pandorga-*.svg` | custom art | Website. The platform provides neutral art |
| `_redirects` | bucket ID in the `/media/*` rule and real slugs | Rule `/media/*` generated from `content.base_url`. Slugs stay in the website |

### 6.2 Git history

The history of this repository contains editorial content, Studio commit messages with post paths (`studio: update content/collections/posts/…`), the private CV, and old versions of files with personal data. The platform starts with a fresh history. An initial commit will import the already cleaned directory (see phase 3), with a note in the `README` indicating that the project was extracted from a personal website. Preserving history with `git filter-repo` is only worthwhile if the owner insists, and it would require auditing every commit. The plan does not depend on it.

### 6.3 Privacy gates on public CI

The `test-no-personal-data` gate fails the build if it finds any term from a blocklist maintained outside the public repository (a CI secret with name, email, domain, IDs), plus generic patterns (emails that are not `@example.com`, `pub-[0-9a-f]{32}.r2.dev`, `pk_live_`, `sk_`, `github_pat_`).

Gitleaks runs on every push and pull request.

The `test-examples-fictional` gate ensures all example content uses a fictional persona and `example.com` or `example.org` domains.

### 6.4 CV in the public repository

The `cv` template is public. It displays a list of jobs, products, skills, languages, education, and contacts, all generated from data. The example uses an invented persona. The files `cv-print.html`, the `cv-print-*` includes, `_private/`, `_config_private.yml`, `scripts/cv/`, and the `generate-private-cv.yml` workflow remain outside the platform. The platform does not offer a private build. It only documents that the export respects the field list of the contract, which leaves the website free to keep any private fields it wants in its own repository.

### 6.5 Documentation

Documentation is written in English in the public repository.

```text
README.md                 # what it is, screenshot, quickstart in 5 commands
docs/
├── getting-started.md    # from zero to local site with the minimal example
├── configuration.md      # complete reference for `pandorga:` (generated from registry schema)
├── pages-and-templates.md
├── templates/<name>.md   # one per template: contract, fields, screenshots, home band
├── content-model.md      # collections, keys, Git chronology, license
├── includes.md           # figure, xcite, plotly, etc. (currently docs/content/elements.md)
├── studio.md             # Clerk, PAT, allowlist, composed schema
├── deploy/cloudflare.md  # Pages + R2 + watch paths (currently docs/ops/cloudflare.md)
├── deploy/static.md      # `static` backend, without R2
├── theming.md            # tokens, themes, DESIGN.md
├── extending.md          # extension points, local templates
├── architecture.md
└── upgrading.md          # release notes
CONTRIBUTING.md, CHANGELOG.md, SECURITY.md, CODE_OF_CONDUCT.md, LICENSE
```

The file `configuration.md` is generated from the registry schema. A gate checks that it is updated, ensuring the reference does not diverge from the code.

### 6.6 Examples

| Example | Content | Backend |
|---|---|---|
| `examples/minimal` | One `articles` page, two articles, no Studio | `static` |
| `examples/full` | The seven templates, fictional persona, configurable Studio | `static` by default, `r2` documented |

The `static` backend (JSON generated in `_site/_content_json/` and served from the same origin) already exists in embryonic form in `content_local_serve.rb`. Making it a first-class backend is what allows an example to run with `bundle exec pandorga serve` and be published as a demo on any static host. The platform CI builds both examples and runs the gates against them. The `examples/full` directory is published as a demonstration site on every release.

## 7. Remaining content in the website repository

```text
website/
├── _config.yml              # identity, content, studio, pages (the registry)
├── Gemfile                  # gem "pandorga", tag: …
├── content/                 # unchanged
├── studies/                 # unchanged
├── _includes/page/hero-pandorga.html
├── _data/themes/, translations.yml   # only if they diverge from default
├── assets/icons/, assets/images/, favicon.ico
├── assets/css/site/         # local adjustments, if any
├── pages/license/
├── _redirects               # only legacy slugs and content-key block
├── cv-private/              # cv-print.html, cv-print-* includes, _private/, _config_private.yml, scripts/cv/
├── studio.overrides.yml     # optional
├── docs/                    # editorial, taxonomy, ops with real IDs, specs for this site
├── scripts/test/            # content and private CV gates (§8)
└── .github/workflows/       # call reusable workflows + private CV + guidelines
```

The files `AGENTS.md`, `README.md`, and `CONTRIBUTING.md` of the website shrink to cover only website concerns, pointing to the platform documentation for everything else.

## 8. Gates

The 35 gates in `scripts/test/` are divided into two groups.

Platform gates run against template fixtures and examples. They include `absent-field-absent-element`, `cdn-pins`, `content-detail-urls`, `content-keys`, `content-license`, `content-render-parity`, `content-validators`, `css-structure`, `detail-render-parity`, `dev-reexport`, `export-content-json-incremental`, `exported-fields-reach-the-view`, `form-control-theming`, `git-chronology`, `hero-portraits`, `home-band-art`, `language-export`, `listing-filter-contract`, `math-row-breaks`, `public-cv-export`, `r2-config-consistency`, `r2-json-sync`, `runtime-js-syntax`, `slim-writing-index`, `studio-*`, `text-excerpt`, `unwrap-media-src`, `withdrawn-content-export`, `writing-index-export-slugs`, `writing-slug-limits`, `xcite-chronology`, and `cloudflare-watch-paths-doc`. New platform gates will cover the page registry, navigation, homepage, routes generation, composed Studio schema, privacy, fictional examples, and updated configuration documentation.

Website gates run against real content using the gem validators. They include `content-validators` and `bibliography-usage` on `content/`, `franco-brazilian-marriage`, `favicon`, `r2-content-origin`, `guidelines-export`, `guidelines-pipeline-paths`, and `visual-inspection-pages`. A new gate will verify that the private CV does not leak into the public export.

The `validate.sh` script continues to exist in both repositories, each running its respective gates.

## 9. Phases

Each phase ends with `mise exec -- ./scripts/validate.sh` turning green and the website in production showing no visible changes, except where noted. Phases 1 to 3 happen inside this repository, because the real content and the gates that prove nothing broke are located here. Only phase 4 creates the public repository.

### Phase 0. Spikes and decisions

- `PLT-0.1` Check if Cloudflare Pages installs a gem from a Git source during build.
- `PLT-0.2` Check if Functions can be loaded from the gem (Option A from §5.1) or implement fallback B.
- `PLT-0.3` Verify the single gem working as theme, plugin, and CLI in Jekyll 4.3.
- `PLT-0.4` Verify name availability on GitHub, RubyGems, and npm.
- `PLT-0.5` Address owner decisions from §13.

Output requirements are short notes in this file documenting the result of each spike.

### Phase 1. Desensitize in place

Apply everything from §6.1 while remaining in this repository. Identity is read from configuration, CORS uses an explicit list, `GITHUB_REPO` loses its default value, Android tests use `example.com`, and tag vocabulary moves to `_config.yml`. Introduce `test-no-personal-data` restricted to the paths that will become the platform.

The risk is low because it only changes where the data lives. Output requirements state that the gate passes on platform paths.

### Phase 2. Page registry in place

This is the most invasive phase. It introduces `pandorga.pages` and the generator. It removes `pages/*/index.html` (except `license`), `_data/nav.yml`, and the fixed homepage bands. The exporter, adapter, timeline, and Studio schema update to read the registry. Inline layout code migrates to template modules registered in the runtime.

Parity proof requires side-by-side comparisons of `visual-inspection` captures for all pages before and after the change. The exported JSON must be identical byte-for-byte (`diff -r` of `_content_json/` before and after). The generated `_redirects` file must be equivalent to the current one. Suggested sub-PRs in order are registry and validation, generated pages and navigation, generated routes, exporter, homepage, Studio, and modularized templates one by one.

### Phase 3. Internal boundary

Move everything that is platform code to `vendor/pandorga/` as a local gem loaded via `path:` in the `Gemfile`, mimicking the final structure of the gem. The repository root is left only with website content (§7). The privacy gate expands to cover the entire `vendor/pandorga/` directory. Platform gates switch to running against fixtures rather than `content/`.

Output requirements state that `vendor/pandorga/` must build on its own. This is verified by copying the directory to an empty checkout and running the examples.

### Phase 4. Extraction and polish

Create the public repository with a fresh history starting from `vendor/pandorga/`. Write the documentation outlined in §6.5, the examples in §6.6, `CHANGELOG`, `SECURITY.md`, CI configuration (gates, gitleaks, privacy, example builds, Studio build), reusable workflows, and the `v1.0.0` release. Publish the demo site.

Output requirements state that a person without access to the `website` repository can follow `getting-started.md` and successfully run the minimal example locally.

### Phase 5. The cut in the website repository

Replace the `path:` directive with `github:, tag: v1.0.0`. Remove the `vendor/pandorga/` directory. Website workflows update to call the reusable workflows. Adjust the build command in Cloudflare Pages if Option A from §5.1 is successful. Update `AGENTS.md`, `README.md`, and `CONTRIBUTING.md`. Dependabot begins monitoring the gem.

Output requirements state that production is served by the pinned version, and all current public URLs respond identically (`PLT-AC-9`).

### Phase 6. After the cut

Introduce a generic Android Studio application. Publish the gem on RubyGems. Implement `pandorga new` as a site generator based on the minimal example. Define criteria for `v1.0`, ensuring the registry and template APIs remain stable for two minor versions.

## 10. Versioning and cross-repository flow

- Semantic Versioning is used. Changing a template contract, the registry schema, or the exported JSON format constitutes a major change (or a minor change with a deprecation warning while in the `0.x` series).
- The JSON format in R2 gains a `schema_version` attribute in `manifest.json`. The runtime refuses unknown versions with a clear message instead of rendering incorrectly.
- Fixes originating from an issue in this website follow a strict flow. A pull request is made in the platform with a test against a fixture, followed by a release, and then an update pull request in the website. The installed gem must never be edited directly.
- Studio commits continue to merge directly into the `main` branch of the `website` repository. The platform does not receive automatic commits.

## 11. Risks

| Risk | Mitigation |
|---|---|
| Functions cannot be loaded from the gem | Fallback B from §5.1 with a version gate |
| Visual parity breaks in phase 2 | Before and after captures per page. Small sub-PRs. Identical JSON acts as objective proof |
| Published content depends on include names | Includes stay in the root of `_includes/` within the gem, keeping identical names |
| R2 serves old JSON to a new shell (or vice versa) during the cut | `schema_version` in the manifest. Publish content before the shell |
| Personal data leaks during extraction | Fresh history. Privacy gate with an external blocklist. Gitleaks. Manual review of the first commit |
| Monolithic runtime becomes hard to extend | Template registration in the runtime. The core remains unified, only templates are modules |
| Two maintenance sources delay fixes | Use `bundle config local.pandorga` to work on both simultaneously |
| Cloudflare watch paths change meaning | Review `docs/ops/cloudflare.md` in phase 5. Gem updates change `Gemfile.lock`, which must trigger a build |

## 12. Acceptance criteria

Criteria are written in EARS format. Every criterion is referenced by at least one gate.

- `PLT-AC-1` When the `pandorga` CI runs, the system must fail if any file contains the name, email, domain, bucket ID, Clerk ID, or repository of the owner (verified by `test-no-personal-data` and gitleaks).
- `PLT-AC-2` The `pandorga` history must not contain any commits from this repository.
- `PLT-AC-3` When a page is added to the registry without any other edits, the system must include it in the navigation, homepage, detail routes, export pipeline, and Studio schema. When it is removed, the system must exclude it from all these places.
- `PLT-AC-4` The system must offer the templates `cv`, `articles`, `blog`, `media`, `network`, `bibliography`, and `portfolio`, each with a `README`, fixtures, and a screenshot. When the registry instantiates the same template twice with different collections, the system must generate two independent pages.
- `PLT-AC-5` When the registry has a duplicate key, unknown template, non-existent collection, or conflicting route, the build must fail with a message indicating the entry and the problem.
- `PLT-AC-6` When someone without a Cloudflare account follows `getting-started.md`, `examples/minimal` and `examples/full` must run locally with the `static` backend.
- `PLT-AC-7` When a `cv` template collection contains fields outside the contract list, the export must not publish them.
- `PLT-AC-8` After the cut, the `website` repository must not contain layouts, runtime files, plugins, exporters, or Studio source code. All of these must come from the gem version pinned in `Gemfile.lock`.
- `PLT-AC-9` After the cut, every current public URL of the `website` (pages, details, legacy redirects, `/studio/`, `/media/*`) must respond with the same status and identical content as before.
- `PLT-AC-10` When the private CV workflow runs in the `website` repository, it must generate PDFs exactly as it does today. None of its files must exist in `pandorga`.
- `PLT-AC-11` When the registry schema changes without `docs/configuration.md` being regenerated, the `pandorga` CI must fail.
- `PLT-AC-12` When the runtime receives a `manifest.json` with an unknown `schema_version`, it must display an explicit error instead of attempting to render.

## 13. Owner decisions

1. The name will be `pandorga` or one of the alternatives from §1.
2. The platform MIT copyright holder must be decided. It could be a proper name, which is personal data in a public repository, or a generic placeholder like "The Pandorga contributors".
3. The account location must be chosen. The repository can sit in a personal account or an organization created for the project. An organization keeps the repository URL free of a proper name.
4. The default theme needs definition. The current Architectural Ledger can become the public theme, or the website can maintain its own variation while the platform provides a more neutral theme.
5. Drafts and Sources in documentation need confirmation. The templates are named `blog` and `media`, but this website continues to call the pages Drafts and Sources, and the URLs (`/pages/blog/`, `/pages/sources/`) will not change.
6. The Android Studio inclusion must be scheduled. It will either enter in version 0.1 or wait for phase 6.
7. The fresh history approach described in §6.2 requires confirmation.