# Studio

Pandorga Studio is the optional CMS. Cloudflare Pages Functions are installed
with:

```bash
bundle exec pandorga install-functions
```

## Required environment

| Variable | Notes |
|---|---|
| `GITHUB_REPO` | `owner/name` — **required**, no default |
| `GITHUB_TOKEN` | Fine-grained PAT: Contents **read/write**, and Actions **read** when using the pipeline indicator |
| `STUDIO_ALLOWED_ORIGINS` | Comma-separated exact Origins |
| `CLERK_*` | Auth (see Clerk docs) |
| `STUDIO_GUIDELINES_URL` | Optional; enables Refine |
| `STUDIO_CONTENT_WORKFLOW` | Optional; workflow file under `.github/workflows/` (e.g. `content-pipeline.yml`). Enables the production pipeline status chip after Save |
| `STUDIO_CONTENT_WORKFLOW_REF` | Optional; branch to query (default `main`) |

Compose the schema from templates and the page registry. Each registered
page contributes its template `studio.yml`; removing the page drops those
collections. Optional site patches live in `studio.overrides.yml`.

```bash
# From a site root that has _config.yml (e.g. examples/full):
bundle exec pandorga studio-schema
# Or pass the site path:
bundle exec pandorga studio-schema path/to/site
```

The command writes `studio/schema.yml` with a `media` block when templates
need uploads, shared `components`, and `content` groups whose collection
items match the registry.

## Content pipeline status

Studio Save commits to `main` through the GitHub Contents API. Publishing
JSON to the site’s object store is usually a separate Actions workflow on
that push. The toolbar shows whether that second step finished.

### Local (`localhost` / `127.0.0.1`)

The **Export** button stays a real control. It calls `POST /__dev/reexport`,
shows an exporting animation, then reloads. It does not call the Actions API.

### Production

There is no Export control. After a successful Save (or create / delete /
media commit), a status chip appears in that slot:

| State | Meaning |
|---|---|
| Waiting… (orange) | Commit succeeded; no matching workflow run yet |
| Exporting… (orange, spinning) | Run is `queued` / `in_progress` |
| Live (green) | Run completed with `conclusion=success` for that commit SHA |
| Failed (red) | Run failed or cancelled, or Actions API denied |
| No run | No run appeared within about ten minutes |

The chip correlates by **exact `head_sha`**, not “latest run on main”. Click
opens the run URL when one exists.

API: `GET /api/studio/pipeline-status?sha=<commit>`. The Save response already
includes `commit` (Git commit SHA). Set `STUDIO_CONTENT_WORKFLOW` on the
Pages Function env or the indicator stays idle / reports unconfigured.

The PAT needs **Actions: Read** in addition to Contents write. Without it the
chip turns red with an authorization message instead of spinning forever.

## Android shell

An optional Expo WebView APK lives under `studio-mobile/` in the git
repository (not in the Ruby gem). Configure Studio URL, package id, app name,
and EAS project id via env — see [studio-android.md](studio-android.md).
