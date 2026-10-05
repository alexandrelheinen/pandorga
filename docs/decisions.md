# Decisions

ADR-style log for constraints that diverge from or freeze choices in
[spec.md](spec.md). Newest first.

## ADR-003: Object-store env names for v1

Date: 2026-10-05  
Status: accepted  
Refs: `PLT` deploy, [spec.md §5.2](spec.md)

`pandorga publish` accepts `S3_*` credentials for any S3-compatible bucket.
Legacy `R2_*` names remain aliases. `pandorga.content.backend` values `r2`,
`object_store`, and `s3` all mean “JSON at `base_url`”; `static` serves from
`_site`.

## ADR-001: Freeze §13 owner decisions for v0.1

Date: 2026-10-05  
Status: accepted  
Refs: `PLT-0.5`, [spec.md §13](spec.md)

| Decision | Choice | Why |
|---|---|---|
| Repository / gem name | `pandorga` | Spec proposal; free on RubyGems and npm (`PLT-0.4`) |
| MIT copyright holder | The Pandorga contributors | Avoids a proper name in the public LICENSE |
| GitHub home | `alexandrelheinen/pandorga` | Repo already exists; org move can wait for v1 |
| Default theme | Architectural Ledger | Matches the first consumer; sites may override via `_data/themes/` |
| Template keys vs site labels | Templates `blog` / `media`; site copy Drafts / Sources in `headers.yml` | URLs stay stable (`PLT-AC-9`) |
| Android Studio | Shipped in 1.2 (`studio-mobile/`, git only) | Kept out of the gem; identity via EAS/env |
| Git history | Fresh orphan at extraction (§6.2) | Personal commits must not enter the public repo (`PLT-AC-2`) |
| Pages Functions | Option A (`pandorga install-functions`) | Preferred in §5.1; spike `PLT-0.2` proves local copy |

## ADR-002: Phase 0 spike results

Date: 2026-10-05  
Status: accepted  
Refs: `PLT-0.1` … `PLT-0.4`

### PLT-0.1 — Cloudflare Pages installs a Git-source gem

Cloudflare Pages runs `bundle install` from the project `Gemfile` before the
build command. Git sources (`gem "pandorga", github: "…", tag: "v0.x"`) are
supported by Bundler on Pages the same way as locally; no vendor cache is
required. Confirmed against Pages v3 Ruby 3.4.4 docs and prior site builds that
already use Bundler. Full end-to-end proof lands at Phase 5 cutover when the
site pins `github:, tag: v1.0.0`.

### PLT-0.2 — Functions from the gem (Option A)

`pandorga install-functions` copies `functions/` and compiled `studio/` from
the gem install path into the site root. Local spike: CLI copies fixture
trees; a gate asserts the destination matches the gem version stamp. Cloudflare
compiles Functions from the project root after the build command runs the
copy — nothing vendored in site Git.

### PLT-0.3 — Theme + plugin + CLI in one gem

Skeleton gemspec ships `_layouts/`, registers via `plugins: [pandorga]`, and
exposes `exe/pandorga`. `bundle exec pandorga doctor` exits 0 against
`examples/minimal`.

### PLT-0.4 — Name availability

| Registry | Result (2026-10-05) |
|---|---|
| RubyGems `pandorga` | Not found (available) |
| npm `pandorga` | Not found (available) |
| GitHub `alexandrelheinen/pandorga` | Exists (this repository) |
