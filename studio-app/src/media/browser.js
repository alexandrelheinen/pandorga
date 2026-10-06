/**
 * Studio media library — browse content/media, upload, create folders.
 * Cite paths as /media/… in Liquid includes after upload.
 */

const MEDIA_ROOT = "content/media";
const MAX_UPLOAD_BYTES = 25 * 1024 * 1024;
const IMAGE_EXT = /\.(png|jpe?g|gif|webp|svg|avif|bmp|ico)$/i;
const VIDEO_EXT = /\.(mp4|webm|mov|m4v)$/i;
const HTML_EXT = /\.html?$/i;
const SAFE_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

export function mediaRootFromSchema(schema) {
  const input = String(schema?.media?.input || MEDIA_ROOT).replace(/\/+$/, "");
  if (input === MEDIA_ROOT || input.startsWith(`${MEDIA_ROOT}/`)) return MEDIA_ROOT;
  return MEDIA_ROOT;
}

export function toPublicPath(repoPath) {
  const path = String(repoPath || "");
  if (path.startsWith("content/media")) {
    return path.replace(/^content/, "") || "/media";
  }
  return "";
}

export function isImageName(name) {
  return IMAGE_EXT.test(String(name || ""));
}

export function isVideoName(name) {
  return VIDEO_EXT.test(String(name || ""));
}

export function isHtmlName(name) {
  return HTML_EXT.test(String(name || ""));
}

/** image | video | html — kinds the media library can open in the figure lightbox. */
export function previewKind(name) {
  if (isImageName(name)) return "image";
  if (isVideoName(name)) return "video";
  if (isHtmlName(name)) return "html";
  return null;
}

export function formatBytes(n) {
  const bytes = Number(n) || 0;
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function sanitizeUploadName(raw) {
  const base = String(raw || "")
    .split(/[/\\]/)
    .pop()
    .trim();
  if (!base) return null;
  const cleaned = base.replace(/\s+/g, "-").replace(/[^A-Za-z0-9._-]/g, "");
  if (!SAFE_NAME.test(cleaned)) return null;
  return cleaned;
}

export function sanitizeFolderName(raw) {
  const name = String(raw || "")
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^A-Za-z0-9._-]/g, "");
  if (!SAFE_NAME.test(name) || name === ".gitkeep") return null;
  return name;
}

export function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result || "");
      const comma = result.indexOf(",");
      resolve(comma >= 0 ? result.slice(comma + 1) : result);
    };
    reader.onerror = () => reject(reader.error || new Error("read_failed"));
    reader.readAsDataURL(file);
  });
}

export function buildBreadcrumb(dirPath, root = MEDIA_ROOT) {
  const path = String(dirPath || root);
  const parts = path.split("/").filter(Boolean);
  const rootParts = root.split("/").filter(Boolean);
  const crumbs = [];
  let acc = "";
  for (let i = 0; i < parts.length; i++) {
    acc = acc ? `${acc}/${parts[i]}` : parts[i];
    const isRoot = i === rootParts.length - 1 && acc === root;
    const belowRoot = i >= rootParts.length - 1;
    if (!belowRoot && !isRoot) continue;
    crumbs.push({
      label: isRoot || acc === root ? "media" : parts[i],
      path: acc,
    });
  }
  if (!crumbs.length) crumbs.push({ label: "media", path: root });
  return crumbs;
}

/**
 * Register-style header shared with collection list panes: kicker line,
 * title row with a live item count, and the two Media-only ops (New folder,
 * Upload) in the same `.list-new-btn`-anchored slot collections use for
 * their single "New" action. See `renderListHeader` in `main.js`.
 */
