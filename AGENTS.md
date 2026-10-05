# AGENTS.md

This file provides guidance to AI coding agents (Antigravity, Gemini, and other agents) when working with code in this repository.

@.guidelines/workflow/sdd.md
@.guidelines/workflow/integration.md
@.guidelines/workflow/tdd.md
@.guidelines/agents/writing.md
@.guidelines/agents/article.md
@.guidelines/style/naming.md
@.guidelines/languages/rb.md
@.guidelines/languages/js.md
@.guidelines/languages/sh.md

Read [CONTRIBUTING.md](CONTRIBUTING.md) for this site's own development
lifecycle, engineering standards, and CI gates. For content writing
(posts, articles, site copy), also read
[docs/editorial/writing-for-agents.md](docs/editorial/writing-for-agents.md)
for this site's specific voice mechanics on top of the shared writing and
article guidelines above. For architecture, read [README.md](README.md).

For visual design — the palette, type scale, spacing, component shapes, and
the light/dark token contract — read [DESIGN.md](DESIGN.md). It describes the
site as currently built, including its known inconsistencies.

## Quick reference: Common tasks

| Task | Command |
|---|---|
| Run all gates before push | `mise exec -- ./scripts/validate.sh` |
| Studio Android shell tests | `cd studio-mobile && npm test` |
| Local dev server (full, JSON + details) | `./scripts/dev-serve.sh` |
| Run one gate | `mise exec -- ruby scripts/test/test-<name>.rb` |
| Shell-only server (no JSON export) | `mise exec -- bundle exec jekyll serve --unpublished` |
| Build CV PDFs | `./scripts/cv/generate-cv-pdf.sh` |
| Create shareable PDF from editorial file | `./scripts/pdf/md-to-pdf.sh -i content/collections/articles/<slug>.md -o /tmp/<slug>.pdf` |
| Format Python code | `./scripts/format-python.sh` |

## Architecture at a glance

Three layers:

1. **Static shell** — Jekyll layouts, nav, CSS, client-side JS. Built once per shell/asset change. Outputs `_site/`.
2. **Editorial content** — Markdown/YAML under `content/collections/`. Exported to JSON (via `export-content-json.rb`), uploaded to Cloudflare R2, fetched by browser at runtime.
3. **Client-side rendering** — `_includes/content-runtime/` (43 Liquid fragments, numbered and concatenated). Fetches JSON, renders Markdown with marked.js, resolves includes, runs MathJax/Mermaid.

Collections:
- `articles/` — English, long-form, tagged (Aesthetics, AI, Data, DevOps, Mathematics, Robotics, Social)
- `posts/` — Portuguese, dated blog (Rascunhos), tagged (arte, brasilidade, carme, devaneio, … — see [docs/content/taxonomy.md](docs/content/taxonomy.md))
- `products/` — CV portfolio items (body via `body_public`)
- `projects/` — Personal projects (portfolio gallery)
- `jobs/` — CV entries (body_public / body_extended / body_single_page)
- `resources/` — Source cards (Sources page)

At runtime, pages like `/articles/<slug>/` are clean URLs, **not** built by Jekyll. Cloudflare `_redirects` serves the listing layout with the slug in the pathname. The client-side runtime reads the pathname, fetches `collections/articles/<slug>.json` from R2 (or locally from `_content_json/` in dev), and renders it.

## Environment notes

Verified 2026-09-13 on this machine (WSL `ubuntu`, repo at `~/Workspace/website`).

- **Ruby runs through `mise`, not the system.** `mise` is installed
  (`/snap/bin/mise`) and provides the 3.4.4 pinned by `.mise.toml` /
  `.ruby-version`. System Ruby is 3.2.3, which *fails* the Gemfile's
  `ruby "~> 3.3.0"` guard, so a bare `bundle exec` dies on the Gemfile, not on
  your code. Prefix everything: `mise exec -- bundle exec …`. Gems are already
  installed under mise's Ruby — there is no `vendor/bundle` and no
  `.bundle/config` anywhere in this repo, in any worktree.
