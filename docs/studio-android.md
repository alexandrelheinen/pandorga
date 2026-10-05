# Studio on Android

Pandorga ships an optional Expo WebView shell under `studio-mobile/`. It loads
your deployed Studio URL inside an Android APK. Auth, saves, and Clerk stay on
the website / Pages Functions — the shell has no Clerk secret or GitHub PAT.

The Android tree is in the **git repository** for anyone who clones GitHub. It
is **not** included in the Ruby gem (`pandorga.gemspec` excludes
`studio-mobile/**`).

Defaults (replace for a real site):

| Setting | Default |
|---|---|
| Web URL | `https://example.com/studio/` |
| Android package | `com.example.pandorga.studio` |
| App name | `Studio` |
| EAS project id | omitted until `EAS_PROJECT_ID` is set |

## Environment

| Variable | Notes |
|---|---|
| `STUDIO_WEB_APP_URL` | Studio origin + `/studio/` path. Used by local Expo and by EAS `env`. |
| `STUDIO_ANDROID_PACKAGE` | Android `applicationId`. Falls back to `ANDROID_PACKAGE`, then the default. |
| `ANDROID_PACKAGE` | Alternate name for the package id. |
| `STUDIO_APP_NAME` | Launcher / display name (default `Studio`). |
| `EAS_PROJECT_ID` | Expo project UUID after `npx eas init`. |
| `STUDIO_RELEASE_VERSION` | Optional; overrides `package.json` version for release builds. |
| `EXPO_TOKEN` | Expo access token for non-interactive / CI EAS builds (never commit). |

Copy `.env.example` to `studio-mobile/.env` for local overrides (gitignored).

## Tools

1. Node 22 (`node -v`).
2. From the repository root:

   ```bash
   cd studio-mobile
   npm ci
   npm test
   ```

   `npm test` does not call Expo or EAS.

3. Optional global CLI: `npm install -g eas-cli`. Commands below use `npx eas`
   from `studio-mobile/`.

## Create the Expo project (once)

Run inside `studio-mobile/`, never at the repository root.

```bash
cd studio-mobile
npx eas login
npx eas whoami
npx eas init --non-interactive
```

Slug: `studio`. Owner: your Expo account. The committed config omits
`extra.eas.projectId` until a real UUID is available — otherwise EAS fails with
`Invalid UUID appId`.

Set the project id via env (preferred for CI) or by replacing the placeholder
in `app.config.ts`:

```bash
# studio-mobile/.env (gitignored) or EAS / GitHub secret
EAS_PROJECT_ID=your-uuid-here
```

```bash
npx eas project:info
```

Do not reuse another app's EAS project id.

## First Android keystore (once, interactive)

EAS will not invent a keystore during a non-interactive CI build. Create it
from your machine:

```bash
cd studio-mobile
# Point release at your Studio before building:
# edit eas.json build.release.env.STUDIO_WEB_APP_URL
# and optionally set STUDIO_ANDROID_PACKAGE / STUDIO_APP_NAME
npx eas build --platform android --profile release
```

When prompted, let Expo generate and store the Android keystore. Profile
`release` builds an `.apk` (not a Play Store bundle). The start URL comes from
`STUDIO_WEB_APP_URL` in EAS `env` (see `eas.json`); if unset, the shell falls
back to `https://example.com/studio/`.

Download when finished:

```bash
npx eas build:list --platform android --limit 1
mkdir -p ../dist/mobile
npx eas build:download --platform android --latest --output ../dist/mobile/studio-latest-android.apk
```

`dist/` is gitignored. Do not commit a `.jks`.

## Sideload

1. Copy the `.apk` to the phone (USB, Drive, or the expo.dev download).
2. Open the file and allow install from that source if Android asks.
3. Open the app. Sign in with a Clerk user already on your site's Studio
   allowlist. Email sign-in stays in the WebView; Google opens the system
   browser and returns to Studio.
4. Saving still commits through your Pages Function, same as the desktop
   editor.

If a later APK will not install over an older one, signatures differ —
uninstall, then install. Do not generate a second keystore if the first is
still on Expo.

## Local Expo against a machine-served Studio

```bash
# terminal 1: serve the site (Studio + Functions as you already do)
# terminal 2:
cd studio-mobile
# .env: STUDIO_WEB_APP_URL=http://127.0.0.1:4000/studio/
npx expo start
```

Press `a` for an Android emulator, or scan the QR with Expo Go. The path must
contain `/studio/`; other paths fall back to the default URL.

## CI in this repository

`.github/workflows/studio-mobile.yml` runs `npm ci && npm test` on
`studio-mobile/`. It does **not** run EAS builds. Attaching APKs to GitHub
releases remains a consumer-site concern (for example a website-owned workflow
with `EXPO_TOKEN`).

## Related

- [docs/studio.md](studio.md) — Studio Functions env and schema compose
- [studio-mobile/README.md](../studio-mobile/README.md) — shell package scripts
