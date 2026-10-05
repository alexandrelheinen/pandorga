# Studio SPA source

Vite app that builds into `../studio/` (committed static assets served at `/studio/`).

```bash
cd studio-app
npm ci
# Optional: bake Clerk publishable key into the bundle
VITE_CLERK_PUBLISHABLE_KEY=pk_test_… npm run build
```

## Local API

Jekyll (`./scripts/dev-serve.sh`) does not run Pages Functions. For `/api/studio/*`:

```bash
# Terminal A — Functions on :8788 (needs repo-root .dev.vars; see .dev.vars.example)
./scripts/studio-api-dev.sh

# Terminal B — site + proxy, or Vite with built-in proxy to :8788
./scripts/dev-serve.sh
# or: npm run dev   # proxies /api/studio → STUDIO_API_PROXY (default :8788)
```

`./scripts/dev-serve.sh` auto-starts the API when `.dev.vars` (or Studio keys in `.env`) exists.

Spec: [docs/features/studio.md](../docs/features/studio.md). Operator tutorial: [docs/content/studio.md](../docs/content/studio.md). Schema: [studio/schema.yml](../studio/schema.yml). API: [functions/api/studio/](../functions/api/studio/).
