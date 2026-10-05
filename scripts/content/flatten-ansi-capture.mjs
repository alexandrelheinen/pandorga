#!/usr/bin/env node
// flatten-ansi-capture.mjs — turn a terminal capture into an ```ansi fence.
//
// An `ansi` fence is rendered by _includes/content-runtime/25-code-blocks.html,
// which honours SGR colour and nothing else. Real captures are not that clean:
// anything that paints columns does it by moving the cursor, and neofetch in
// particular draws its whole info block by jumping up twenty rows and right
// forty-three columns for every line. Pasted as-is, the result is one column of
// overstruck text.
//
// So the moves are played out here, onto a character grid, and the result is
// re-emitted as ordinary lines that carry colour and nothing else. What the
// fence stores is then what a reader sees.
//
// Usage:
//   script -qec "neofetch" /dev/null > capture.txt
//   node scripts/content/flatten-ansi-capture.mjs capture.txt > block.txt
//
// `script` is what makes the capture worth taking: neofetch, like most tools,
// drops its colour when stdout is not a terminal, and `script` gives it a pty
// to write to. Paste the output between ```ansi fences.
//
// --raw emits the 0x1b control byte instead of the printable `\e[` spelling.
// The default is the printable form, because that is what survives an editor,
// a JSON export and a diff; the renderer reads both.

import fs from 'node:fs';

const ESC = String.fromCharCode(27);

/* SGR is accumulated rather than replaced. Tools write the attributes of one
   run as several sequences in a row — neofetch's logo is `\e[0m\e[31m\e[1m` —
   so treating each `m` as the whole state throws away every colour. */
function makeAttr() {
  return { fg: null, bg: null, bold: false };
}

function applySgr(attr, params) {
  const codes = params === '' ? ['0'] : params.split(';');
  for (let i = 0; i < codes.length; i++) {
    const n = parseInt(codes[i], 10);
    if (Number.isNaN(n) || n === 0) { attr.fg = null; attr.bg = null; attr.bold = false; }
    else if (n === 1) attr.bold = true;
    else if (n === 22) attr.bold = false;
    else if (n === 39) attr.fg = null;
    else if (n === 49) attr.bg = null;
    else if ((n >= 30 && n <= 37) || (n >= 90 && n <= 97)) attr.fg = String(n);
    else if ((n >= 40 && n <= 47) || (n >= 100 && n <= 107)) attr.bg = String(n);
    else if (n === 38 || n === 48) {
      const target = n === 38 ? 'fg' : 'bg';
      if (codes[i + 1] === '5') { attr[target] = `${n};5;${codes[i + 2]}`; i += 2; }
      else if (codes[i + 1] === '2') {
        attr[target] = `${n};2;${codes[i + 2]};${codes[i + 3]};${codes[i + 4]}`;
        i += 4;
      }
    }
  }
}

function sgrOf(attr) {
  const parts = [];
  if (attr.bold) parts.push('1');
  if (attr.fg) parts.push(attr.fg);
  if (attr.bg) parts.push(attr.bg);
  return parts.join(';');
}

export function flattenAnsi(input) {
  const grid = [];
  let row = 0;
  let col = 0;
  const attr = makeAttr();

  const cell = (r, c) => {
    while (grid.length <= r) grid.push([]);
    const line = grid[r];
    while (line.length <= c) line.push({ ch: ' ', sgr: '', bg: false });
    return line[c];
  };

  for (let i = 0; i < input.length; i++) {
    const ch = input[i];
    if (ch === ESC && input[i + 1] === '[') {
      const m = /^\x1b\[([0-9;?]*)([A-Za-z])/.exec(input.slice(i));
      if (m) {
        const [, params, final] = m;
        const n = parseInt(params, 10) || 1;
        // `?` params belong to the private mode sequences (cursor hide, wrap
        // off) that every capture opens and closes with. Nothing to draw.
        if (final === 'm') applySgr(attr, params.replace(/\?/g, ''));
        else if (final === 'A') row = Math.max(0, row - n);
        else if (final === 'B') row += n;
        else if (final === 'C') col += n;
        else if (final === 'D') col = Math.max(0, col - n);
        else if (final === 'G') col = Math.max(0, n - 1);
        i += m[0].length - 1;
        continue;
      }
    }
    if (ch === '\n') { row++; col = 0; continue; }
    if (ch === '\r') { col = 0; continue; }
    if (ch === ESC || ch < ' ') continue;
    const target = cell(row, col);
    target.ch = ch;
    target.sgr = sgrOf(attr);
    target.bg = attr.bg != null;
    col++;
  }

  const lines = grid.map((line) => {
    // Trailing blanks are padding unless they carry a background colour, which
    // is how the palette strips at the foot of a neofetch block are drawn.
    let last = -1;
    for (let i = 0; i < line.length; i++) if (line[i].ch !== ' ' || line[i].bg) last = i;
    let text = '';
    let active = '';
    for (let i = 0; i <= last; i++) {
      const c = line[i];
      // A plain space shows no attribute of its own, so it stays inside the
      // run it sits in rather than forcing a reset mid-line.
      const want = c.ch === ' ' && !c.bg ? active : c.sgr;
      // Every run states its attributes absolutely, leading with the reset.
      // SGR is additive, so `\e[1m` after a red run is *bold red*, not bold
      // default — and that is exactly the pair neofetch's logo alternates
      // between. Emitting the difference would silently repaint the white
      // letters of the Ubuntu mark in red.
      if (want !== active) { text += `${ESC}[${want ? `0;${want}` : '0'}m`; active = want; }
      text += c.ch;
    }
    if (active) text += `${ESC}[0m`;
    return text;
  });

  while (lines.length && lines[lines.length - 1].replace(/\x1b\[[0-9;]*m/g, '').trim() === '') {
    lines.pop();
  }
  return lines.join('\n');
}

const args = process.argv.slice(2);
const raw = args.includes('--raw');
const source = args.filter((a) => !a.startsWith('--'))[0];

if (!source) {
  console.error('usage: flatten-ansi-capture.mjs <capture.txt> [--raw]');
  process.exit(2);
}

// latin1 throughout: a capture is a byte stream, and decoding it as UTF-8
// would fold the box-drawing bytes some logos use into replacement characters.
const flattened = flattenAnsi(fs.readFileSync(source, 'latin1'));
const out = raw ? flattened : flattened.split(ESC + '[').join('\\e[');
process.stdout.write(Buffer.from(out + '\n', 'latin1'));