function renderMediaHeader(opts, { items, fileInput }) {
  const { el, materialIcon, state } = opts;
  const dirs = items.filter((i) => i.type === "dir").length;
  const files = items.length - dirs;
  const countText = state.mediaLoading
    ? ""
    : items.length
      ? `${dirs} ${dirs === 1 ? "folder" : "folders"} · ${files} ${files === 1 ? "file" : "files"}`
      : "Empty folder";

  const titleRow = [el("h1", { className: "list-pane-title", text: "Media" })];
  if (countText) {
    titleRow.push(el("span", { className: "list-pane-count", text: countText }));
  }
  titleRow.push(
    el(
      "button",
      {
        className: "btn btn-tool list-new-btn",
        type: "button",
        title: "Create a new folder here",
        "aria-label": "New folder",
        disabled: !!state.mediaBusy,
        onClick: () => void createFolder(opts),
      },
      [materialIcon("create_new_folder"), el("span", { className: "btn-label", text: "Folder" })]
    ),
    el(
      "button",
      {
        className: "btn btn-tool btn-primary",
        type: "button",
        title: "Upload files into this folder",
        "aria-label": "Upload files",
        disabled: !!state.mediaBusy,
        onClick: () => fileInput.click(),
      },
      [
        materialIcon(
          state.mediaBusy ? "progress_activity" : "upload",
          state.mediaBusy ? "studio-icon-spin" : ""
        ),
        el("span", { className: "btn-label", text: state.mediaBusy ? "Working…" : "Upload" }),
      ]
    )
  );

  return el("header", { className: "list-register" }, [
    el("p", { className: "list-register-kicker" }, [
      el("span", { className: "list-register-mark", "aria-hidden": "true" }),
      el("span", { text: "Register // Media" }),
      el("span", { className: "list-register-sep", "aria-hidden": "true", text: "/" }),
      el("span", { text: "Library index" }),
    ]),
    el("div", { className: "list-register-title-row" }, titleRow),
  ]);
}

/**
 * @param {object} opts
 * @param {typeof import("../api/client.js").studioApi} opts.api
 * @param {object} opts.state
 * @param {(tag: string, attrs?: object, children?: any[]) => HTMLElement} opts.el
 * @param {(name: string, extraClass?: string) => HTMLElement} opts.materialIcon
 * @param {(raw: string) => string} opts.resolveMediaUrl
 * @param {() => void} opts.render
 * @param {(err: any) => void} opts.captureError
 * @param {() => void} opts.clearError
 */
export function renderMediaPane(opts) {
  const { state, el } = opts;

  const dirPath = state.mediaPath || MEDIA_ROOT;
  const items = state.mediaItems || [];
  const crumbs = buildBreadcrumb(dirPath);

  const breadcrumb = el("nav", {
    className: "media-breadcrumb",
    "aria-label": "Media path",
  });
  crumbs.forEach((crumb, i) => {
    if (i > 0) {
      breadcrumb.append(el("span", { className: "media-breadcrumb-sep", text: "/" }));
    }
    const isLast = i === crumbs.length - 1;
    if (isLast) {
      breadcrumb.append(
        el("span", {
          className: "media-breadcrumb-current",
          text: crumb.label,
        })
      );
    } else {
      breadcrumb.append(
        el("button", {
          className: "media-breadcrumb-link",
          type: "button",
          text: crumb.label,
          onClick: () => void openMediaDir(crumb.path, opts),
        })
      );
    }
  });

  const fileInput = el("input", {
    type: "file",
    className: "media-file-input",
    multiple: "multiple",
    accept: "image/*,video/*,.html,.svg,.pdf",
    hidden: true,
    onChange: async (ev) => {
      const files = Array.from(ev.target.files || []);
      ev.target.value = "";
      if (!files.length) return;
      await uploadFiles(files, opts);
    },
  });

  const header = renderMediaHeader(opts, { items, fileInput });

  // Same bordered shelf as the collection list's search/sort toolbar
  // (`.list-controls`); the folder breadcrumb is Media's one control.
  const controls = el("div", { className: "list-controls media-controls" }, [breadcrumb]);

  let body;
  if (state.mediaLoading) {
    body = el("p", { className: "loading-msg", text: "Loading media…" });
  } else if (state.error && !items.length) {
    // Same shape as the collection list's load-error panel.
    body = el("div", { className: "list-error" }, [
      el("p", {
        className: "list-error-title",
        text: "Could not load this folder.",
      }),
      el("p", { className: "list-error-message", text: state.error }),
      state.errorDetail
        ? el("pre", { className: "list-error-detail", text: state.errorDetail })
        : null,
    ]);
  } else if (!items.length) {
    body = el("p", {
      className: "list-empty",
      text: "This folder is empty. Upload a file or create a subfolder.",
    });
  } else {
    const rows = items.map((item) => renderMediaRow(item, opts));
    body = el("div", { className: "ledger-list", role: "list" }, rows);
  }

  return el("div", { className: "pane media-pane" }, [header, controls, body, fileInput]);
}

