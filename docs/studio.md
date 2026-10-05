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
| `GITHUB_TOKEN` | Contents API PAT |
| `STUDIO_ALLOWED_ORIGINS` | Comma-separated exact Origins |
| `CLERK_*` | Auth (see Clerk docs) |
| `STUDIO_GUIDELINES_URL` | Optional; enables Refine |

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
