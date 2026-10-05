# Force UTF-8 as the process-wide default encoding.
#
# Some build environments (e.g. the Cloudflare build image) run under a non-UTF-8
# locale such as `C`/`POSIX`, which makes Ruby's `Encoding.default_external` be
# US-ASCII. Jekyll/kramdown then raise "The source text contains invalid
# characters for the used encoding US-ASCII" when rendering non-ASCII content
# (accents, em-dashes, etc.). Netlify defaulted to a UTF-8 locale, which hid this.
#
# Plugins are loaded before content is read and rendered, so setting the defaults
# here makes the build locale-independent regardless of how `jekyll build` is
# invoked. This is a no-op where the locale is already UTF-8 (local dev, CI).
Encoding.default_external = Encoding::UTF_8 unless Encoding.default_external == Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8 unless Encoding.default_internal == Encoding::UTF_8