function renderMediaRow(item, opts) {
  const { el, materialIcon, resolveMediaUrl, state } = opts;
  const isDir = item.type === "dir";
  const kind = isDir ? null : previewKind(item.name);
  const publicPath = item.public_path || (isDir ? null : toPublicPath(item.path));
  const thumbSrc =
    !isDir && isImageName(item.name) && publicPath
      ? resolveMediaUrl(publicPath)
      : "";

  let preview;
  if (isDir) {
    preview = el("span", { className: "media-thumb media-thumb--folder" }, [
      materialIcon("folder", "media-thumb-icon"),
    ]);
  } else if (thumbSrc) {
    const img = el("img", {
      className: "media-thumb-img",
      src: thumbSrc,
      alt: "",
      loading: "lazy",
      referrerpolicy: "no-referrer",
    });
    img.addEventListener("error", () => {
      img.replaceWith(
        el("span", { className: "media-thumb media-thumb--file" }, [
          materialIcon("image", "media-thumb-icon"),
        ])
      );
    });
    preview = el("span", { className: "media-thumb media-thumb--image" }, [img]);
  } else if (isVideoName(item.name)) {
    preview = el("span", { className: "media-thumb media-thumb--file" }, [
      materialIcon("movie", "media-thumb-icon"),
    ]);
  } else if (isHtmlName(item.name)) {
    preview = el("span", { className: "media-thumb media-thumb--file" }, [
      materialIcon("html", "media-thumb-icon"),
    ]);
  } else {
    preview = el("span", { className: "media-thumb media-thumb--file" }, [
      materialIcon("draft", "media-thumb-icon"),
    ]);
  }

  const metaParts = [];
  if (!isDir && item.size) metaParts.push(formatBytes(item.size));
  if (publicPath) metaParts.push(publicPath);
  const metaText = metaParts.join(" · ") || (isDir ? "Folder" : "");

  // Same copy block shape as a collection's `.ledger-row` title + meta line.
  const body = el("span", { className: "ledger-copy" }, [
    el("span", { className: "ledger-title", text: item.name }),
    metaText ? el("span", { className: "ledger-meta", text: metaText }) : null,
  ]);

  const openOrCopy = isDir
    ? () => void openMediaDir(item.path, opts)
    : kind
      ? (event) => openMediaPreview(item, event.currentTarget, opts)
      : () => void copyPath(publicPath, opts);

  const rowTitle = isDir
    ? `Open ${item.name}`
    : kind
      ? `Preview ${item.name}`
      : `Copy ${publicPath}`;

  const ops = !isDir && publicPath ? renderMediaOps(item, publicPath, opts) : null;

  const activate = (event) => {
    if (state.mediaBusy) return;
    openOrCopy(event);
  };

  // Whole row is the click/keyboard target, exactly like `.ledger-row`
  // (ops buttons below stop propagation the same way `ledger-ops` do).
  return el(
    "div",
    {
      className:
        "ledger-row ledger-row--plain media-row" +
        (kind ? " media-row--preview" : ""),
      role: "button",
      tabindex: "0",
      title: rowTitle,
      onClick: activate,
      onKeydown: (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          activate(e);
        }
      },
    },
    [preview, body, ops]
  );
}

function renderMediaOps(item, publicPath, opts) {
  const { el, materialIcon, state } = opts;
  const busy = !!state.mediaBusy;
  const copyBtn = el(
    "button",
    {
      className: "btn btn-icon media-op-btn media-copy-btn",
      type: "button",
      title: `Copy ${publicPath}`,
      "aria-label": `Copy path ${publicPath}`,
      disabled: busy,
      onClick: (e) => {
        e.stopPropagation();
        void copyPath(publicPath, opts);
      },
    },
    [materialIcon("content_copy")]
  );
  const deleteBtn = el(
    "button",
    {
      className: "btn btn-icon media-op-btn media-delete-btn",
      type: "button",
      title: `Delete ${item.name}`,
      "aria-label": `Delete ${item.name}`,
      disabled: busy,
      onClick: (e) => {
        e.stopPropagation();
        void deleteMediaFile(item, opts);
      },
    },
    [materialIcon("delete")]
  );
  return el("div", { className: "media-ops", role: "group", "aria-label": "Operations" }, [
    copyBtn,
    deleteBtn,
  ]);
}

