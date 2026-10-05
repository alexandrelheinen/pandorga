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

Compose the schema from templates:

```bash
bundle exec pandorga studio-schema
```
