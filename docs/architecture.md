# Architecture

Pandorga is one Ruby gem that ships a Jekyll theme, Jekyll plugins, and a
CLI. A consuming site supplies identity, content, and configuration. The
platform never embeds an owner name, bucket ID, or Clerk production key.

## Layers

| Layer | What it is | Where it lives |
|---|---|---|
| Shell | Static HTML/CSS from Jekyll layouts and includes | Theme gem (`_layouts`, `_includes`, `assets`) |
| Content JSON | Exported collections and `manifest.json` | Object store or `_site` (`static` backend) |
| Runtime | Browser module that fetches JSON and fills the shell | `_includes/content-runtime/` (concatenated fragments) |
| Studio | Optional Vite editor + Pages Functions | `studio-app/`, compiled `studio/`, `functions/` |

No Node build runs for the public shell. Studio is the only Vite build; the
gem embeds the compiled assets. Sites copy Functions into the project root
with `pandorga install-functions` before a Cloudflare Pages build.

## Page registry

`pandorga.pages` drives listing pages, `site.data.nav`, homepage bands, and
which collections the exporter and adapters see. Details:
[pages-and-templates.md](pages-and-templates.md) and
[configuration.md](configuration.md).

## Content path

1. Editorial files sit under the site `content/` tree.
2. `pandorga export` writes JSON (and `schema_version` in the manifest).
3. `pandorga publish` syncs to an S3-compatible store when the backend is not
   `static`.
4. The runtime loads the manifest, checks `schema_version`, then hydrates
   listings and detail views.

## Studio path

`pandorga studio-schema` composes `studio/schema.yml` from thin template
`studio.yml` fragments plus optional `studio.overrides.yml`. The web Studio
talks to GitHub through Pages Functions. Auth and allowlists are site env
vars; see [studio.md](studio.md). Schema coverage is still thin: only some
templates ship Studio field fragments.

## Optional Android shell

`studio-mobile/` is an Expo WebView APK shell for Studio. It lives in the git
repository and is excluded from the Ruby gem. Identity (Studio URL, Android
package, app name, EAS project id) comes from env / EAS — see
[studio-android.md](studio-android.md). Attaching APKs to releases is left to
consuming sites.

## Deferred platform pieces

Phase 6 in [spec.md](spec.md) covered `pandorga new`, RubyGems publication,
and the generic Android Studio app. The first two landed in 1.1; Android
ships in 1.2. Remaining work is keeping registry and template APIs stable.