- **Gate count: 35 tests.** `mise exec -- ./scripts/validate.sh` runs the public Jekyll build, then the full test suite, then Python formatters. It passes end-to-end after worktree setup. Expected non-fatal output: `Timeline: Product '…' … clipped` and `Skipping Franco-Brazilian marriage output check (missing cache: …)`.
- **Run a single gate.** Each `scripts/test/test-*.rb` is standalone and self-reporting:
  ```bash
  mise exec -- ruby scripts/test/test-<name>.rb
  ```
  This is fast for iteration (no full rebuild). Examples: `test-content-validators.rb`, `test-content-render-parity.rb`, `test-detail-render-parity.rb`. Run the full `./scripts/validate.sh` before pushing.
- **Node (24.21.0) and Python formatters are local-only.** Node lives at `~/.local/lib/node-v24.21.0-linux-x64` with symlinks in `~/.local/bin`. Black is `/usr/bin/black`, isort is `~/.local/bin/isort`. Ensure `~/.local/bin` is on `$PATH` — on WSL, `npm` otherwise resolves to Windows `/mnt/c/Program Files/nodejs/`, whose shebang breaks Node scripts.

### Setting up a fresh worktree

A worktree created from the Windows side needs four fixes before anything runs.
Every round of parallel agents has lost time rediscovering these one at a time.

1. **Restore the exec bit.** The Windows-side checkout writes every script
   `-rw-r--r--`, so `./scripts/validate.sh` fails with `Permission denied`.
   `chmod +x scripts/*.sh scripts/*/*.sh` — `core.fileMode` is `false`, so this
   does not dirty `git status`.
2. **Link the Node deps.** They exist only in the main checkout:
   `ln -sfn ~/Workspace/website/scripts/node_modules scripts/node_modules`.
   The `.gitignore` entry is `scripts/node_modules/` with a trailing slash, which
   does not match a symlink — it shows up as untracked; do not commit it.
3. **Populate `.guidelines/` by copy, not by clone.** The nine `@.guidelines/…`
   imports at the top of this file resolve to nothing when it is uninitialised.
   `git submodule update --init` cannot work here: the remote is SSH and only
   WSL holds the key, while WSL-side git cannot read the worktree at all (see
   below). Copy it from the main checkout and repoint the gitlink, which `cp`
   would otherwise leave dangling:

   ```bash
   cp -a ~/Workspace/website/.guidelines/. .guidelines/
   echo 'gitdir: //wsl.localhost/ubuntu/home/alexandre/Workspace/website/.git/modules/.guidelines' > .guidelines/.git
   ```

   Verify with `git submodule status`: a leading `-` means still uninitialised,
   and a dangling gitlink breaks `git status` outright with
   `fatal: not a git repository: .guidelines/../.git/modules/.guidelines`.
4. **Know which side of WSL each command runs on.** The `.git` file holds a UNC path, so `git` inside WSL fails with "not a git repository." Run git from Windows (Bash/PowerShell tools) with `-c safe.directory='*'`. Run builds, tests, mise, and `jekyll serve` inside WSL. For remote operations (fetch/push), drive from WSL with explicit gitdir: `git --git-dir=$HOME/Workspace/website/.git --work-tree=. push …` (the key is in WSL only).

## Development workflow

### Content-only edits

When you edit only `content/collections/` or `content/pages/` (Markdown and YAML), **do not** start a browser dev server for every change. The export + JSON render path is a separate contract:

1. Make your edits.
2. Run gates to verify export contract and content metadata: `mise exec -- ruby scripts/test/test-content-validators.rb && mise exec -- ruby scripts/content/export-content-json.rb content _content_json` — this confirms the editorial JSON export works.
3. If you need to verify the page renders, use `./scripts/dev-serve.sh` once at the end (exports JSON, serves with detail-URL rewrites).

Content-only changes are fast because they skip the shell rebuild.

### Shell, layout, or JS edits

When you touch `_layouts/`, `_includes/`, `assets/`, or `_plugins/`:

1. Start the dev server: `./scripts/dev-serve.sh`. This watches `content/` and re-exports as you edit articles, plus rebuilds the shell on every change.
2. Open `http://localhost:4000` and test your changes.
3. Run `mise exec -- ./scripts/validate.sh` before push to catch any gate failures.

