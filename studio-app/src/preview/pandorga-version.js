/**
 * Vite replaces `__PANDORGA_VERSION__` with `Pandorga::VERSION` from
 * `lib/pandorga/version.rb` at build time. Do not hardcode a release number
 * here; the gem file is the source of truth.
 */
export const PANDORGA_VERSION = __PANDORGA_VERSION__;
