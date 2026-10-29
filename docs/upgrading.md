# Upgrading

Pandorga follows [Semantic Versioning](https://semver.org/). The gem version
is `Pandorga::VERSION` (`lib/pandorga/version.rb`).

## What bumps what

| Change | Version impact |
|---|---|
| Template contract, registry schema, or exported JSON shape | Major (or a deprecation window while still on a pre-1.x line) |
| New optional config, backward-compatible behaviour | Minor |
| Bug fix with no contract change | Patch |

Read [CHANGELOG.md](../CHANGELOG.md) before you bump.

## Mobile article/post detail action button wrap (2.2.1)

Bug fix only. Restores `flex-wrap: wrap` on mobile `.text-detail-sidebar .article-meta` under `@media (max-width: 767px)` so action buttons (Back, Share, Cite, reading size) wrap to the next row when dates and actions cannot share one line, preventing button crushing and clipping on narrow screens (regression from 2.1.0) (PLT-AC-67).

## Ancizar cqi hero clamps, upright list titles, unified markers & hierarchy ladder (2.2.0)

Pandorga 2.2.0 updates title typography, cqi clamps, hero family markers, and section/specimen hierarchy:

- **CR-10 — Ancizar hero clamps:** Recalculated `.home-hero-title` cqi divisors for Ancizar Serif at -0.02em tracking (~5.55em phone family-line width, ~10.81em desktop full-name cap). Replaced Cinzel comments/factors.
- **CR-11 — Upright list page titles:** List page header titles (`.page-header-title`) drop hardcoded `class="italic"` and default to upright. Emphasis and marker washes apply only to explicit `*emphasis*` (`<em>`) segments. Token `--type-page` is bumped from 2.4015rem to 2.75rem and `--type-page-lg` from 2.9015rem to 3.35rem.
- **CR-12 — Hero family marker:** `.home-hero-family` drops `font-style: italic` and keeps primary color, with highlighter mark strength raised to ~0.88× section alpha levels.
- **CR-13 — Home hierarchy ladder:** Section titles dominate specimen names across mobile and desktop breakpoints. Section title steps are raised (e.g. `--type-section-sm` raised to 1.7rem), and `.home-specimen-title` no longer uses `var(--type-section)` at large breakpoints (>=900px).
- **CR-14 — Unified title role markers:** Grouped selector in `assets/css/base.css` ensures `em` elements inside `.section-title`, `.page-header-title`, `.home-index-title`, `.card-title`, and `.ledger-card-title` all receive the felt-marker wash.

## Mobile body weight cascade (2.1.1)

Bug fix only. `--weight-body` on viewports under 768px now reads
`pandorga.fonts.body_weight_mobile` because the rebind sits in
`theme-vars.html` after the palette token block. No config change.

## Four-family typography & Projects sidebar (2.1.0)

Pandorga 2.1.0 updates theme defaults and layout features:

- **Typography:** Theme defaults switch to Ancizar Serif (title + wordmark) and Ancizar Sans (body + taglines). Cinzel Decorative and Newsreader defaults are replaced. `--font-content-title` now uses `--font-title` (Ancizar Serif). Sites that relied on Cinzel Decorative or Newsreader defaults must explicitly configure `pandorga.fonts` in `_config.yml` if they wish to keep those fonts:
  ```yaml
  pandorga:
    fonts:
      title: "Cinzel Decorative"
      body: "Newsreader"
  ```
- **Body weights:** Site-configurable via `pandorga.fonts.body_weight` (desktop default 300) and `pandorga.fonts.body_weight_mobile` (mobile default 350). On mobile viewports (`<768px`), `--weight-body` rebinds to `body_weight_mobile`.
- **Home Projects sidebar (desktop >=900px):** The inventory column moves to the left of the specimen. Inventory buttons become logo-only with enlarged icon marks, displaying accessible titles on hover/focus. Accessible name is `aria-label="Explore projects"` on the inventory group (visible label removed in CR-21d).

## Hero summary file (2.0.2)

No `pandorga:` keys were added. The home hero reads
`content/pages/home/summary.md` when it exists, and the CV page keeps
`content/pages/cv/summary.md`. To split them, copy the current text of
`cv/summary.md` into `home/summary.md`; the hero does not change, and
`cv/summary.md` is then free for the CV page alone. Without the new file the
hero keeps reading `cv/summary.md`. Saved empty, the hero shows no summary.

## 16:9 home hero (2.0.0, breaking)

The home hero plate is 16:9 at every width (`PLT-AC-51`). A site upgrading
from 1.x changes:

- **Gemfile.** Pin `gem "pandorga", "~> 2.0"`; `~> 1.3` never resolves
  2.0.0. Then run `bundle update pandorga`.
- **Photographs.** Every file in `content/media/images/hero/` should be a
  16:9 original (1920 px wide covers the 1440 variant). A 3:4 file is
  center-cropped to 16:9.
- **Variants.** `pandorga export` (or `pandorga thumbnails`) now writes
  16:9 `variants/<stem>-{480,960,1440}.jpg` for each hero photograph and
  replaces the old 3:4 files of the same name. Delete any other hero file
  under `variants/`, such as a separate 16:9 copy kept for phones.
- **`portraits.json`.** The export no longer needs anything added by hand.
  Drop the `landscape` field from any entry the site writes or patches; the
  runtime ignores it. `srcset` lists only 16:9 variants, and `sizes` is
  `(max-width: 1023px) 100vw, 50vw`.
- **Config.** Remove `pandorga.home.hero_landscape` and home front matter
  `hero_landscape`. Both are ignored.
- **Name size.** From 1024px the name sets on two lines. The theme sizes it
  with `.home-ledger .home-hero-title` so the longer part fills the copy
  column. A site that sets its own hero name size can keep it below
  1024px; from 1024px set `--hero-name-fit` (the longer part's width in
  em) and `--hero-name-max` instead of a font size.

## Project thumbnail variants (1.13+)

`pandorga export` (and `pandorga thumbnails`) writes 16:9 width variants (`variants/<stem>-{480,960,1440}.jpg`) beside each local `/media/...` project thumbnail and sets `thumbnail_srcset` in the exported project front matter; the content pipeline needs ImageMagick on the runner, and sites may commit or ignore `variants/` folders.

## Mobile hero pool (1.10.0)

Superseded by the 16:9 home hero above.

At or below 767px the home hero draws at random from
`pages/home/portraits.json` entries that set `landscape`, and paints that
entry's 16:9 URL. `src` stays the 3:4 file used above 767px. `srcset` and
`sizes` stay optional and are not applied to the landscape file.

`pandorga.home.hero_landscape` (home front matter `hero_landscape` overrides
it) is the fallback, used only when no entry has `landscape`. Set it so the
first paint is a fixed 16:9 plate. Omit it, and omit every `landscape`, and
the phone plate stays 3:4.

```json
[
  {
    "src": "/media/images/hero/plate.jpg",
    "landscape": "/media/images/hero/plate-16x9.jpg"
  }
]
```

```yaml
pandorga:
  home:
    hero_landscape: /media/images/hero/fallback-16x9.jpg
```

The folder export does not invent `landscape`. The site adds the field to
each entry that has a 16:9 file.

## Narrow hero (1.9.0)

Superseded by the 16:9 home hero above.

Optional `pandorga.home.hero_landscape` is a root-relative path or an
absolute URL of a 16:9 image. At or below 767px the home hero uses that
file through `<picture>` and a 16:9 plate, with `object-fit: contain`, so
the 3:4 portrait is not cropped into the band. Home front matter
`hero_landscape` overrides the site key. Omit both and every width keeps
the 3:4 plate. The theme does not ship the photograph.

```yaml
pandorga:
  home:
    hero_landscape: /media/images/hero/home-16x9.jpg
```

Variants under `variants/` stay 3:4 fills for the portrait plate. From
1.10.0 the single URL above is the fallback. See Mobile hero pool.

## Detail URLs (1.7.3)

1.7.2 wrote one static page per article, post, project, and product,
and removed the splat 200 lines from the published `_redirects`. A text
published only to the content store then 404ed, because Pages does not
rebuild for content. 1.7.3 restores the shell. One listing page serves
every detail URL, and the client loads the entry from the runtime.

Publish the built `_redirects`. It keeps these lines, and adds any that
the source file is missing:

```
/articles/:slug /pages/articles/ 200
/posts/:slug /pages/blog/ 200
/blog/:slug /pages/blog/ 200
/projects/:slug /pages/projects/ 200
/products/:slug /pages/cv/ 200
```

The source file is not edited. Specific 301 lines stay where they are.
The sitemap does not list detail URLs. The client sets the canonical
link and `og:url` when the entry renders. The shell does not emit
Article or BlogPosting JSON-LD.

`jekyll serve` rewrites every detail URL onto the listing shell.

No `pandorga:` keys were added.

## Site fonts (1.7.0)

Optional. A site that sets nothing keeps Cinzel Decorative, Newsreader,
and Courier Prime. Set a Google Fonts family, or a map with `family` and
optional `weights` and `italic`:

```yaml
pandorga:
  fonts:
    title: "Fraunces"
    body:
      family: "Source Serif 4"
      weights: [400, 600]
    mono:
      family: "IBM Plex Mono"
      weights: [400, 500]
      italic: true
```

`label` and `subtitle` use the same shape. The tagline follows `body`
when you leave `subtitle` out and the theme used one family for both.
Text faces still load after the first paint. A release still needs a
Lighthouse mobile score of 90 or above.

## Home list tasks (1.6.9)

No `pandorga:` keys were added. Filling the home bands yields between
bands and between project specimen measurements. The lists still render.
A release still needs a Lighthouse mobile score of 90 or above.

## Home lists (1.6.8)

No `pandorga:` keys were added. Listing scripts start when the content
runtime is assigned. The runtime stays after the page. A release still
needs the static hero summary, the text faces after first paint, the
named icon subset, and a Lighthouse mobile score of 90 or above. The
example home must also show project and article items after load. Article
titles in the home Articles band are 2pt larger, and on a phone the
featured card has more space above its text. Below 1024px the Rascunhos
licence stays under the entries.

## Launcher icons (1.6.8)

The gem draws the site icon and the Studio icon from the site stamp.
Studio adds a small badge inside the stamp. At 512, 192, 180, and 32
the canvases match, and the stamp uses the same pixel bounds on both,
so the home-screen shortcuts are the same visual size. The build writes
`/site.webmanifest` and `/studio.webmanifest`. Each lists 192 and 512
icons with purpose `any` and purpose `maskable`. Android then masks
both shortcuts to one shape.

A file in the website at the same path replaces the gem file. Replace
these four so the tab icon and the Apple icon match the installed icons:

| Website path | Copy from the gem |
|---|---|
| `favicon.ico` | `assets/icons/favicon.ico` |
| `assets/icons/favicon.svg` | `assets/icons/favicon.svg` |
| `assets/icons/favicon-32.png` | `assets/icons/favicon-32.png` |
| `assets/icons/apple-touch-icon.png` | `assets/icons/apple-touch-icon.png` |

Copy those four files at the gem's pixel size. Resizing one of them
changes the home-screen size of that shortcut.

Leave these paths absent. A file there hides the icon the manifest names:

- `assets/icons/icon-192.png`
- `assets/icons/icon-512.png`
- `assets/icons/icon-maskable-192.png`
- `assets/icons/icon-maskable-512.png`
- `assets/icons/studio-icon-192.png`
- `assets/icons/studio-icon-512.png`
- `assets/icons/studio-maskable-192.png`
- `assets/icons/studio-maskable-512.png`
- `assets/icons/studio-apple-touch-icon.png`
- `assets/icons/studio-logo.svg`
- `assets/icons/studio-logo-32.png`
- `assets/icons/studio-logo.ico`

Do not commit `site.webmanifest` or `studio.webmanifest`. The gem writes
them. `pandorga install-functions` copies `studio/index.html`, which
links `/studio.webmanifest`. If the website repository has its own
`studio/index.html` or `_includes/theme/favicons.html`, add that link or
delete the copy.

The manifest name is `pandorga.identity.name`, then `site.title`. After
the site is published, remove the old home-screen shortcuts and install
them again. Android keeps the icon from the first install.

## Example home score (1.6.7)

No `pandorga:` keys were added. Text faces are requested after the first
paint and before the load event. The icon face requests named icons only.
Lighthouse runs against `examples/full`, which has a static hero summary.

## Example home score (1.6.6)

No `pandorga:` keys were added. The text-face stylesheet and the flag
stylesheet are added after the page loads. The markdown library loads
with `defer`. A release below 90 does not publish unless the notes
include `LIGHTHOUSE_BUGFIX=1`.

## Example home score (1.6.5)

No `pandorga:` keys were added. The icon face is requested after the page
loads, not from a head link. The text font sheet and the flag stylesheet
no longer block first paint. The Lighthouse example server compresses
text and answers concurrently.

## Material Symbols (1.6.4)

No `pandorga:` keys were added. The icon stylesheet no longer blocks first
paint. Lighthouse mobile thresholds apply to releases: 90 or above for a
stable release, 75 to 89 only to ship a bug fix, then an urgent campaign
back to 90. Below 75 is never acceptable for a release. A pull request or
a merge may score lower when that is unavoidable to keep the work modular.

## Font stylesheet (1.6.3)

No `pandorga:` keys were added. The hero summary is still the built HTML
from 1.6.2. The Google Fonts stylesheet is linked with the other sheets
again. Only the font preconnect stays above the preload script.

## Hero summary (1.6.2)

No `pandorga:` keys were added. When `content/pages/cv/summary.md` exists,
the home hero includes that markdown as HTML. Sites without the file keep
the quiet fragment. The body fallback is `Georgia, serif`.

## Discovery and portraits (1.6.0)

No `pandorga:` keys were added. The shell writes `/sitemap.xml` and
`/robots.txt`, and a `WebSite` / `Person` JSON-LD block. The sitemap origin
is `pandorga.identity.url`, then `site.url`.

A hero portrait object may set `srcset` and `sizes` next to `src`. Omit them
and the plate still uses `src` alone.

```json
{ "src": "/media/images/hero/plate.jpg", "srcset": "/media/images/hero/plate-800.jpg 800w, /media/images/hero/plate.jpg 1200w", "sizes": "(max-width: 767px) 100vw, 16rem" }
```

The hero subtitle stays at the body size (`--type-body`).

## Hero name (1.5.0)

`pandorga.identity.name` stays required. Two optional keys split the home
hero. `last_name` may contain spaces. The top bar shows `first_name`.

```yaml
pandorga:
  identity:
    name: "Ada Example"
    first_name: "Ada"
    last_name: "Example"
```

A site that only sets `name` keeps the 1.4.9 split. The first word is the
given name and the top-bar wordmark. The rest of `name`, up to eight words,
is the family name. Set the new keys when that split is wrong, for example
when the family name itself has more than one word. On a phone the hero
breaks only between those two fields.

When `first_name` is omitted, the top bar uses the first word of
`identity.name`, then `site.author`, then `site.title`.

The hero subtitle uses the body size (`--type-body`), the same size as the
summary under the name. Below 768px the name is 3pt larger than in 1.4.9.

See [features/hero-name.md](features/hero-name.md).

## Pin the gem by tag

Consumer sites should pin a release tag, not `main`:

```ruby
# Gemfile — RubyGems (preferred once published)
gem "pandorga", "~> 2.0"

# Or pin a GitHub release tag
gem "pandorga", github: "alexandrelheinen/pandorga", tag: "v2.3.2"
```

After a bump, run `bundle update pandorga` and commit `Gemfile.lock`. Host
watch paths must include `Gemfile.lock` so the shell rebuilds when the gem
moves.

During local platform work, `bundle config local.pandorga ../pandorga` points
Bundler at a checkout without editing the Gemfile.

## Content `schema_version`

Every export writes `schema_version` into `manifest.json` (currently `1`).
The content runtime refuses an unknown version and shows an explicit error
instead of rendering a broken page.

When a release raises the schema, publish content JSON **before** you ship a
shell that requires the new version. See [deploy/cloudflare.md](deploy/cloudflare.md)
for the Pages + object-store order.

## RubyGems

`pandorga new` pins `gem "pandorga", "~> 2.0"`. Publishing is automated: when a
GitHub Release is published, [`.github/workflows/publish-gem.yml`](../.github/workflows/publish-gem.yml)
pushes the gem via [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)
(OIDC; no long-lived API key). The release tag must match `Pandorga::VERSION`
(for example `v1.8.1`).

Site wrappers that `exec` the gem publish script **must** export
`PANDORGA_SITE_ROOT` to the Jekyll site root. Without it, publish exits with an
error instead of skipping `content/media` (Studio uploads would otherwise land
on GitHub only).

One-time setup on [RubyGems.org](https://rubygems.org):

1. Create a **pending** trusted publisher for gem name `pandorga`
   ([pending trusted publishers](https://rubygems.org/profile/oidc/pending_trusted_publishers)),
   pointing at [github.com/alexandrelheinen/pandorga](https://github.com/alexandrelheinen/pandorga)
   with workflow filename `publish-gem.yml` and environment `release`.
2. Ensure the GitHub Environment `release` exists on that repository
   (Settings → Environments).

After the first successful push, the pending publisher becomes a normal
trusted publisher for `pandorga`. Until then, installs stay on the GitHub tag
pin above.

Manual publish (optional, local MFA may apply):

```bash
mise exec -- gem build pandorga.gemspec
mise exec -- gem push pandorga-2.3.2.gem
```

## Android shell (1.2+)

From 1.2.0 the git repository includes `studio-mobile/` (not packaged in the
gem). Clone the repo (or copy that tree), set `STUDIO_WEB_APP_URL` and related
env vars, run `eas init`, then build an APK — see
[studio-android.md](studio-android.md).