/** One overlay for the page, same chrome as the public figure lightbox. */
let mediaLightbox = null;
let mediaLightboxTrigger = null;

function ensureMediaLightbox(el, materialIcon) {
  if (mediaLightbox) return mediaLightbox;
  const img = el("img", { className: "figure-lightbox-img", alt: "" });
  const video = el("video", {
    className: "figure-lightbox-video",
    controls: true,
    playsinline: true,
  });
  const frame = el("iframe", {
    className: "figure-lightbox-frame",
    title: "Media preview",
  });
  const caption = el("p", { className: "figure-lightbox-caption" });
  img.hidden = true;
  video.hidden = true;
  frame.hidden = true;
  caption.hidden = true;
  video.controls = true;
  const closeBtn = el(
    "button",
    {
      type: "button",
      className: "figure-lightbox-close",
      "data-lightbox-close": "true",
      "aria-label": "Close",
      onClick: (event) => {
        event.preventDefault();
        closeMediaPreview();
      },
    },
    [materialIcon("close")]
  );
  const root = el(
    "div",
    {
      id: "figure-lightbox",
      className: "figure-lightbox",
      role: "dialog",
      "aria-modal": "true",
      "aria-label": "Media preview",
      "aria-hidden": "true",
    },
    [
      el("div", {
        className: "figure-lightbox-backdrop",
        "data-lightbox-close": "true",
        tabindex: "-1",
        onClick: () => closeMediaPreview(),
      }),
      el("div", { className: "figure-lightbox-panel" }, [
        closeBtn,
        img,
        video,
        frame,
        caption,
      ]),
    ]
  );
  root.hidden = true;
  document.body.append(root);
  document.addEventListener("keydown", (event) => {
    if (!mediaLightbox || mediaLightbox.root.hidden) return;
    if (event.key === "Escape") {
      event.preventDefault();
      closeMediaPreview();
    }
  });
  mediaLightbox = { root, img, video, frame, caption, closeBtn };
  return mediaLightbox;
}

function clearLightboxMedia(box) {
  box.img.removeAttribute("src");
  box.img.alt = "";
  box.img.hidden = true;
  box.video.pause();
  box.video.removeAttribute("src");
  box.video.load();
  box.video.hidden = true;
  box.frame.removeAttribute("src");
  box.frame.hidden = true;
  box.caption.textContent = "";
  box.caption.hidden = true;
}

function setLightboxOpen(box, isOpen) {
  box.root.hidden = !isOpen;
  box.root.setAttribute("aria-hidden", String(!isOpen));
  document.documentElement.classList.toggle("figure-lightbox-open", isOpen);
  document.body.classList.toggle("figure-lightbox-open", isOpen);
}

function closeMediaPreview() {
  if (!mediaLightbox || mediaLightbox.root.hidden) return;
  clearLightboxMedia(mediaLightbox);
  setLightboxOpen(mediaLightbox, false);
  const trigger = mediaLightboxTrigger;
  mediaLightboxTrigger = null;
  if (trigger && typeof trigger.focus === "function") {
    try {
      trigger.focus();
    } catch {
      /* row may have been re-rendered */
    }
  }
}

function openMediaPreview(item, trigger, opts) {
  const { el, materialIcon, resolveMediaUrl } = opts;
  const kind = previewKind(item.name);
  const publicPath = item.public_path || toPublicPath(item.path);
  const url = publicPath ? resolveMediaUrl(publicPath) : "";
  if (!kind || !url) return;
  const box = ensureMediaLightbox(el, materialIcon);
  mediaLightboxTrigger = trigger || null;
  clearLightboxMedia(box);
  if (kind === "image") {
    box.img.hidden = false;
    box.img.referrerPolicy = "no-referrer";
    box.img.alt = item.name || "";
    box.img.src = url;
  } else if (kind === "video") {
    box.video.hidden = false;
    box.video.referrerPolicy = "no-referrer";
    box.video.src = url;
  } else {
    box.frame.hidden = false;
    box.frame.title = item.name || "HTML preview";
    box.frame.src = url;
  }
  box.caption.textContent = item.name || "";
  box.caption.hidden = !item.name;
  setLightboxOpen(box, true);
  box.closeBtn.focus();
}

