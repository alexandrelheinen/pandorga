# CV timeline temporal pan

## Intent

Let the reader move along time at the current zoom, with any input (pointer, touch, wheel, keyboard, on-screen buttons), without losing their place when they zoom, toggle lanes, or resize.

## Scope

In:

- Drag-to-pan on the timeline chart with the primary pointer.
- Keyboard pan and zoom when the wrapper region is focused.
- On-screen pan buttons (`‹`, `›`) and `Today` button with accessible names.
- Zoom, resize, and lane toggles anchored to the viewport center.
- Period selection moved to Shift+drag, with a hint beside the lane toggles.
- Respect `prefers-reduced-motion` for animated scrolling.

Out:

- Wheel or pinch zoom.
- Inertia or momentum beyond native scrolling.
- Vertical pan (lanes fit vertically).
- Changes to data, lanes, or styling beyond the new controls.

## Acceptance criteria

- `PLT-AC-47` The CV timeline supports temporal pan:
  1. When the reader drags the chart with the primary mouse or pen button, without Shift, it shall pan horizontally by the pointer delta. When the move is under 4 px, it shall not pan and shall behave as a click.
  2. When the reader drags with Shift held, it shall set a date range exactly as the plain drag did before this change.
  3. When the wrapper has focus, ←/→ shall pan 10% of the visible width; Shift+←/→ and PageUp/PageDown shall pan 90%; Home shall go to the range start; End shall go to today; `+` and `−` shall zoom. Other keys shall not be intercepted.
  4. The zoom controls shall include `‹`, `›` and `Today` buttons with accessible names. `‹` shall be disabled at `scrollLeft = 0`, and `›` shall be disabled at the maximum scroll.
  5. When the zoom changes, the lanes are toggled or the window is resized, the time at the viewport center shall stay centered (±1 day, or clamped at a bound). The chart shall open on today only on first load.
  6. A vertical wheel shall scroll the page, not the timeline. Touch swipe shall stay native.
  7. Smooth scrolling shall be disabled under `prefers-reduced-motion: reduce`.
  8. The wrapper shall be keyboard-focusable, with a visible focus outline and an accessible name.

## Design notes

Native horizontal scroll on `#timeline-chart-wrapper` (`scrollLeft`) drives pan, preserving sticky lane labels and the year axis without transform overhead. Pointer events with `setPointerCapture` implement primary button drag. To distinguish clicks from pans, movement below 4 px is treated as a click. Moving period selection to Shift+drag preserves date filtering while freeing primary drag for pan. Keyboard interaction operates only when the wrapper region (`tabindex="0"`, `role="region"`) has focus, leaving Tab flow uninterrupted. Centering across zoom, resize, and lane visibility changes calculates the viewport center timestamp (`timeFromClientX`) prior to re-render and restores it via `centerPreservingScroll`. Button and keyboard pans use `scrollTo({ behavior: 'smooth' })`, falling back to `'auto'` when `prefers-reduced-motion: reduce` matches.

## Constraints

No Node build for the public site shell; timeline logic remains inline in `_includes/page/timeline-section.html`. `panTarget` and `centerPreservingScroll` are pure functions placed directly before `parseDate`, so `test-timeline-pan.mjs` can execute them from the real source. The selection hint reads "Shift+drag to select a period". The pan and Today buttons reuse the zoom button classes and tokens. The timeline can boot twice (inline placeholder, then the runtime JSON), so `bootTimeline` aborts the previous boot's listeners through an `AbortController` signal (`bootScope`) passed to every listener on a persistent element. The center date is read with the wrapper width of the last render, because on resize the wrapper already has its new width when the handler runs.

Backward compatibility: a plain drag used to select a period; it now pans. The CHANGELOG notes the change.
