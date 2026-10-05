/**
 * Atomic Liquid include blocks for TipTap.
 * Spec: docs/features/studio.md §6 — AC-STU-03, AC-STU-04.
 */

import { Node, mergeAttributes } from "@tiptap/core";
import {
  INCLUDE_DEFS,
  attrsToInclude,
  parseIncludes,
  markdownToEditorContent,
  serializeContent,
} from "./liquid-core.js";

export {
  INCLUDE_DEFS,
  attrsToInclude,
  parseIncludes,
  markdownToEditorContent,
  serializeContent,
};

export function LiquidIncludeNode(def) {
  return Node.create({
    name: def.name,
    group: def.inline ? "inline" : "block",
    inline: !!def.inline,
    atom: true,
    selectable: true,
    draggable: true,
    addAttributes() {
      const attrs = {};
      for (const f of def.fields) {
        attrs[f] = { default: "" };
      }
      attrs.raw = { default: "" };
      return attrs;
    },
    parseHTML() {
      return [{ tag: `div[data-liquid="${def.name}"]` }];
    },
    renderHTML({ HTMLAttributes }) {
      const summary = def.fields
        .map((f) => HTMLAttributes[f])
        .filter(Boolean)
        .slice(0, 2)
        .join(" | ");
      const tag = def.inline ? "span" : "div";
      return [
        tag,
        mergeAttributes(HTMLAttributes, {
          "data-liquid": def.name,
          class: def.inline ? "liquid-block liquid-block--inline" : "liquid-block",
          "data-include": def.include,
        }),
        ["strong", {}, def.label],
        [tag === "span" ? "span" : "div", {}, summary || "(empty)"],
      ];
    },
    addCommands() {
      return {
        [`insert${def.name.charAt(0).toUpperCase()}${def.name.slice(1)}`]:
          (attrs = {}) =>
          ({ commands }) =>
            commands.insertContent({
              type: def.name,
              attrs,
            }),
      };
    },
  });
}

export function serializeDocToMarkdown(editor) {
  const json = editor.getJSON();
  return serializeContent(json.content || []);
}
