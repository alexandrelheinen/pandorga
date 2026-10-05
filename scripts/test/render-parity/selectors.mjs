// selectors.mjs — the fixture selector vocabulary, shared by both runners.
//
// Fixtures describe expectations as selector-ish strings rather than parsing
// the HTML, so a fixture stays readable and the runners stay dependency-free.
// Supported forms:
//   "iframe" / "img" / "video" / "blockquote"  bare tag
//   "span.lang-pill"                           tag with class
//   "ledger-chip-row"                          class name, or a tag name
//
// Class matching is whole-token, not \b-delimited: a hyphen is a word
// boundary, so `\bledger-chip\b` also matches class="ledger-chip-row" and
// every count comes out one too high.

function classPattern(name, flags = 'i') {
  return new RegExp(`class="(?:[^"]*\\s)?${name}(?:\\s[^"]*)?"`, flags);
}

export function matchesSelector(html, selector) {
  if (selector === 'iframe') return /<iframe\b/i.test(html);
  if (selector === 'img') return /<img\b/i.test(html);
  if (selector === 'video') return /<video\b/i.test(html);
  if (selector === 'blockquote') return /<blockquote\b/i.test(html);
  const tagClass = String(selector).match(/^([a-z][\w-]*)\.([a-z][\w-]*)$/i);
  if (tagClass) {
    const [, tag, cls] = tagClass;
    return new RegExp(`<${tag}\\b[^>]*class="(?:[^"]*\\s)?${cls}(?:\\s[^"]*)?"`, 'i').test(html);
  }
  return classPattern(selector).test(html) || new RegExp(`<${selector}\\b`, 'i').test(html);
}

export function missingSelectors(html, selectors) {
  return (selectors || []).filter((selector) => !matchesSelector(html, selector));
}

export function presentSelectors(html, selectors) {
  return (selectors || []).filter((selector) => matchesSelector(html, selector));
}

/** How many elements carry the class, for "exactly one separator" assertions. */
export function countClass(html, className) {
  const matches = html.match(classPattern(className, 'gi'));
  return matches ? matches.length : 0;
}
