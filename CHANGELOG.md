# Changelog

## [1.2.0] — 2026-10-05

### Added

- Optional Expo Android Studio shell under `studio-mobile/` (git only; excluded from the gem)
- Env/EAS identity: `STUDIO_WEB_APP_URL`, `STUDIO_ANDROID_PACKAGE` / `ANDROID_PACKAGE`, `STUDIO_APP_NAME`, `EAS_PROJECT_ID` (example.com defaults)
- Docs: [docs/studio-android.md](docs/studio-android.md); CI workflow `studio-mobile.yml` (`npm ci && npm test`)

### Changed

- `pandorga new` pins `gem "pandorga", "~> 1.2"`

## [1.1.0] — 2026-10-05

### Added

- `pandorga new PATH` scaffolds a site from `examples/minimal` (`gem "pandorga", "~> 1.1"`)
- Listing runtimes read collection, listing path, and detail pattern from the registry page slot (dual template instances)

### Changed

- Generator injects `collection`, `listing_path`, `detail`, and `template` on listing pages
- Pinning docs prefer the RubyGems form when the gem is published

## [1.0.0] — 2026-10-05

### Added

- Configurable hero art via `pandorga.home.hero_art` (default `page/hero-default.html`)
- Registry-driven homepage bands (`site.data.pandorga_home_bands`)
- `pandorga.content.backend` (`static` | `r2` | `object_store` | `s3`) wired to the runtime
- S3-compatible publish (`S3_*` env aliases, `pandorga publish` → object-store sync)
- Template layout selection from the registry (`cv`, `articles`, `blog`, …)
- `studio.yml` for all seven templates; `pandorga studio-schema` composes Studio from the registry
- Template packages with README, fixtures, and screenshot placeholders (`PLT-AC-4`)
- Registry schema + generated `docs/configuration.md` (`PLT-AC-11`)
- CV public-export allowlist gate (`PLT-AC-7`)
- Gitleaks job in CI (`PLT-AC-1`)
- Deploy notes for Netlify and GitHub Pages (shell + static backend)
- Docs: architecture, pages-and-templates, theming, extending, upgrading
- Fictional content for `examples/full`

### Changed

- Home layout no longer hardcodes Portuguese CTAs or website kite art
- Blog listing UI uses English platform defaults and identity locale
- Export / content adapter / collections prefer `PandorgaRegistry` over fixed lists
- Docs drop v0.1.0-only deploy wording; Cloudflare doc notes host-agnostic shell

## [0.2.0] — 2026-10-05

### Added

- Full theme extract: `_layouts`, `_includes` (content-runtime), `_data`, assets
- Jekyll plugins migrated under `_plugins` / `lib/pandorga/jekyll/plugins`
- Content export pipeline, Studio build + Functions, `studio-app` source
- CLI `export` / `serve` delegate to the real pipeline (`PANDORGA_SITE_ROOT`)

## [0.1.0] — 2026-10-05

### Added

- Gem skeleton: page-registry generator, CLI stubs, examples, docs, CI
- ADR freeze for §13 owner decisions (`docs/decisions.md`)
