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
| `GITHUB_TOKEN` | Fine-grained PAT: Contents **read/write**, and Actions **read** for the pipeline indicator |
| `STUDIO_ALLOWED_ORIGINS` | Comma-separated exact Origins |
| `CLERK_*` | Auth (see Clerk docs) |
| `STUDIO_GUIDELINES_URL` | Optional; enables Refine |

Optional overrides (prefer site `_config.yml` instead):

| Variable | Notes |
|---|---|
| `STUDIO_CONTENT_WORKFLOW` | Override workflow file; normally unused |
| `STUDIO_CONTENT_WORKFLOW_REF` | Override branch (default `main`) |

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
that push. The toolbar always shows a chip for that second step (between
Theme and Revert).

### Site config (`_config.yml`)

Point Studio at the workflow in the site config — this is **not** a secret:

```yaml
pandorga:
  content:
    backend: r2
    workflow: content-pipeline.yml
    # workflow_ref: main   # optional
```

The Function reads `_config.yml` from the repo over the Contents API. An
optional `STUDIO_CONTENT_WORKFLOW` env var overrides the file (local experiments
only).

### Local (`localhost` / `127.0.0.1`)

The **Export** button sits in the same toolbar slot. It calls
`POST /__dev/reexport`, shows an exporting animation, then reloads. It does
not call the Actions API.

### Production

After load, the chip shows the latest run on the configured workflow. After
Save (or create / delete / media commit), it tracks **that** commit SHA.
Status polls update the chip in place so the editor keeps focus for the
whole run.

| State | Meaning |
|---|---|
| Pipeline (muted) | Idle / no recent run |
| Waiting… (orange) | Commit succeeded; no matching run yet |
| Exporting… (orange, spinning) | Run is `queued` / `in_progress` |
| Live (green) | Run completed with `conclusion=success` |
| Failed (red) | Run failed or cancelled, or Actions API denied |
| No run | No run appeared within about ten minutes |

Click opens the run URL when one exists.

API: `GET /api/studio/pipeline-status` (optional `?sha=<commit>`). The Save
response includes `commit` (Git commit SHA).

The PAT needs **Actions: Read** in addition to Contents write.

## Android shell

An optional Expo WebView APK lives under `studio-mobile/` in the git
repository (not in the Ruby gem). Configure Studio URL, package id, app name,
and EAS project id via env — see [studio-android.md](studio-android.md).
