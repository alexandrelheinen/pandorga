import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { ANDROID_STATUS_BAR_FALLBACK_PX, resolveTopInset } from './resolve-safe-area-insets';

describe('resolveTopInset', () => {
  it('returns a rounded positive inset', () => {
    assert.equal(resolveTopInset(47.6, 'android'), 48);
  });

  it('uses the status bar height on Android when the inset is zero', () => {
    assert.equal(resolveTopInset(0, 'android', 32), 32);
  });

  it('falls back when Android reports neither inset nor status bar height', () => {
    assert.equal(resolveTopInset(0, 'android', 0), ANDROID_STATUS_BAR_FALLBACK_PX);
    assert.equal(resolveTopInset(0, 'android'), ANDROID_STATUS_BAR_FALLBACK_PX);
  });

  it('does not invent a top inset on iOS', () => {
    assert.equal(resolveTopInset(0, 'ios', 20), 0);
  });
});
