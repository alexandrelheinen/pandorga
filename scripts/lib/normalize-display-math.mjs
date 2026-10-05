/**
 * Repair common display-math row-break corruption before MathJax typesets.
 *
 * Editorial / CMS pipelines sometimes turn LaTeX `\\` row separators into a
 * single `\` (end of line) or `\ ` (backslash + space inside matrix/cases).
 * MathJax then treats the rows as one horizontal equation.
 *
 * Keep in sync with `_includes/content-runtime/20-markdown.html`
 * (`normalizeDisplayMathTex`).
 */

const ROW_ENV =
  'align\\*?|aligned|gather\\*?|eqnarray\\*?|split|cases|matrix|bmatrix|pmatrix|vmatrix|Vmatrix|smallmatrix|array';

const ROW_ENV_BLOCK = new RegExp(
  `\\\\begin\\{(${ROW_ENV})\\}([\\s\\S]*?)\\\\end\\{\\1\\}`,
  'g'
);

export function normalizeDisplayMathTex(math) {
  let text = String(math || '');

  // Odd-length trailing backslash run at EOL → add one `\` so the run is even.
  text = text
    .split('\n')
    .map((line) => {
      const match = line.match(/(\\+)([ \t]*)$/);
      if (!match) return line;
      if (match[1].length % 2 === 0) return line;
      return line.slice(0, line.length - match[0].length) + match[1] + '\\' + match[2];
    })
    .join('\n');

  // Inside ams/matrix row environments, lone `\ ` is almost always a corrupted `\\`.
  text = text.replace(ROW_ENV_BLOCK, (full, env, body) => {
    const fixed = body.replace(/(^|[^\\])\\([ \t]+)/g, (_, prefix, ws) => `${prefix}\\\\${ws}`);
    return `\\begin{${env}}${fixed}\\end{${env}}`;
  });

  return text;
}

export function normalizeMathRegion(mathMatch) {
  const raw = String(mathMatch || '');
  if (raw.startsWith('$$') && raw.endsWith('$$')) {
    return `$$${normalizeDisplayMathTex(raw.slice(2, -2))}$$`;
  }
  if (raw.startsWith('\\[') && raw.endsWith('\\]')) {
    return `\\[${normalizeDisplayMathTex(raw.slice(2, -2))}\\]`;
  }
  return raw;
}
