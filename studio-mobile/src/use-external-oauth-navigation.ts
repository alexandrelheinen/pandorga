import * as WebBrowser from 'expo-web-browser';
import { useCallback, useRef, type RefObject } from 'react';
import type { WebView } from 'react-native-webview';
import {
  buildAuthSessionReturnUrl,
  buildWebViewNavigateScript,
  isGoogleOAuthUrl,
} from './oauth-external-browser';

WebBrowser.maybeCompleteAuthSession();

export function useExternalOAuthNavigation(
  webViewRef: RefObject<WebView | null>,
  webAppUrl: string,
) {
  const authInProgressRef = useRef(false);

  const openGoogleOAuthInBrowser = useCallback(
    async (oauthUrl: string) => {
      if (authInProgressRef.current) {
        return;
      }

      authInProgressRef.current = true;
      try {
        const returnUrl = buildAuthSessionReturnUrl(webAppUrl);
        const result = await WebBrowser.openAuthSessionAsync(oauthUrl, returnUrl);

        if (result.type === 'success' && result.url) {
          webViewRef.current?.injectJavaScript(buildWebViewNavigateScript(result.url));
        }
      } finally {
        authInProgressRef.current = false;
      }
    },
    [webAppUrl, webViewRef],
  );

  const onShouldStartLoadWithRequest = useCallback(
    (request: { url: string }) => {
      if (!isGoogleOAuthUrl(request.url)) {
        return true;
      }

      void openGoogleOAuthInBrowser(request.url);
      return false;
    },
    [openGoogleOAuthInBrowser],
  );

  return { onShouldStartLoadWithRequest };
}
