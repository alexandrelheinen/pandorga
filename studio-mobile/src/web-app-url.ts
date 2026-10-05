// Shared CJS helper so Expo app.config and the WebView shell use one resolver.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { DEFAULT_WEB_APP_URL, resolveWebAppUrl } = require('../resolve-web-app-url.cjs') as {
  DEFAULT_WEB_APP_URL: string;
  resolveWebAppUrl: (...candidates: Array<string | undefined | null>) => string;
};

export { DEFAULT_WEB_APP_URL, resolveWebAppUrl };

type ExpoExtra = { extra?: { webAppUrl?: string } };

/** Production Studio URL loaded inside the native WebView shell. */
export function readWebAppUrl(): string {
  // Lazy require keeps expo-constants (and react-native) out of unit test imports.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const Constants = require('expo-constants').default as {
    expoConfig?: ExpoExtra;
    manifest?: ExpoExtra;
    manifest2?: { extra?: { expoClient?: ExpoExtra } };
  };
  return resolveWebAppUrl(
    Constants.expoConfig?.extra?.webAppUrl,
    Constants.manifest?.extra?.webAppUrl,
    Constants.manifest2?.extra?.expoClient?.extra?.webAppUrl,
    process.env.STUDIO_WEB_APP_URL,
  );
}
