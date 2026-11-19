/**
 * Mirrors `_includes/theme/theme-vars.html` + `theme-vars-block.liquid` for
 * the gem's default palette (`_data/themes/light.yml` / `dark.yml` /
 * `shared.yml`), which is also this site's resolved palette — `_config.yml`
 * names the same `Ancizar Serif` / `Ancizar Sans` families and `300` / `350`
 * body weights the shared defaults already carry (studio-app has no Liquid
 * runtime to render the real partial, so this is a literal, hand-kept copy;
 * re-sync by diffing against the two `.liquid`/`.html` files above whenever
 * a theme or font token changes).
 *
 * Only `assets/css/base.css` + `article.css` + `ledger/detail.css` sizing is
 * static (declared directly in `base.css`'s `html {}`); colour roles, the
 * four-family font stack, and motion durations are the one part of the cascade
 * that normally only exists after a Liquid render, which is why this file
 * exists at all.
 */

// Same Google Fonts request `_includes/theme/font-loader.html` resolves to
// for the gem defaults — one family per role, deduped (title, label, body,
// mono). Keep in sync with studio-app/index.html's own font `<link>`.
export const PREVIEW_FONTS_HREF =
  "https://fonts.googleapis.com/css2?family=Ancizar+Serif:ital,wght@0,400;0,600;1,400&family=Marcellus+SC:wght@400;700&family=Ancizar+Sans:ital,wght@0,300;0,350;0,400;0,600;1,300;1,350;1,400;1,600&family=Courier+Prime:ital,wght@0,400;0,700;1,400;1,700&display=swap";

const FONT_TITLE = "'Ancizar Serif', 'Pandorga Ancizar Fallback', serif";
const FONT_SUBTITLE_BODY = "'Ancizar Sans', 'Pandorga Ancizar Sans Fallback', sans-serif";
const FONT_LABEL = "'Marcellus SC', 'Pandorga Label Fallback', serif";
const FONT_MONO =
  "'Courier Prime', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, monospace";

function fontBlock() {
  return `
    --font-title: ${FONT_TITLE};
    --font-subtitle: ${FONT_SUBTITLE_BODY};
    --font-label: ${FONT_LABEL};
    --font-body: ${FONT_SUBTITLE_BODY};
    --font-cv-body: ${FONT_SUBTITLE_BODY};
    --font-cv-body-weight: 400;
    --weight-body: 300;
    --weight-body-mobile: 350;
    --font-serif: ${FONT_TITLE};
    --font-content-title: var(--font-title);
    --font-sans: var(--font-body);
    --font-mono: ${FONT_MONO};
    --font-code: ${FONT_MONO};

    --motion-duration-fast: 0.15s;
    --motion-duration-base: 0.4s;
    --motion-duration-slow: 0.7s;
    --motion-ease-default: ease;
    --motion-ease-out: ease-out;`;
}

