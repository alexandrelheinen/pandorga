#!/usr/bin/env node
/**
 * Pipeline status updates must patch the toolbar chip. Rebuilding the shell
 * drops editor focus for the whole run.
 */
import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const source = fs.readFileSync(path.join(root, "studio-app/src/main.js"), "utf8");

function skipString(i) {
  const q = source[i];
  i += 1;
  while (i < source.length && source[i] !== q) {
    if (source[i] === "\\") i += 2;
    else i += 1;
  }
  return i + 1;
}

function functionSource(name) {
  const re = new RegExp(`(?:async\\s+)?function\\s+${name}\\s*\\(`);
  const m = re.exec(source);
  if (!m) throw new Error(`missing function ${name}`);
  let i = m.index + m[0].length;
  let paren = 1;
  while (i < source.length && paren > 0) {
    const c = source[i];
    if (c === "'" || c === '"' || c === "`") i = skipString(i);
    else if (c === "/" && source[i + 1] === "/") {
      const nl = source.indexOf("\n", i);
      i = nl === -1 ? source.length : nl + 1;
    } else {
      if (c === "(") paren += 1;
      else if (c === ")") paren -= 1;
      i += 1;
    }
  }
  while (i < source.length && source[i] !== "{") i += 1;
  if (i >= source.length) throw new Error(`missing body ${name}`);
  let depth = 0;
  while (i < source.length) {
    const c = source[i];
    if (c === "{") {
      depth += 1;
      i += 1;
    } else if (c === "}") {
      depth -= 1;
      if (depth === 0) return source.slice(m.index, i + 1);
      i += 1;
    } else if (c === "'" || c === '"' || c === "`") {
      i = skipString(i);
    } else if (c === "/" && source[i + 1] === "/") {
      const nl = source.indexOf("\n", i);
      i = nl === -1 ? source.length : nl + 1;
    } else {
      i += 1;
    }
  }
  throw new Error(`unclosed function ${name}`);
}

class MiniNode {
  constructor(tag) {
    this.nodeType = 1;
    this.tagName = String(tag || "").toUpperCase();
    this.childNodes = [];
    this.parentNode = null;
    this.attributes = new Map();
    this.className = "";
    this.disabled = false;
    this.title = "";
    this.value = "";
    this.selectionStart = 0;
    this.selectionEnd = 0;
    this._text = "";
    this.listeners = new Map();
    const node = this;
    this.classList = {
      toggle(name, force) {
        const parts = node.className.split(/\s+/).filter(Boolean);
        const has = parts.includes(name);
        const on = force === undefined ? !has : !!force;
        const next = parts.filter((part) => part !== name);
        if (on) next.push(name);
        node.className = next.join(" ");
        return on;
      },
    };
  }

  get textContent() {
    if (this.childNodes.length === 0) return this._text;
    return this.childNodes.map((child) => child.textContent).join("");
  }

  set textContent(value) {
    this._text = value == null ? "" : String(value);
    this.childNodes = [];
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  }

  getAttribute(name) {
    return this.attributes.has(name) ? this.attributes.get(name) : null;
  }

  addEventListener(type, fn) {
    this.listeners.set(type, fn);
  }

  append(...kids) {
    for (const kid of kids) {
      if (kid == null || kid === false) continue;
      kid.parentNode = this;
      this.childNodes.push(kid);
    }
  }

  replaceWith(next) {
    const parent = this.parentNode;
    if (!parent) return;
    const idx = parent.childNodes.indexOf(this);
    if (idx < 0) return;
    next.parentNode = parent;
    parent.childNodes[idx] = next;
    this.parentNode = null;
    if (document.activeElement === this) document.activeElement = document.body;
  }

  querySelector(sel) {
    return querySelector(this, sel);
  }

  focus() {
    document.activeElement = this;
  }

  setSelectionRange(start, end) {
    this.selectionStart = start;
    this.selectionEnd = end;
  }
}

function matches(node, sel) {
  const attr = sel.match(/^\[([^=]+)='([^']*)'\]$/);
  if (attr) return node.getAttribute(attr[1]) === attr[2];
  if (sel.startsWith(".")) {
    const name = sel.slice(1);
    return node.className.split(/\s+/).includes(name);
  }
  return false;
}

