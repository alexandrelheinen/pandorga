# Changelog

## [1.3.25] — 2026-10-06

### Changed

- Drop the Media library disclaimer under the title

## [1.3.24] — 2026-10-06

### Fixed

- Studio top-bar tools share one height again: a later `height: 100%` rule on
  direct `.btn-tool` children was overriding the fixed size and growing
  Revert/Save/Export to the brand line while Theme stayed shorter

## [1.3.23] — 2026-10-06

### Changed

- Media library rows use bordered Copy and Delete icon buttons; delete confirms
  then commits removal via the existing Studio file DELETE API

## [1.3.11] — 2026-10-06

### Fixed

- Studio SPA rebuild embeds the real Clerk Frontend API host again (was baking
  `clerk.example.com` into `studio/`); Vite refuses placeholder publishable keys

## [1.3.10] — 2026-10-06

### Fixed

- Home specimen height is measured from the tallest project and locked, so
  swapping projects no longer resizes the bench or the inventory; taglines
  and wrapping chips still fit without clipping

## [1.3.9] — 2026-10-06

### Changed

- Studio header uses a compact icon toolbar with a light / dark / system theme
  menu; mobile collections toggle matches the public site menu icon
- Left collections aside stays visible from 961px; navigation groups list
  References before Portfolio
- Expo launcher icons split `assets/studio/` (hex mark) vs `assets/website/`
  (square site logo); hex frame is stroke-only with no gray fill plate

## [1.3.8] — 2026-10-06

### Fixed

- Home specimen grows with its tagline and wrapping tag chips instead of
  clipping under a fixed height; pills stay one line (row wraps whole chips)
- Specimen strip above the plate uses the projects label chrome at a larger
  step so it matches the featured scale

## [1.3.7] — 2026-10-06

### Added

- Home projects band specimen bench: project specimen, rack card, and tape
  blocks, with inventory rows and glyph/initial fallbacks when an icon is
  missing

### Fixed

- Specimen stays half-width and 16:9; title always sits below the plate with
  roomier copy and links; drafting tape removed from the home layout

## [1.3.6] — 2026-10-05

### Fixed

- Home specimen is taller so project tags are not clipped, with more space
  between the poster and the project title

## [1.3.5] — 2026-10-05

### Fixed

- Home specimen height is CSS-fixed (no ResizeObserver jump when switching
  projects); mobile icon strip always reserves six compact slots; desktop
  inventory sits in a panel over the tiled band

## [1.3.4] — 2026-10-05

### Fixed

- Home portfolio mobile inventory is a single row of project-icon buttons
  (desktop index styles no longer override the phone layout)

## [1.3.3] — 2026-10-05

### Changed

- Home portfolio inventory is an index folio (number, thumb, title, project
  icon) with a borderless specimen; drafting marks stay on the poster only
- Specimen meta shows project tags instead of label/status
- Mobile selector strip and session-sticky random specimen pick from 1.3.2
  polish remain

## [1.3.2] — 2026-10-05

### Fixed

- Home inventory rows are selectable, height-synced to the specimen, and keep
  16:9 thumbs flush in flex media shells
- Studio list surfaces use the themed panel background

## [1.3.1] — 2026-10-05

### Changed

- Home portfolio band is a specimen + inventory bench (16:9 media) instead of
  an equal card grid
- Projects listing lead shows a Featured chip

## [1.3.0] — 2026-10-05

### Fixed

- Object-store publish fails fast when `PANDORGA_SITE_ROOT` is unset and the
  script runs from the pandorga gem (no more silent skip of `content/media`)
- `pandorga publish` exports `PANDORGA_SITE_ROOT` even when delegating to a
  site-local `publish-content-to-r2.sh` wrapper

## [1.2.4] — 2026-10-05

### Fixed

- An omitted `pandorga.content.backend` keeps a configured `base_url` or legacy `content_api_base_url` as an object-store origin. `static` remains the default only when no public URL is set, and an explicit `backend: static` still wins.

## [1.2.3] — 2026-10-05

### Changed

- Home portfolio cards use a denser equal grid (projects listing layout untouched)
- Corrects the 1.2.2 mis-target that compacted the projects index instead of the home band

## [1.2.2] — 2026-10-05

### Added

- Blog listing chrome follows `pages[].language` (`en` default; `pt-BR` for Portuguese UI strings)

### Changed

- Home draft cards are taller (~40%) so excerpts stay readable
- Full example blog page is `Rascunhos` with `language: pt-BR`

### Removed

- Mobile nav no longer shows a page `badge` note (language belongs in `language`, not a sidebar label)

## [1.2.1] — 2026-10-05

### Added

- GitHub Actions workflow publishes the gem to RubyGems when a release is published (`RUBYGEMS_API_KEY`)

### Fixed

- Refresh root `Gemfile.lock` for the 1.2 path gemspec (CI frozen `bundle install`)
- Run validate gates under `bundle exec` so Jekyll resolves in CI

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
