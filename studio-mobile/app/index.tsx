import { useRef, useState } from 'react';
import { ActivityIndicator, Platform, StyleSheet, useColorScheme, View } from 'react-native';
import Constants from 'expo-constants';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { WebView } from 'react-native-webview';
import { resolveTopInset } from '../src/resolve-safe-area-insets';
import { useExternalOAuthNavigation } from '../src/use-external-oauth-navigation';
import { readWebAppUrl } from '../src/web-app-url';

/** DESIGN.md canvas tokens. The splash stays the light canvas; chrome follows the OS scheme. */
const LIGHT_CANVAS = '#ffffff';
const DARK_CANVAS = '#0c0c0e';
const STUDIO_PRIMARY = '#1c5a7a';

export default function StudioWebAppScreen() {
  const [loading, setLoading] = useState(true);
  const webViewRef = useRef<WebView>(null);
  const webAppUrl = readWebAppUrl();
  const { onShouldStartLoadWithRequest } = useExternalOAuthNavigation(webViewRef, webAppUrl);
  const insets = useSafeAreaInsets();
  const topInset = resolveTopInset(insets.top, Platform.OS, Constants.statusBarHeight);
  const chromeColor = useColorScheme() === 'dark' ? DARK_CANVAS : LIGHT_CANVAS;

  return (
    <SafeAreaView
      style={[styles.container, { backgroundColor: chromeColor, paddingTop: topInset }]}
      edges={['bottom']}
    >
      <WebView
        ref={webViewRef}
        source={{ uri: webAppUrl }}
        style={styles.webview}
        originWhitelist={['https://*', 'http://*']}
        javaScriptEnabled
        domStorageEnabled
        thirdPartyCookiesEnabled
        sharedCookiesEnabled
        setSupportMultipleWindows={false}
        allowsBackForwardNavigationGestures
        onShouldStartLoadWithRequest={onShouldStartLoadWithRequest}
        onLoadEnd={() => setLoading(false)}
        testID="studio-webview"
      />
      {loading ? (
        <View style={[styles.loadingOverlay, { backgroundColor: LIGHT_CANVAS }]} pointerEvents="none">
          <ActivityIndicator size="large" color={STUDIO_PRIMARY} accessibilityLabel="Loading Studio" />
        </View>
      ) : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  webview: {
    flex: 1,
    backgroundColor: LIGHT_CANVAS,
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
