/** Typical Android status bar height when the OS reports zero insets. */
export const ANDROID_STATUS_BAR_FALLBACK_PX = 24;

export type SafeAreaPlatform = 'ios' | 'android' | 'web' | 'windows' | 'macos';

export function resolveTopInset(
  rawTop: number,
  platform: SafeAreaPlatform,
  statusBarHeight?: number,
): number {
  const rounded = Math.max(0, Math.round(rawTop));
  if (rounded > 0) return rounded;
  if (platform !== 'android') return 0;

  if (typeof statusBarHeight === 'number' && statusBarHeight > 0) {
    return Math.round(statusBarHeight);
  }

  return ANDROID_STATUS_BAR_FALLBACK_PX;
}
