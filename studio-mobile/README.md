# Studio Android shell

Expo WebView that opens a live Pandorga Studio editor. Defaults point at
`https://example.com/studio/` and package `com.example.pandorga.studio`.
Override identity with env / EAS (see [docs/studio-android.md](../docs/studio-android.md)).

This tree lives in the git repository for consumers who clone GitHub. It is
**not** packaged inside the Ruby gem.

```bash
cd studio-mobile
npm ci
npm test
```