### Running a single gate

Tests are standalone and fast. To debug a specific gate:

```bash
mise exec -- ruby scripts/test/test-<name>.rb
```

Each reports its own pass/fail. Examples: `test-content-validators.rb`, `test-content-render-parity.rb`, `test-detail-render-parity.rb`.

## Code architecture

### Runtime rendering (`_includes/content-runtime/`)

Articles and posts (and listing pages) are rendered in the browser. The runtime:

1. Loads `manifest.json` (collection index).
2. Fetches the detail JSON (`collections/articles/<slug>.json`, etc.).
3. Renders Markdown with marked.js, resolves `{% include %}` markers, runs MathJax/Mermaid if enabled.
4. Mounts the HTML into the page.

The 43 numbered Liquid fragments are concatenated in order at build time. **Do not split this file** — it is one monolithic module, not a collection of separate concerns. Ordering matters for dependencies.

### Shared block library (`_includes/content-runtime/43-blocks.html`)

Every card, row, chip, and CTA on a client-rendered page uses functions from `43-blocks.html`. Renders nothing when the field is absent. Key functions:

- `renderArchiveCard(item, opts)` — vertical grid card (articles, posts)
- `renderLedgerRow(item, opts)` — dense horizontal entry (writing archive, rascunhos)
- `renderSystemCard(item, opts)` — project card with media and links
- `renderTagChips(tags, {hrefFor, limit})` — tag pills
- `renderMetaStrip([parts], {className})` — date + language ledger line
- `renderCtaLink(href, label)` — directional link

If a second page needs a card, it belongs in `43-blocks.html`, not in a private renderer. Pages used to grow their own copies — which is why the same card drifted between home and the writing index.

### CSS organization

- `assets/css/base.css` — shared component rules (Tailwind utilities + custom rules for cards, sidebars, etc.)
- `assets/css/article.css` — article/post detail styles
- `assets/css/ledger/<page>.css` — one-page-specific rules (home, cv, projects, etc.)

The shell loads every `.css` file in `assets/css/ledger/` automatically, so a new page needs a new CSS file and nothing else.

**Token rule:** use design tokens, never hardcoded hex. The site runs two complete palettes (`data-theme`), and a hardcoded colour breaks one of them.

### Liquid includes (editorial)

Keep includes at the root of `_includes/` (not nested) because their names appear in published Markdown, in Studio block patterns, and in the PDF export script. Moving one breaks content.

Key includes:
- `figure.html` — image with optional lightbox and caption
- `youtube.html`, `video.html` — embeds
- `xcite.html` — BibTeX citation
- `plotly.html` — interactive charts

### Ruby plugins (`_plugins/`)

Run at build time (hooks registered with `:site, :post_read`):

- `timeline.rb` — builds CV timeline metadata
- `git_metadata.rb` — applies the chronology from `git_chronology.rb` to articles/posts. `date` is the editorial date (front matter `date`, else the `YYYY-MM-DD` filename prefix, else the first Git add); `last_updated` is always the latest commit that changed the markdown body. **Do not set `last_updated` in front matter** — it is overwritten at build time.
- `content_validators.rb`, `resource_validator.rb` — fail the build on hard validation errors
- `job_sections.rb` — organizes CV job entries

Fail the build on validation errors. Log warnings for soft issues.

### Python scripts (`studies/*/scripts/`, `scripts/pdf/`, `scripts/visual/`)

Python is optional and on-demand only — never in CI, only for editorial data work or visual inspection:

- `studies/<slug>/scripts/` — data ingestion and Plotly chart generation, next to the data they read (feeds articles); see [studies/README.md](studies/README.md)
- `scripts/pdf/` — Markdown → PDF export (shareable links from articles)
- `scripts/visual/` — screenshot runner for design inspection
- `render-favicon.py` — rasterizes `assets/icons/favicon.svg`

When you add a script, put it in its study and record the consumer in that study's `README.md` (example: `mcmc_*.py` → `2026-03-02-mcmc.md`). Every study obeys three rules: reproducible, auditable, re-runnable.

## Constraints and rules

### Field-backed rendering

**An element renders only when a field backing it already exists and is populated.** Absent field → absent element. No placeholders, em dashes, or invented data.

