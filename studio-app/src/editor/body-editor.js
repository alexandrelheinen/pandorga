import { Editor } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import Link from "@tiptap/extension-link";
import Placeholder from "@tiptap/extension-placeholder";
import { TextStyle } from "@tiptap/extension-text-style";
import { Color } from "@tiptap/extension-color";
import {
  INCLUDE_DEFS,
  LiquidIncludeNode,
  markdownToEditorContent,
  serializeDocToMarkdown,
} from "./liquid.js";

export function createBodyEditor(element, { content = "", onUpdate } = {}) {
  const liquidNodes = INCLUDE_DEFS.map(LiquidIncludeNode);

  const editor = new Editor({
    element,
    extensions: [
      StarterKit.configure({
        heading: { levels: [1, 2, 3, 4] },
      }),
      TextStyle,
      Color,
      Link.configure({
        autolink: false,
        linkOnPaste: false,
        openOnClick: false,
      }),
      Placeholder.configure({ placeholder: "Write… Use Insert for Liquid blocks." }),
      ...liquidNodes,
    ],
    content: markdownToEditorContent(content),
    onUpdate: ({ editor: ed }) => {
      if (onUpdate) onUpdate(serializeDocToMarkdown(ed));
    },
  });

  return {
    editor,
    getMarkdown: () => serializeDocToMarkdown(editor),
    setMarkdown: (md) => {
      editor.commands.setContent(markdownToEditorContent(md));
    },
    destroy: () => editor.destroy(),
    insertInclude: (defName, attrs = {}) => {
      const def = INCLUDE_DEFS.find((d) => d.name === defName);
      if (!def) return;
      editor.commands.insertContent({ type: def.name, attrs });
    },
    transformSelectionCase: (mode) => {
      const { from, to, empty } = editor.state.selection;
      if (empty) return;
      const text = editor.state.doc.textBetween(from, to, "");
      let next = text;
      if (mode === "lower") next = text.toLocaleLowerCase();
      else if (mode === "upper") next = text.toLocaleUpperCase();
      else if (mode === "title") {
        next = text.replace(/\S+/g, (word) => {
          const first = [...word][0] || "";
          const rest = [...word].slice(1).join("");
          return first.toLocaleUpperCase() + rest.toLocaleLowerCase();
        });
      } else return;
      editor.chain().focus().insertContentAt({ from, to }, next).run();
    },
  };
}

export { INCLUDE_DEFS };
