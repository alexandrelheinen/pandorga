import type { ConfigContext, ExpoConfig } from 'expo/config';

// Expo evaluates app.config with Node require(); keep shared logic in CJS.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { readAppVersion } = require('./read-app-version.cjs') as {
  readAppVersion: () => string;
};
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { resolveConfiguredWebAppUrl } = require('./resolve-web-app-url.cjs') as {
  resolveConfiguredWebAppUrl: (
    profile: string | undefined | null,
    envUrl: string | undefined | null,
  ) => string;
};

/**
 * Set after `npx eas init` via env (`EAS_PROJECT_ID`) or by replacing this
 * placeholder. While it remains the placeholder, `extra.eas.projectId` is
 * omitted so `eas init` can create the project.
 */
const PLACEHOLDER_EAS_PROJECT_ID = 'REPLACE_WITH_EAS_PROJECT_ID';
const DEFAULT_EAS_PROJECT_ID = PLACEHOLDER_EAS_PROJECT_ID;

const DEFAULT_ANDROID_PACKAGE = 'com.example.pandorga.studio';
const DEFAULT_APP_NAME = 'Studio';

const LIGHT_CANVAS = '#ffffff';

function readEasProjectId(): string | undefined {
  const raw = process.env.EAS_PROJECT_ID?.trim();
  if (raw && raw !== PLACEHOLDER_EAS_PROJECT_ID) return raw;
  if (DEFAULT_EAS_PROJECT_ID !== PLACEHOLDER_EAS_PROJECT_ID) {
    return DEFAULT_EAS_PROJECT_ID;
  }
  return undefined;
}

function readAndroidPackage(): string {
  const fromEnv =
    process.env.STUDIO_ANDROID_PACKAGE?.trim() ||
    process.env.ANDROID_PACKAGE?.trim();
  return fromEnv || DEFAULT_ANDROID_PACKAGE;
}

function readAppName(): string {
  const fromEnv = process.env.STUDIO_APP_NAME?.trim();
  return fromEnv || DEFAULT_APP_NAME;
}

export default ({ config }: ConfigContext): ExpoConfig => {
  const easProjectId = readEasProjectId();
  const webAppUrl = resolveConfiguredWebAppUrl(
    process.env.EAS_BUILD_PROFILE,
    process.env.STUDIO_WEB_APP_URL,
  );

  return {
    ...config,
    name: readAppName(),
    slug: 'studio',
    version: readAppVersion(),
    orientation: 'portrait',
    icon: './assets/studio/icon.png',
    scheme: 'studio',
    userInterfaceStyle: 'automatic',
    newArchEnabled: true,
    splash: {
      image: './assets/studio/splash.png',
      resizeMode: 'contain',
      backgroundColor: LIGHT_CANVAS,
    },
    android: {
      package: readAndroidPackage(),
      softwareKeyboardLayoutMode: 'resize',
      adaptiveIcon: {
        foregroundImage: './assets/studio/adaptive-icon.png',
        backgroundColor: LIGHT_CANVAS,
      },
    },
    plugins: ['expo-router', 'expo-asset'],
    extra: {
      webAppUrl,
      ...(easProjectId ? { eas: { projectId: easProjectId } } : {}),
    },
  };
};