function colorBlock({
  primary,
  secondary,
  tertiary,
  primaryContainer,
  secondaryContainer,
  tertiaryContainer,
  onPrimaryContainer,
  onSecondaryContainer,
  onTertiaryContainer,
  onPrimary,
  onSecondary,
  onTertiary,
  onSurface,
  onSurfaceVariant,
  onBackground,
  outline,
  outlineVariant,
  background,
  backgroundSecondary,
  surface,
  surfaceContainerLow,
  surfaceContainer,
  surfaceContainerHigh,
  surfaceVariant,
  surfaceContainerLowest,
  surfaceDim,
  panelContrast,
  surfaceCard,
  surfaceCardContrast,
  surfaceHigh,
  surfaceHighContrast,
  link,
  linkHover,
  inversePrimary,
  inverseSurface,
  inverseOnSurface,
  primaryFixed,
  primaryFixedDim,
  secondaryFixed,
  secondaryFixedDim,
  tertiaryFixed,
  tertiaryFixedDim,
  onPrimaryFixed,
  onPrimaryFixedVariant,
  onSecondaryFixed,
  onSecondaryFixedVariant,
  onTertiaryFixed,
  onTertiaryFixedVariant,
  error,
  onError,
  errorContainer,
  onErrorContainer,
  resYoutube,
  resPodcast,
  resDoc,
  timelineEmployment,
  timelineEducation,
  timelineProduct,
  timelineProject,
  timelineArticle,
  timelinePost,
  sidebarThumbnailBackground,
  sidebarThumbnailOverlayStart,
  sidebarThumbnailOverlayEnd,
}) {
  return `
    --color-primary: ${primary};
    --color-secondary: ${secondary};
    --color-tertiary: ${tertiary};
    --color-primary-container: ${primaryContainer};
    --color-secondary-container: ${secondaryContainer};
    --color-tertiary-container: ${tertiaryContainer};
    --color-on-primary-container: ${onPrimaryContainer};
    --color-on-secondary-container: ${onSecondaryContainer};
    --color-on-tertiary-container: ${onTertiaryContainer};
    --color-on-primary: ${onPrimary};
    --color-on-secondary: ${onSecondary};
    --color-on-tertiary: ${onTertiary};
    --color-on-surface: ${onSurface};
    --color-on-surface-variant: ${onSurfaceVariant};
    --color-on-background: ${onBackground};
    --color-outline: ${outline};
    --color-outline-variant: ${outlineVariant};
    --border-gentle-faint: color-mix(in srgb, ${outlineVariant} 22%, transparent);
    --border-gentle-subtle: color-mix(in srgb, ${outlineVariant} 32%, transparent);
    --border-gentle-divider: color-mix(in srgb, ${outlineVariant} 35%, transparent);
    --border-gentle: color-mix(in srgb, ${outlineVariant} 62%, transparent);
    --border-gentle-hover: color-mix(in srgb, ${outlineVariant} 78%, transparent);
    --border-ink: color-mix(in srgb, ${onSurface} 5%, ${background});
    --border-ink-strong: color-mix(in srgb, ${onSurface} 8%, ${background});
    --radius-card: 0;
    --cubist-card-border: var(--border-gentle);
    --cubist-card-border-hover: var(--border-gentle-hover);
    --color-background: ${background};
    --color-background-secondary: ${backgroundSecondary};
    --color-surface: ${surface};
    --color-surface-bright: ${surface};
    --color-surface-container-lowest: ${surfaceContainerLowest};
    --color-surface-container-low: ${surfaceContainerLow};
    --color-surface-container: ${surfaceContainer};
    --color-surface-container-high: ${surfaceContainerHigh};
    --color-surface-container-highest: ${surfaceVariant};
    --color-surface-variant: ${surfaceVariant};
    --color-surface-dim: ${surfaceDim};
    --color-panel-contrast: ${panelContrast};
    --color-canvas: ${panelContrast};
    --color-surface-card: ${surfaceCard};
    --color-surface-card-contrast: ${surfaceCardContrast};
    --color-surface-high: ${surfaceHigh};
    --color-surface-high-contrast: ${surfaceHighContrast};
    --color-panel-grey: color-mix(in srgb, ${surfaceContainer} 82%, ${background});
    --color-link: ${link};
    --color-link-hover: ${linkHover};
    --color-surface-tint: ${primary};
    --color-inverse-primary: ${inversePrimary};
    --color-inverse-surface: ${inverseSurface};
    --color-inverse-on-surface: ${inverseOnSurface};
    --color-primary-fixed: ${primaryFixed};
    --color-primary-fixed-dim: ${primaryFixedDim};
    --color-secondary-fixed: ${secondaryFixed};
    --color-secondary-fixed-dim: ${secondaryFixedDim};
    --color-tertiary-fixed: ${tertiaryFixed};
    --color-tertiary-fixed-dim: ${tertiaryFixedDim};
    --color-on-primary-fixed: ${onPrimaryFixed};
    --color-on-primary-fixed-variant: ${onPrimaryFixedVariant};
    --color-on-secondary-fixed: ${onSecondaryFixed};
    --color-on-secondary-fixed-variant: ${onSecondaryFixedVariant};
    --color-on-tertiary-fixed: ${onTertiaryFixed};
    --color-on-tertiary-fixed-variant: ${onTertiaryFixedVariant};
    --color-error: ${error};
    --color-on-error: ${onError};
    --color-error-container: ${errorContainer};
    --color-on-error-container: ${onErrorContainer};
    --color-res-youtube: ${resYoutube};
    --color-res-podcast: ${resPodcast};
    --color-res-doc: ${resDoc};
    --triad-primary: ${primary};
    --triad-secondary: ${secondary};
    --triad-tertiary: ${tertiary};
    --timeline-employment: ${timelineEmployment};
    --timeline-education: ${timelineEducation};
    --timeline-product: ${timelineProduct};
    --timeline-project: ${timelineProject};
    --timeline-article: ${timelineArticle};
    --timeline-post: ${timelinePost};
    --sidebar-thumbnail-background: ${sidebarThumbnailBackground};
    --sidebar-thumbnail-overlay-start: ${sidebarThumbnailOverlayStart};
    --sidebar-thumbnail-overlay-end: ${sidebarThumbnailOverlayEnd};
    --sidebar-thumbnail-width: 22rem;
    --sidebar-thumbnail-image-opacity: 0.94;
    --sidebar-thumbnail-filter-saturate: 0.68;
    --sidebar-thumbnail-filter-contrast: 0.98;
    --sidebar-thumbnail-filter-brightness: 1.02;
    --sidebar-thumbnail-filter-sepia: 0.10;`;
}