This is architectural: the design comp shows shape, not licence to invent. Do not add counters, reading times, status pills, or metrics with nothing beNewsreader them. If the design needs something the content model lacks, add a front-matter field, backfill it, then render.

### No Node build for the public site

The site runs Tailwind CDN, not a Node/webpack pipeline. Do not introduce a build step without explicit spec and sign-off — it changes the deploy model for everyone. Node is allowed in `scripts/` only (CV PDFs, screenshots, visual inspection).

### No bundler for site JavaScript

Vanilla JS or D3 (already loaded). Inline `<script>` tags or module-like patterns in layouts. Client-side behavior must degrade if JS fails; content stays readable.

### Rebase-merge only

History is linear. Studio commits straight to `main` (simple workflow). Branches: feature names like `timeline`, `feature/<name>`. Sync to current `main` tip before branching (see [.guidelines/workflow/branching.md](.guidelines/workflow/branching.md)).

### Content dating

Two fields, two different rules (`_plugins/git_chronology.rb`, documented in
[docs/content/architecture.md](docs/content/architecture.md#content-chronology)):

- `date` is the **editorial** publication date, and front matter wins. The resolution order is front matter `date`, then the `YYYY-MM-DD` filename prefix, then the first Git add for undated legacy names. Setting it in front matter is normal and supported; every dated filename in `content/collections/` already pins it implicitly.
- `last_updated` is **always derived from Git**, from the latest commit whose markdown body (everything after the closing `---`) changed. Front-matter-only edits do not advance it. **Never set `last_updated` in front matter** — the build overwrites whatever you put there.

So: edit the body and commit, and the "updated" date follows on its own. Reach for a front-matter `date` only when the editorial date differs from the filename prefix.

### URLs are non-obvious

- Top-level pages: `/pages/<name>/` (CV is `/pages/cv/`, not `/cv/`)
- Articles: `/articles/<slug>/`, listed at `/pages/articles/`
- Rascunhos (posts): `/posts/<slug>/`, listed at `/pages/blog/` (nav label: Rascunhos)
- Projects: `/projects/<slug>/`, listed at `/pages/projects/`
- Legacy fallback (query params): `?article=<slug>`, `?post=<slug>`

Clean URLs are served via Cloudflare `_redirects` (HTTP 200) pointing to listing layouts. The runtime reads the slug from the pathname and loads JSON.

## Before starting work

1. Read [README.md](README.md) — architecture, collections, build flow, CLI reference.
2. Read [CONTRIBUTING.md](CONTRIBUTING.md) — workflow, gates, CI, agent rules.
3. Sync `main` and branch from it (see [.guidelines/workflow/branching.md](.guidelines/workflow/branching.md)).
4. Read the feature spec in `docs/` if the task is spec-driven.
5. For content tasks (articles, posts, pages), read [.guidelines/agents/writing.md](.guidelines/agents/writing.md), [.guidelines/agents/article.md](.guidelines/agents/article.md), and [docs/editorial/writing-for-agents.md](docs/editorial/writing-for-agents.md).
6. Skills available in `.agents/skills/`:
   - When drafting or substantially rewriting an article or a rascunho, use the [writing-arc](.agents/skills/writing-arc/SKILL.md) skill: author supplies the arc, agent researches, drafts once, dissects paragraph by paragraph, then redrafts with point of view corrected. Do not skip straight to a polished draft on a substantial piece.
   - When writing or rewriting a project or product page (`content/collections/projects/`, `content/collections/products/`), use the [project-page](.agents/skills/project-page/SKILL.md) skill instead: a fixed questionnaire fixes point of view and positioning before any structure or prose exists.
   - When reviewing drafts or revisions for prose authenticity, run the [ai-slop-review](.agents/skills/ai-slop-review/SKILL.md) skill to eliminate model cadence, formulaic summaries, and generic praise.

Before every push:

```bash
mise exec -- ./scripts/validate.sh
```

Do not merge PRs yourself — the owner approves and merges. The full V-cycle (spec, architecture, implementation, verification, review, merge) is in [CONTRIBUTING.md](CONTRIBUTING.md).