async function copyPath(publicPath, opts) {
  const { state, render, captureError, clearError } = opts;
  if (!publicPath) return;
  clearError();
  try {
    await navigator.clipboard.writeText(publicPath);
    state.status = `Copied ${publicPath}`;
  } catch (err) {
    captureError(err);
    state.status = publicPath;
  }
  render();
}

async function deleteMediaFile(item, opts) {
  const { api, state, render, captureError, clearError } = opts;
  const path = item?.path;
  if (!path || item.type === "dir") return;
  const name = item.name || String(path).split("/").pop() || path;
  if (
    !window.confirm(
      `Delete ${name}?\n\nThis commits a deletion to main and cannot be undone from Studio.`
    )
  ) {
    return;
  }
  clearError();
  state.mediaBusy = true;
  state.status = `Deleting ${path}…`;
  render();
  try {
    let sha = item.sha || null;
    if (!sha) {
      const data = await api.getFile(path);
      sha = data.sha;
    }
    await api.deleteFile({
      path,
      sha,
      message: `studio: delete ${path}`,
    });
    state.mediaBusy = false;
    state.status = `Deleted ${path}`;
    await openMediaDir(state.mediaPath, opts);
  } catch (err) {
    state.mediaBusy = false;
    captureError(err);
    render();
  }
}

export async function openMediaDir(dirPath, opts) {
  const { api, state, render, captureError, clearError } = opts;
  clearError();
  state.mediaPath = dirPath || MEDIA_ROOT;
  state.mediaLoading = true;
  state.mediaBusy = false;
  state.status = `Loading ${state.mediaPath}…`;
  render();
  try {
    const data = await api.listMedia(state.mediaPath);
    state.mediaItems = data.items || [];
    state.mediaPath = data.path || state.mediaPath;
    state.mediaLoading = false;
    const dirs = state.mediaItems.filter((i) => i.type === "dir").length;
    const files = state.mediaItems.filter((i) => i.type === "file").length;
    state.status = `${dirs} folders · ${files} files`;
  } catch (err) {
    state.mediaItems = [];
    state.mediaLoading = false;
    captureError(err);
  }
  render();
}

async function createFolder(opts) {
  const { api, state, render, captureError, clearError } = opts;
  const raw = window.prompt("New folder name (letters, numbers, .-_)");
  if (raw == null) return;
  const name = sanitizeFolderName(raw);
  if (!name) {
    state.error = "Invalid folder name";
    state.status = "";
    render();
    return;
  }
  const path = `${state.mediaPath || MEDIA_ROOT}/${name}`;
  clearError();
  state.mediaBusy = true;
  state.status = `Creating ${name}…`;
  render();
  try {
    await api.createMediaFolder({
      path,
      message: `studio: mkdir ${path}`,
    });
    state.mediaBusy = false;
    state.status = `Created ${toPublicPath(path) || path}`;
    await openMediaDir(state.mediaPath, opts);
  } catch (err) {
    state.mediaBusy = false;
    captureError(err);
    render();
  }
}

async function uploadFiles(files, opts) {
  const { api, state, render, captureError, clearError } = opts;
  clearError();
  const dir = state.mediaPath || MEDIA_ROOT;
  let ok = 0;
  state.mediaBusy = true;

  for (const file of files) {
    const name = sanitizeUploadName(file.name);
    if (!name) {
      state.error = `Skipped invalid name: ${file.name}`;
      continue;
    }
    if (file.size > MAX_UPLOAD_BYTES) {
      state.error = `${name} exceeds ${formatBytes(MAX_UPLOAD_BYTES)} (GitHub Contents API soft limit in Studio)`;
      continue;
    }
    state.status = `Uploading ${name}…`;
    render();
    try {
      const content_base64 = await fileToBase64(file);
      const path = `${dir}/${name}`;
      const result = await api.uploadMedia({
        path,
        content_base64,
        message: `studio: upload ${path}`,
      });
      ok += 1;
      state.status = `Uploaded ${result.public_path || toPublicPath(path)}`;
    } catch (err) {
      captureError(err);
      state.mediaBusy = false;
      render();
      return;
    }
  }

  state.mediaBusy = false;
  if (ok) state.status = ok === 1 ? state.status : `Uploaded ${ok} files`;
  await openMediaDir(dir, opts);
}