function querySelector(root, sel) {
  for (const child of root.childNodes || []) {
    if (child.nodeType === 1 && matches(child, sel)) return child;
    const found = querySelector(child, sel);
    if (found) return found;
  }
  return null;
}

const document = {
  activeElement: null,
  body: null,
  createElement(tag) {
    return new MiniNode(tag);
  },
  querySelector(sel) {
    return querySelector(document.body, sel);
  },
};
document.body = new MiniNode("body");
document.body.parentNode = document;

const editor = new MiniNode("textarea");
editor.value = "keep typing";
editor.className = "body-editor";
const chipHost = new MiniNode("div");
document.body.append(chipHost, editor);

const state = {
  pipeline: {
    state: "idle",
    sha: "",
    runUrl: "",
    message: "",
    pollGen: 0,
  },
  reexporting: false,
  error: "",
  errorDetail: "",
  status: "",
  file: "content/collections/articles/hello.md",
  saving: false,
  dirty: false,
};

let statusCalls = 0;
const studioApi = {
  async pipelineStatus() {
    statusCalls += 1;
    if (statusCalls < 3) {
      return {
        state: "running",
        sha: "abc",
        run: { html_url: "https://example.com/actions/runs/9" },
      };
    }
    return {
      state: "ok",
      sha: "abc",
      run: { html_url: "https://example.com/actions/runs/9" },
    };
  },
};

const context = {
  state,
  document,
  studioApi,
  sleep: async () => {},
  console,
  JSON,
  String,
  window: { open() {}, location: { hostname: "studio.example.com" } },
};
vm.createContext(context);
vm.runInContext(
  [
    functionSource("el"),
    functionSource("pipelineChipMeta"),
    functionSource("pipelineChipViewKey"),
    functionSource("renderPipelineChip"),
    functionSource("syncPipelineChip"),
    functionSource("applyPipelinePayload"),
    functionSource("localExportPresentation"),
    functionSource("syncLocalExportButton"),
    functionSource("pollPipelineStatus"),
  ].join("\n"),
  context
);

chipHost.append(vm.runInContext("renderPipelineChip()", context));
editor.focus();
editor.setSelectionRange(5, 5);
const editorAtFocus = document.activeElement;

await vm.runInContext(
  `(async () => {
    state.pipeline.pollGen = 1;
    state.pipeline.state = "awaiting_run";
    syncPipelineChip();
    await pollPipelineStatus(1, "abc");
  })()`,
  context
);

assert.equal(document.activeElement, editorAtFocus, "editor focus survives pipeline polls");
assert.equal(editor.parentNode, document.body, "editor stays mounted");
assert.equal(editor.value, "keep typing");
assert.equal(editor.selectionStart, 5);
assert.equal(state.pipeline.state, "ok");

const chip = document.querySelector("[data-studio-action='pipeline-status']");
assert.ok(chip, "pipeline chip remains");
assert.match(chip.className, /pipeline-ok/);
assert.equal(chip.querySelector(".btn-label").textContent, "Live");
assert.equal(chip.querySelector(".studio-icon-spin"), null);
assert.equal(chip.disabled, false);

editor.focus();
state.reexporting = true;
state.pipeline.state = "syncing";
vm.runInContext("syncLocalExportButton()", context);
const exportBtn = document.querySelector("[data-studio-action='reexport']");
assert.equal(exportBtn, null, "production shell has no local export button");

const exportHost = new MiniNode("button");
exportHost.setAttribute("data-studio-action", "reexport");
exportHost.className = "btn btn-tool btn-reexport";
const icon = new MiniNode("span");
icon.className = "material-symbols-outlined";
icon.textContent = "sync";
const label = new MiniNode("span");
label.className = "btn-label";
label.textContent = "Export";
exportHost.append(icon, label);
document.body.append(exportHost);

editor.focus();
vm.runInContext("syncLocalExportButton()", context);
assert.equal(document.activeElement, editor, "local export spin does not steal editor focus");
assert.equal(exportHost.disabled, true);
assert.match(exportHost.className, /pipeline-running/);
assert.equal(icon.textContent, "progress_activity");
assert.match(icon.className, /studio-icon-spin/);
assert.equal(label.textContent, "Exporting…");
assert.equal(editor.value, "keep typing");

console.log("All Studio pipeline focus checks passed.");