// _data/themes/light.yml
const LIGHT = colorBlock({
  primary: "#1c5a7a",
  secondary: "#287445",
  tertiary: "#746f30",
  primaryContainer: "#a8c5d4",
  secondaryContainer: "#b4d4c0",
  tertiaryContainer: "#d0ceb0",
  onPrimaryContainer: "#0a1419",
  onSecondaryContainer: "#0c1710",
  onTertiaryContainer: "#17160c",
  onPrimary: "#ffffff",
  onSecondary: "#ffffff",
  onTertiary: "#ffffff",
  onSurface: "#000000",
  onSurfaceVariant: "#5e5d59",
  onBackground: "#000000",
  outline: "#5c5c5c",
  outlineVariant: "#b8b8b8",
  background: "#ffffff",
  backgroundSecondary: "#f4f4f4",
  surface: "#ffffff",
  surfaceContainerLow: "#f4f4f4",
  surfaceContainer: "#ebebeb",
  surfaceContainerHigh: "#e2e2e2",
  surfaceVariant: "#d8d8d8",
  surfaceContainerLowest: "#ffffff",
  surfaceDim: "#d8d8d8",
  panelContrast: "#f4f4f4",
  surfaceCard: "#ffffff",
  surfaceCardContrast: "#f4f4f4",
  surfaceHigh: "#ebebeb",
  surfaceHighContrast: "#e2e2e2",
  link: "#1c5a7a",
  linkHover: "#2a6f92",
  inversePrimary: "#a4c8da",
  inverseSurface: "#000000",
  inverseOnSurface: "#ffffff",
  primaryFixed: "#a8c5d4",
  primaryFixedDim: "#7fa8bc",
  secondaryFixed: "#b4d4c0",
  secondaryFixedDim: "#6fb387",
  tertiaryFixed: "#d0ceb0",
  tertiaryFixedDim: "#c0bc90",
  onPrimaryFixed: "#0a1419",
  onPrimaryFixedVariant: "#163040",
  onSecondaryFixed: "#0c1710",
  onSecondaryFixedVariant: "#24382a",
  onTertiaryFixed: "#17160c",
  onTertiaryFixedVariant: "#3a381c",
  error: "#ba1a1a",
  onError: "#ffffff",
  errorContainer: "#ffdad6",
  onErrorContainer: "#93000a",
  resYoutube: "#c62828",
  resPodcast: "#2e7d32",
  resDoc: "#b45309",
  timelineEmployment: "#1c5a7a",
  timelineEducation: "#287445",
  timelineProduct: "#906c2a",
  timelineProject: "#534da1",
  timelineArticle: "#a95031",
  timelinePost: "#478576",
  sidebarThumbnailBackground: "#ebebeb",
  sidebarThumbnailOverlayStart: "rgba(255, 255, 255, 0.18)",
  sidebarThumbnailOverlayEnd: "rgba(226, 226, 226, 0.28)",
});

