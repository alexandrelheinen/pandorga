---
# Kept as the readable theme binding. The shell does not load this file.
# Utilities are compiled to assets/css/tailwind.css (scripts/tailwind/build.sh).
# Named *-play.js so the Tailwind IntelliSense extension does not treat it as
# tailwind.config.js and fail with "tailwind is not defined" / _site duplicates.
---
tailwind.config = {
  darkMode: ["selector", '[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {% include theme/tailwind-theme-colors.json.liquid %},
      fontFamily: {% include theme/tailwind-theme-fonts.json.liquid %},
      borderRadius: { "DEFAULT": "0.125rem", "lg": "0.25rem", "xl": "0.5rem", "full": "0.75rem" },
    },
  },
}