// _data/themes/dark.yml
const DARK = colorBlock({
  primary: "#a4c8da",
  secondary: "#95c8a6",
  tertiary: "#ddd8a8",
  primaryContainer: "#4a5c66",
  secondaryContainer: "#435c4c",
  tertiaryContainer: "#6a684f",
  onPrimaryContainer: "#c0d8e6",
  onSecondaryContainer: "#b5d9c2",
  onTertiaryContainer: "#ebe7c3",
  onPrimary: "#0f1a22",
  onSecondary: "#141a15",
  onTertiary: "#1b1c12",
  onSurface: "#ffffff",
  onSurfaceVariant: "#b8b7ae",
  onBackground: "#ffffff",
  outline: "#93938d",
  outlineVariant: "#45454c",
  background: "#0c0c0e",
  backgroundSecondary: "#141418",
  surface: "#111114",
  surfaceContainerLow: "#17171b",
  surfaceContainer: "#1f1f24",
  surfaceContainerHigh: "#26262b",
  surfaceVariant: "#2e2e34",
  surfaceContainerLowest: "#08080a",
  surfaceDim: "#060607",
  panelContrast: "#141418",
  surfaceCard: "#0c0c0e",
  surfaceCardContrast: "#141418",
  surfaceHigh: "#26262b",
  surfaceHighContrast: "#26262b",
  link: "#b0d0e0",
  linkHover: "#c4dce8",
  inversePrimary: "#1c5a7a",
  inverseSurface: "#ffffff",
  inverseOnSurface: "#000000",
  primaryFixed: "#a8c5d4",
  primaryFixedDim: "#a4c8da",
  secondaryFixed: "#b4d4c0",
  secondaryFixedDim: "#95c8a6",
  tertiaryFixed: "#d0ceb0",
  tertiaryFixedDim: "#ddd8a8",
  onPrimaryFixed: "#0a1419",
  onPrimaryFixedVariant: "#c0d8e6",
  onSecondaryFixed: "#0c1710",
  onSecondaryFixedVariant: "#b5d9c2",
  onTertiaryFixed: "#17160c",
  onTertiaryFixedVariant: "#e8e4c0",
  error: "#ffb4ab",
  onError: "#690005",
  errorContainer: "#93000a",
  onErrorContainer: "#ffdad6",
  resYoutube: "#de6461",
  resPodcast: "#5dc462",
  resDoc: "#e4b268",
  timelineEmployment: "#a4c8da",
  timelineEducation: "#95c8a6",
  timelineProduct: "#d5b46e",
  timelineProject: "#a9a5dd",
  timelineArticle: "#da987e",
  timelinePost: "#7cc7b5",
  sidebarThumbnailBackground: "#1f1f24",
  sidebarThumbnailOverlayStart: "rgba(23, 23, 27, 0.35)",
  sidebarThumbnailOverlayEnd: "rgba(12, 12, 14, 0.45)",
});

export const ARTICLE_THEME_TOKENS_CSS = `
:root, [data-theme="light"] {${fontBlock()}${LIGHT}
}
[data-theme="dark"] {${fontBlock()}${DARK}
}
@media (prefers-reduced-motion: reduce) {
  :root, [data-theme] {
    --motion-duration-fast: 0s;
    --motion-duration-base: 0s;
    --motion-duration-slow: 0s;
  }
}
@media (max-width: 767px) {
  :root, [data-theme] {
    --weight-body: var(--weight-body-mobile, 350);
  }
}
`;
