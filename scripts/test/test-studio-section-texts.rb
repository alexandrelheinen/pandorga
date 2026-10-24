#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-50. Section texts in Studio (docs/features/studio-section-texts.md).
#
# Each check names the acceptance item it covers (50.1 … 50.8). Pass item
# numbers to run a subset: `ruby scripts/test/test-studio-section-texts.rb 1 2`.
# Source-level gate: it reads the schema as YAML, the runtime and the Liquid
# templates as text, and runs `headerText`, the two hydrators (on a stub DOM)
# and Studio's `pruneEmptyFields` under Node when Node is
# present. Absent key -> theme default; empty string -> nothing rendered.

require "pathname"
require "set"
require "yaml"
require "date"
require "open3"
require "json"

ROOT = Pathname.new(__dir__).join("../..").expand_path
ONLY_ITEMS = ARGV.map { |a| a.sub(/\A(PLT-AC-)?50\./, "") }.to_set

$failures = []

def item(id)
  return if !ONLY_ITEMS.empty? && !ONLY_ITEMS.include?(id.to_s)

  @item = id
  yield
end

def fail!(msg)
  $failures << "FAIL PLT-AC-50.#{@item}: #{msg}"
end

def read(rel)
  path = ROOT.join(rel)
  return path.read if path.file?

  fail!("#{rel} is missing")
  ""
end

def strip_js_comments(text)
  text.gsub(%r{/\*.*?\*/}m, "").gsub(%r{^\s*//.*$}, "")
end

def strip_liquid_comments(text)
  text.gsub(/\{%-?\s*comment\s*-?%\}.*?\{%-?\s*endcomment\s*-?%\}/m, "")
end

# Body of `function name(...) { ... }`, braces matched outside strings.
def js_function(source, name)
  start = source.index(/function\s+#{Regexp.escape(name)}\s*\(/)
  return nil unless start

  open_at = source.index("{", start)
  return nil unless open_at

  depth = 0
  quote = nil
  i = open_at
  while i < source.length
    c = source[i]
    if quote
      i += 1 if c == "\\"
      quote = nil if c == quote
    elsif c == "'" || c == '"' || c == "`"
      quote = c
    elsif c == "{"
      depth += 1
    elsif c == "}"
      depth -= 1
      return source[start..i] if depth.zero?
    end
    i += 1
  end
  nil
end

def node_available?
  return @node_available unless @node_available.nil?

  out, = Open3.capture2e("node", "--version")
  @node_available = !out.to_s.strip.empty?
rescue StandardError
  @node_available = false
end

# Runs `script` under Node; returns [ok, output]. nil when Node is missing.
def run_node(script)
  unless node_available?
    warn "test-studio-section-texts: node not found; item #{@item} runtime cases skipped"
    return nil
  end
  out, status = Open3.capture2e("node", "-e", script)
  [status.success?, out.strip]
end

# Liquid: a field-backed text is replaced only when its key is not nil, never
# through `| default:` (default treats "" as absent).
def liquid_nil_override?(src, var, expr)
  src.match?(/\{%-?\s*if #{Regexp.escape(expr)} != nil\s*-?%\}\s*\{%-?\s*assign #{Regexp.escape(var)} = #{Regexp.escape(expr)} \| strip\s*-?%\}/)
end

# 50.1 Schema --------------------------------------------------------------------
PAGE_FIELDS = {
  "page_projects" => %w[title kicker note cta others_kicker others_title repositories_kicker repositories_title accent tags],
  "page_articles" => %w[cta],
  "page_rascunhos" => %w[cta],
  "page_sources" => %w[note cta],
  "page_network" => %w[note cta],
  "page_bibliography" => %w[cta],
  "page_cv" => %w[summary_title experience_title products_title education_title languages_title timeline_title contact_label]
}.freeze

# Fields held to the new-field rules (string, optional, described, keep_empty).
# The bibliography note already exists but follows the same rule.
NEW_FIELDS = {
  "page_projects" => %w[cta others_kicker others_title repositories_kicker repositories_title],
  "page_articles" => %w[cta],
  "page_rascunhos" => %w[cta],
  "page_sources" => %w[note cta],
  "page_network" => %w[note cta],
  "page_bibliography" => %w[note cta],
  "page_cv" => %w[summary_title experience_title products_title education_title languages_title timeline_title contact_label]
}.freeze

def check_new_field(where, field)
  fail!("#{where}.#{field['name']} must be type string") unless field["type"].to_s == "string"
  fail!("#{where}.#{field['name']} must not be required") if field["required"]
  fail!("#{where}.#{field['name']} needs a description") if field["description"].to_s.strip.empty?
  fail!("#{where}.#{field['name']} must set keep_empty: true so an emptied field saves as \"\"") unless field["keep_empty"] == true
end

item(1) do
  schema = YAML.safe_load(read("studio/schema.yml"), permitted_classes: [Date]) || {}
  pages = Array(schema["content"]).find { |g| g.is_a?(Hash) && g["name"] == "pages" }
  if pages.nil?
    fail!("studio/schema.yml has no pages group")
  else
    items = Array(pages["items"]).to_h { |i| [i["name"], i] }
    projects = items["page_projects"]
    if projects
      fail!("page_projects must edit content/pages/headers.yml") unless projects["path"] == "content/pages/headers.yml"
      fail!("page_projects must be format yaml") unless projects["format"] == "yaml"
      fail!("page_projects must use root_key projects") unless projects["root_key"] == "projects"
      fail!("page_projects must be a file item") unless projects["type"] == "file"
    end
    PAGE_FIELDS.each do |name, wanted|
      entry = items[name]
      unless entry
        fail!("pages group has no #{name}")
        next
      end
      fields = Array(entry["fields"]).to_h { |f| [f["name"], f] }
      wanted.each { |f| fail!("#{name} has no #{f} field") unless fields.key?(f) }
      NEW_FIELDS.fetch(name, []).each { |f| check_new_field(name, fields[f]) if fields[f] }
    end
    home = items["page_home"]
    fail!("page_home must keep root_key index") unless home && home["root_key"] == "index"
    fail!("page_home must be labeled 'Home references band'") unless home && home["label"] == "Home references band"
  end

  fragment = YAML.safe_load(read("templates/network/studio.yml"), permitted_classes: [Date]) || {}
  network = Array(fragment["files"]).find { |f| f["name"] == "page_network" }
  if network.nil?
    fail!("templates/network/studio.yml has no page_network file")
  else
    fields = Array(network["fields"]).to_h { |f| [f["name"], f] }
    %w[note cta].each do |f|
      if fields[f]
        check_new_field("templates/network page_network", fields[f])
      else
        fail!("templates/network/studio.yml page_network has no #{f} field")
      end
    end
  end
end

# A minimal DOM for the hydrators: only the members the spec lists.
STUB_DOM_JS = <<~'JS'
  function attrSel(sel) {
    var m = /^\[([a-z-]+)(?:="([^"]*)")?\]$/.exec(sel);
    if (!m) throw new Error('stub DOM supports [attr] and [attr="v"] only, got ' + sel);
    return function (el) { return el.hasAttribute(m[1]) && (m[2] === undefined || el.getAttribute(m[1]) === m[2]); };
  }
  function El(tag, attrs, kids) {
    this.tagName = tag.toUpperCase();
    this.attrs = Object.assign({}, attrs || {});
    this.kids = [];
    this.parentElement = null;
    this._text = '';
    this.hidden = 'hidden' in this.attrs;
    var self = this;
    this.classList = { remove: function () {}, add: function () {}, contains: function () { return false; } };
    (kids || []).forEach(function (k) {
      if (typeof k === 'string') self._text += k; else { k.parentElement = self; self.kids.push(k); }
    });
  }
  El.prototype.getAttribute = function (n) { return n in this.attrs ? this.attrs[n] : null; };
  El.prototype.hasAttribute = function (n) { return n in this.attrs; };
  El.prototype.setAttribute = function (n, v) { this.attrs[n] = String(v); };
  El.prototype.removeAttribute = function (n) { delete this.attrs[n]; };
  Object.defineProperty(El.prototype, 'childElementCount', { get: function () { return this.kids.length; } });
  Object.defineProperty(El.prototype, 'children', { get: function () { return this.kids.slice(); } });
  Object.defineProperty(El.prototype, 'firstElementChild', { get: function () { return this.kids[0] || null; } });
  Object.defineProperty(El.prototype, 'textContent', {
    get: function () { return this._text + this.kids.map(function (k) { return k.textContent; }).join(''); },
    set: function (v) { this.kids = []; this._text = String(v); }
  });
  Object.defineProperty(El.prototype, 'innerHTML', {
    get: function () { return this._text + this.kids.map(function (k) { return k.innerHTML; }).join(''); },
    set: function (v) { this.kids = []; this._text = String(v); }
  });
  El.prototype.remove = function () {
    if (!this.parentElement) return;
    var p = this.parentElement;
    p.kids = p.kids.filter(function (k) { return k !== this; }, this);
    this.parentElement = null;
  };
  El.prototype.querySelectorAll = function (sel) {
    var test = attrSel(sel), out = [];
    (function walk(n) { n.kids.forEach(function (k) { if (test(k)) out.push(k); walk(k); }); })(this);
    return out;
  };
  El.prototype.querySelector = function (sel) { return this.querySelectorAll(sel)[0] || null; };
  El.prototype.closest = function (sel) {
    var test = attrSel(sel);
    for (var n = this; n; n = n.parentElement) if (test(n)) return n;
    return null;
  };
  El.prototype.contains = function (other) {
    for (var n = other; n; n = n.parentElement) if (n === this) return true;
    return false;
  };
  function h(tag, attrs, kids) { return new El(tag, attrs, kids); }
  function parseInlineMarkdown(s) { return String(s); }
  function stripSingleParagraph(s) { return String(s); }
  var HEADERS = null;
  var FETCH_FAILS = false;
  var FETCHES = 0;
  function loadPageHeaders() {
    FETCHES += 1;
    return FETCH_FAILS ? Promise.reject(new Error('offline')) : Promise.resolve(HEADERS || {});
  }
  console.error = function () {};
  function page() {
    var root = h('body', {}, [
      h('div', { 'data-content-header-wrap': '', id: 'aside' }, [
        h('a', { id: 'band-link' }, [h('span', { 'data-content-header-text': 'blog.cta', id: 'band-cta' }, ['View all'])])
      ]),
      h('article', { 'data-content-header-name': '', id: 'panel' }, [
        h('div', { 'data-content-header-group': '', id: 'head' }, [
          h('h3', { 'data-content-header-text': 'network.title', id: 'panel-title' }, ['Network']),
          h('a', { 'data-content-header-wrap': '', id: 'panel-link' }, [h('span', { 'data-content-header-text': 'network.cta', id: 'panel-cta' }, ['Open'])])
        ]),
        h('p', { 'data-content-panel-note': 'network', hidden: '', id: 'note' }, []),
        h('p', { 'data-content-panel-note': 'resources', id: 'built-note' }, ['Built note'])
      ]),
      h('section', { 'data-content-header-name': '', id: 'cv' }, [
        h('div', { id: 'cv-rail' }, [
          h('div', { 'data-content-header-wrap': '', id: 'cv-head' }, [
            h('h2', { 'data-content-header-text': 'cv.summary_title', id: 'cv-title' }, ['Summary']),
            h('span', { 'aria-hidden': 'true', id: 'cv-rule' }, [])
          ])
        ])
      ]),
      h('section', { 'data-content-header-name': '', 'aria-labelledby': 'x', id: 'named' }, [
        h('h2', { 'data-content-header-text': 'cv.experience_title', id: 'named-title' }, ['Experience'])
      ])
    ]);
    return root;
  }
  function byId(root, id) { return root.querySelectorAll('[id="' + id + '"]')[0] || null; }
JS

HYDRATOR_CASES_JS = <<~'JS'
  var fails = [];
  function expect(cond, msg) { if (!cond) fails.push(msg); }
  function run(headers, failFetch) {
    HEADERS = headers; FETCH_FAILS = !!failFetch;
    var root = page();
    return hydrateHeaderTexts(root).then(function () { return hydratePanelNotes(root); }).then(function () { return root; });
  }
  (async function () {
    // Nothing to fill: no fetch.
    FETCHES = 0;
    await hydrateHeaderTexts(h('body', {}, [h('p', {}, ['x'])]));
    await hydratePanelNotes(h('body', {}, [h('p', {}, ['x'])]));
    expect(FETCHES === 0, 'hydrators fetched with no slot under root');

    // Absent keys: built text stays, empty note goes, built note goes too.
    var r = await run({ blog: {}, network: { cta: null }, cv: { summary_title: 7 } });
    expect(byId(r, 'band-cta') && byId(r, 'band-cta').textContent === 'View all', 'absent blog.cta must keep "View all"');
    expect(byId(r, 'panel-title') && byId(r, 'panel-title').textContent === 'Network', 'absent network.title must keep the built title');
    expect(byId(r, 'panel-cta') && byId(r, 'panel-cta').textContent === 'Open', 'null network.cta must keep "Open"');
    expect(byId(r, 'cv-title') && byId(r, 'cv-title').textContent === 'Summary', 'non-string cv.summary_title must keep "Summary"');
    expect(byId(r, 'cv-rule'), 'a CV heading that stays must keep its rule');
    expect(!byId(r, 'note'), 'absent network.note must remove the note');
    expect(!byId(r, 'built-note'), 'absent resources.note must remove the note');
    expect(!byId(r, 'panel').hasAttribute('aria-label'), 'a panel that keeps its title must not get aria-label');

    // Values: filled and trimmed, note unhidden.
    r = await run({ blog: { cta: ' Ver todos ' }, network: { title: '*Network* of Ideas', cta: 'Go', note: 'A map.' }, cv: { summary_title: 'Resumo' } });
    expect(byId(r, 'band-cta').innerHTML === 'Ver todos', 'blog.cta must fill "Ver todos", got ' + byId(r, 'band-cta').innerHTML);
    expect(byId(r, 'panel-title').innerHTML === '*Network* of Ideas', 'network.title must fill the panel title');
    expect(byId(r, 'panel-cta').innerHTML === 'Go', 'network.cta must fill the link label');
    expect(byId(r, 'cv-title').innerHTML === 'Resumo', 'cv.summary_title must fill the heading');
    var note = byId(r, 'note');
    expect(note && note.innerHTML === 'A map.' && note.hidden === false, 'network.note must fill and unhide the note');

    // Empty values: element and wrapper gone, heading name kept.
    r = await run({ blog: { cta: '' }, network: { title: '  ', cta: '' }, cv: { summary_title: '', experience_title: '' } });
    expect(!byId(r, 'aside') && !byId(r, 'band-link') && !byId(r, 'band-cta'), 'empty blog.cta must remove the whole band aside');
    expect(!byId(r, 'panel-title'), 'empty network.title must remove the panel title');
    expect(!byId(r, 'panel-link'), 'empty network.cta must remove the whole link');
    expect(!byId(r, 'head'), 'a panel head left with no child must be removed');
    expect(byId(r, 'panel') && byId(r, 'panel').getAttribute('aria-label') === 'Network', 'a panel whose title is hidden must keep "Network" as aria-label');
    expect(!byId(r, 'cv-title'), 'empty cv.summary_title must remove the heading');
    expect(!byId(r, 'cv-rule') && byId(r, 'cv-rail'), 'empty cv.summary_title must remove the rule with its head, keeping the rail');
    expect(byId(r, 'cv') && byId(r, 'cv').getAttribute('aria-label') === 'Summary', 'a CV section whose heading is hidden must get aria-label "Summary"');
    expect(byId(r, 'named') && !byId(r, 'named').hasAttribute('aria-label'), 'a region named by aria-labelledby must not get aria-label');
    expect(!byId(r, 'named-title'), 'empty cv.experience_title must remove the heading');

    // Only the title empty: the head stays with the link.
    r = await run({ network: { title: '', cta: 'Go' } });
    expect(byId(r, 'head') && byId(r, 'panel-link') && !byId(r, 'panel-title'), 'empty title with a link must keep the head and the link');

    // Fetch failure: everything as built, empty notes removed, built note kept.
    r = await run({}, true);
    expect(byId(r, 'band-cta') && byId(r, 'band-cta').textContent === 'View all', 'fetch failure must keep the built link label');
    expect(byId(r, 'panel-title') && byId(r, 'cv-title'), 'fetch failure must keep the built headings');
    expect(!byId(r, 'note'), 'fetch failure must remove an empty note');
    expect(byId(r, 'built-note') && byId(r, 'built-note').textContent === 'Built note', 'fetch failure must keep a note that has text');

    if (fails.length) { console.log(fails.join(' | ')); process.exit(1); }
  })().catch(function (e) { console.log('threw: ' + (e && e.stack || e)); process.exit(1); });
JS

# 50.2 Runtime -------------------------------------------------------------------
item(2) do
  fragments = strip_js_comments(read("_includes/content-runtime/60-fragments.html"))
  bootstrap = strip_js_comments(read("_includes/content-runtime/90-bootstrap.html"))

  texts = js_function(fragments, "hydrateHeaderTexts")
  if texts.nil?
    fail!("60-fragments.html defines no hydrateHeaderTexts(root)")
  else
    fail!("hydrateHeaderTexts must select [data-content-header-text]") unless texts.include?("data-content-header-text")
    fail!("hydrateHeaderTexts must read the page headers") unless texts.include?("loadPageHeaders(")
    %w[parseInlineMarkdown stripSingleParagraph].each do |fn|
      fail!("hydrateHeaderTexts must render through #{fn}") unless texts.include?(fn)
    end
    fail!("hydrateHeaderTexts must remove an element whose field is empty") unless texts.match?(/\.remove\(\)/)
    %w[data-content-header-wrap data-content-header-group data-content-header-name aria-label].each do |hook|
      fail!("hydrateHeaderTexts must handle #{hook}") unless texts.include?(hook)
    end
  end

  notes = js_function(fragments, "hydratePanelNotes")
  if notes.nil?
    fail!("60-fragments.html defines no hydratePanelNotes(root)")
  else
    fail!("hydratePanelNotes must select [data-content-panel-note]") unless notes.include?("data-content-panel-note")
    fail!("hydratePanelNotes must read the page headers") unless notes.include?("loadPageHeaders(")
    fail!("hydratePanelNotes must remove a blank note") unless notes.match?(/\.remove\(\)/)
    fail!("hydratePanelNotes must unhide a filled note") unless notes.match?(/hidden\s*=\s*false|removeAttribute\(\s*['"]hidden['"]\s*\)/)
    %w[parseInlineMarkdown stripSingleParagraph].each do |fn|
      fail!("hydratePanelNotes must render through #{fn}") unless notes.include?(fn)
    end
  end

  boot = js_function(fragments, "hydratePageFragments")
  if boot.nil?
    fail!("60-fragments.html lost hydratePageFragments")
  else
    tail = boot[(boot.index("hydrateHomeSections(") || 0)..] || ""
    fail!("hydratePageFragments must call hydrateHeaderTexts") unless boot.include?("hydrateHeaderTexts(")
    fail!("hydratePageFragments must call hydratePanelNotes") unless boot.include?("hydratePanelNotes(")
    unless boot.include?("hydrateHomeSections(") && tail.include?("hydrateHeaderTexts(") && tail.include?("hydratePanelNotes(")
      fail!("hydrateHeaderTexts and hydratePanelNotes must run alongside hydrateHomeSections, after the page headers")
    end
  end

  %w[loadPageHeaders hydrateHeaderTexts headerText].each do |name|
    fail!("90-bootstrap.html must export #{name}") unless bootstrap.match?(/\b#{name}\s*:\s*#{name}\b/)
  end

  helper = js_function(fragments, "headerText")
  if helper.nil?
    fail!("60-fragments.html defines no headerText(headers, key, field, fallback)")
  else
    # Absent, null or non-string -> fallback; a string -> trimmed, "" included.
    cases = [
      [{ "projects" => { "others_title" => "  Mine  " } }, "projects", "others_title", "Other projects", "Mine"],
      [{ "projects" => { "others_title" => "   " } }, "projects", "others_title", "Other projects", ""],
      [{ "projects" => { "others_title" => "" } }, "projects", "others_title", "Other projects", ""],
      [{ "projects" => { "others_title" => nil } }, "projects", "others_title", "Other projects", "Other projects"],
      [{ "projects" => {} }, "projects", "others_title", "Other projects", "Other projects"],
      [{ "projects" => "x" }, "projects", "others_title", "Other projects", "Other projects"],
      [{}, "projects", "others_title", "Other projects", "Other projects"],
      [nil, "projects", "others_title", "Other projects", "Other projects"],
      [{ "cv" => { "summary_title" => 3 } }, "cv", "summary_title", "Summary", "Summary"],
      [{ "cv" => { "summary_title" => ["x"] } }, "cv", "summary_title", "Summary", "Summary"],
      [{ "cv" => {} }, "cv", "summary_title", nil, nil]
    ]
    script = "#{helper}\nconst cases = #{JSON.generate(cases)};\n" \
             "const bad = cases.filter(c => headerText(c[0], c[1], c[2], c[3]) !== c[4]);\n" \
             "if (bad.length) { console.log(JSON.stringify(bad)); process.exit(1); }\n"
    ok, out = run_node(script)
    fail!("headerText returned the wrong value for #{out}") if ok == false
  end

  # Behavior of the two hydrators on a stub DOM (absent -> built text kept,
  # value -> filled, empty -> removed with its wrapper, heading name kept).
  if helper && texts && notes
    ok, out = run_node(<<~JS)
      #{STUB_DOM_JS}
      #{helper}
      #{texts}
      #{notes}
      #{HYDRATOR_CASES_JS}
    JS
    fail!("hydrators on the stub DOM: #{out}") if ok == false
  end
end

# 50.3 Home band call to action --------------------------------------------------
item(3) do
  band = strip_liquid_comments(read("_includes/home/band-listing.html"))
  fail!("band-listing CTA has no data-content-header-text=\"{{ band.section_key }}.cta\"") unless band.include?('data-content-header-text="{{ band.section_key }}.cta"')
  fail!("band-listing CTA must read page_headers[band.section_key].cta") unless band.match?(/page_headers\[band\.section_key\]/) && band.include?("_section.cta")
  fail!("band-listing CTA must still fall back to band.home.cta, then \"View all\"") unless band.match?(/assign _cta = band\.home\.cta \| default: "View all"/)
  fail!("band-listing must not pass _section.cta through | default: (an empty cta must hide the link)") if band.match?(/_section\.cta\s*\|\s*default/)
  fail!("band-listing CTA must take _section.cta (stripped) only when it is not nil") unless liquid_nil_override?(band, "_cta", "_section.cta")
  default_at = band.index("assign _cta = band.home.cta")
  override_at = band.index("if _section.cta != nil")
  fail!("band-listing must assign the default before the headers override") unless default_at && override_at && default_at < override_at
  fail!("band-listing must render .home-section-aside only when _cta is not empty") unless band.match?(/\{%-?\s*if _cta != ""\s*-?%\}\s*<div class="home-section-aside" data-content-header-wrap>/)
end

# 50.4 Home panels ---------------------------------------------------------------
item(4) do
  band = strip_liquid_comments(read("_includes/home/band-index.html"))
  fail!("panel title has no data-content-header-text=\"{{ panel.key }}.title\"") unless band.match?(/<h3 class="home-index-title"[^>]*data-content-header-text="\{\{ panel\.key \}\}\.title"/)
  fail!("panel title must read page_headers[panel.key].title") unless band.match?(/page_headers\[panel\.key\]/) && band.match?(/\.title\b/)
  fail!("Open label has no data-content-header-text=\"{{ panel.key }}.cta\"") unless band.include?('data-content-header-text="{{ panel.key }}.cta"')
  fail!("Open label must default to \"Open\"") unless band.match?(/"Open"|>Open</)
  fail!("band-index must not pass panel headers through | default: (empty must hide)") if band.match?(/_panel_head\.(title|cta|note)\s*\|\s*default/)
  fail!("panel title must take _panel_head.title (stripped) only when it is not nil") unless liquid_nil_override?(band, "_panel_title", "_panel_head.title")
  fail!("panel Open label must take _panel_head.cta (stripped) only when it is not nil") unless liquid_nil_override?(band, "_panel_cta", "_panel_head.cta")
  fail!("panel title h3 must render only when _panel_title is not empty") unless band.match?(/\{%-?\s*if _panel_title != ""\s*-?%\}\s*<h3 class="home-index-title"/)
  fail!("panel Open link must render only when _panel_cta is not empty, with data-content-header-wrap") unless band.match?(/\{%-?\s*if _panel_cta != ""\s*-?%\}\s*<a class="ledger-cta"[^>]*data-content-header-wrap/)
  fail!("panel head must render only when the title or the link is not empty") unless band.match?(/\{%-?\s*if _panel_title != "" or _panel_cta != ""\s*-?%\}\s*<div class="home-index-panel-head" data-content-header-group>/)
  article = band[/<article class="home-index-panel"[^>]*>/m].to_s
  fail!("article.home-index-panel must carry data-content-header-name") unless article.include?("data-content-header-name")
  fail!("article.home-index-panel must carry aria-label when its title is empty") unless article.match?(/\{%\s*if _panel_title == ""\s*%\}\s*aria-label="/)

  note_at = band.index('data-content-panel-note="{{ panel.key }}"')
  head_at = band.index("home-index-panel-head")
  plate_at = band.index("home-index-plate")
  if note_at.nil?
    fail!("panel has no <p class=\"home-index-note font-body\" data-content-panel-note=\"{{ panel.key }}\">")
  else
    tag = band[band.rindex("<", note_at)..band.index(">", note_at)]
    fail!("panel note must be p.home-index-note.font-body") unless tag.start_with?("<p") && tag.include?("home-index-note") && tag.include?("font-body")
    fail!("panel note must be hidden when empty") unless tag.include?("hidden")
    fail!("panel note must come after .home-index-panel-head") unless head_at && head_at < note_at
    plate_after_head = head_at && band.index("home-index-plate", head_at)
    fail!("panel note must come before figure.home-index-plate") unless plate_at && plate_after_head && note_at < plate_after_head
    fail!("panel note must be prefilled from page_headers[panel.key].note") unless band.match?(/\.note\b/)
  end

  css = read("assets/css/ledger/home.css").gsub(%r{/\*.*?\*/}m, "")
  # A panel with an empty title keeps its link on the right, as with a title.
  cta_right = css.scan(/([^{}]*)\{([^{}]*)\}/).any? do |sel, body|
    sel.split(",").any? { |s| s.strip.match?(/\A\.home-index-panel-head\s*>?\s*\.ledger-cta\z/) } &&
      body.match?(/margin-(left|inline-start)\s*:\s*auto\b/)
  end
  fail!("home.css must right-align the panel link on its own (.home-index-panel-head > .ledger-cta { margin-left: auto })") unless cta_right
  rules = css.scan(/([^{}]*\.home-index-note[^{}]*)\{([^{}]*)\}/)
  fail!("home.css has no .home-index-note rule") if rules.empty?
  rules.each do |sel, body|
    fail!("#{sel.strip} uses a color literal") if body.match?(/#[0-9a-fA-F]{3,8}\b|rgba?\(|hsla?\(/)
    fail!("#{sel.strip} uses !important") if body.include?("!important")
  end
end

# 50.5 Projects page banners -----------------------------------------------------
item(5) do
  page = strip_js_comments(read("_layouts/projects.html"))
  fail!("projects.html must load the headers with runtime.loadPageHeaders()") unless page.include?("runtime.loadPageHeaders(")
  {
    "others_kicker" => "Index", "others_title" => "Other projects",
    "repositories_kicker" => "Open source", "repositories_title" => "Repositories"
  }.each do |field, default|
    pattern = /runtime\.headerText\([^;]*?['"]#{field}['"]\s*,\s*['"]#{Regexp.escape(default)}['"]\s*\)/m
    fail!("projects.html must build #{field} with runtime.headerText(..., '#{field}', '#{default}')") unless page.match?(pattern)
  end
  fail!("projects.html must give section.projects-repos aria-label \"Repositories\" when its title is empty") unless page.match?(/projects-repos[^\n]*aria-label=[^\n]*Repositories/)
  page.scan(/renderSectionBanner\(\{([^}]*)\}/m).each do |(args)|
    if args.match?(/\b(kicker|title)\s*:\s*['"]/)
      fail!("projects.html passes a literal kicker or title to renderSectionBanner: #{args.strip.gsub(/\s+/, ' ')}")
    end
  end
end

# 50.6 CV labels -----------------------------------------------------------------
item(6) do
  box = strip_liquid_comments(read("_includes/cv/cv-box.html"))
  unless box.match?(/<h2 class="section-title cv-register-title"[^>]*\{%-?\s*if include\.text_key\s*-?%\}\s*data-content-header-text="\{\{ include\.text_key \}\}"/)
    fail!("cv-box.html must put include.text_key on h2.cv-register-title as data-content-header-text")
  end
  fail!("cv-box.html must render the h2 only when include.title is not empty") unless box.match?(/\{%-?\s*if include\.title != ""\s*-?%\}\s*(<div class="cv-register-head" data-content-header-wrap>\s*)?<h2 class="section-title cv-register-title"/)
  # An empty title drops the decorative rule with the heading, at build time
  # and when the runtime removes the heading (they share one header wrap).
  head = box[/\{%-?\s*if include\.title != ""\s*-?%\}(.*?)^\s*\{%-?\s*endif\s*-?%\}/m, 1].to_s
  unless head.match?(/\A\s*<div class="cv-register-head" data-content-header-wrap>\s*<h2 class="section-title cv-register-title".*?<\/h2>\s*<span class="cv-register-rule" aria-hidden="true"><\/span>\s*<\/div>\s*\z/m)
    fail!("cv-box.html must wrap the h2 and span.cv-register-rule in div.cv-register-head[data-content-header-wrap] rendered only when include.title is not empty")
  end
  fail!("cv-box.html must render span.cv-register-rule only inside the title block") unless box.scan("cv-register-rule").size == 1
  section = box[/<section class="cv-register"[^>]*>/m].to_s
  fail!("section.cv-register must carry data-content-header-name") unless section.include?("data-content-header-name")
  fail!("section.cv-register must carry aria-label=\"{{ include.label }}\" when include.title is empty") unless section.match?(/\{%\s*if include\.title == ""\s*%\}\s*aria-label="\{\{ include\.label \}\}"/)

  cv = strip_liquid_comments(read("_layouts/cv.html"))
  fail!("cv.html must read the CV headers from site.data.page_headers[page.key]") unless cv.include?("site.data.page_headers[page.key]")
  fail!("cv.html must not pass CV header fields through | default: (empty must hide)") if cv.match?(/_cv_head\.\w+\s*\|\s*default/)
  { "summary" => "Summary", "experience" => "Experience", "products" => "Products",
    "education" => "Education", "languages" => "Languages" }.each do |name, default|
    fail!("cv.html must default _#{name}_title to \"#{default}\"") unless cv.match?(/assign _#{name}_title = "#{default}"/)
    fail!("cv.html must take #{name}_title (stripped) only when it is not nil") unless liquid_nil_override?(cv, "_#{name}_title", "_cv_head.#{name}_title")
    include_tag = cv[/\{%\s*include cv\/cv-box\.html id="#{name}"[^%]*%\}/]
    if include_tag.nil?
      fail!("cv.html lost the #{name} cv-box include")
    else
      fail!("cv-box #{name} must pass a text_key ending in .#{name}_title") unless include_tag.match?(/text_key=\S*#{name}_title/)
      fail!("cv-box #{name} must not pass the literal title \"#{default}\"") if include_tag.include?("title=\"#{default}\"")
      fail!("cv-box #{name} must pass label=\"#{default}\"") unless include_tag.include?("label=\"#{default}\"")
    end
  end
  fail!("cv.html Contact label must carry data-content-header-text=\"{{ page.key }}.contact_label\"") unless cv.match?(/data-content-header-text="\{\{ page\.key \}\}\.contact_label"[^>]*>[^<]*(Contact|contact_label)/m)
  fail!("cv.html must default _contact_label to \"Contact\" and take contact_label only when not nil") unless cv.match?(/assign _contact_label = "Contact"/) && liquid_nil_override?(cv, "_contact_label", "_cv_head.contact_label")
  fail!("cv.html must render the Contact label only when it is not empty") unless cv.match?(/\{%-?\s*if _contact_label != ""\s*-?%\}\s*<span class="cv-contact-cta-label"/)

  timeline = strip_liquid_comments(read("_includes/page/timeline-section.html"))
  unless timeline.match?(/<h2 class="section-title"[^>]*data-content-header-text="\{\{ page\.key \}\}\.timeline_title"[^>]*>[^<]*(Timeline|timeline_title)/m)
    fail!("timeline-section.html heading must carry data-content-header-text=\"{{ page.key }}.timeline_title\" with Timeline as default")
  end
  fail!("timeline-section.html must not pass timeline_title through | default:") if timeline.match?(/timeline_title\s*\|\s*default/)
  fail!("timeline-section.html must default _timeline_title to \"Timeline\" and take timeline_title only when not nil") unless timeline.match?(/assign _timeline_title = "Timeline"/) && timeline.match?(/\{%-?\s*if [\w.\[\]]+\.timeline_title != nil\s*-?%\}\s*\{%-?\s*assign _timeline_title = [\w.\[\]]+\.timeline_title \| strip\s*-?%\}/)
  fail!("timeline-section.html must render .cv-band-head (data-content-header-wrap) only when the title is not empty") unless timeline.match?(/\{%-?\s*if _timeline_title != ""\s*-?%\}\s*<div class="cv-band-head" data-content-header-wrap>/)
  band = timeline[/<section class="cv-band" id="timeline-section"[^>]*>/m].to_s
  fail!("section#timeline-section must carry data-content-header-name and aria-label=\"Timeline\" when the title is empty") unless band.include?("data-content-header-name") && band.match?(/\{%\s*if _timeline_title == ""\s*%\}\s*aria-label="Timeline"/)
end

# 50.7 Docs and guards -----------------------------------------------------------
item(7) do
  doc = read("docs/pages-and-templates.md")
  %w[cta note others_kicker others_title repositories_kicker repositories_title
     summary_title experience_title products_title education_title languages_title
     timeline_title contact_label].each do |field|
    fail!("docs/pages-and-templates.md does not document headers.yml field `#{field}`") unless doc.include?("`#{field}`")
  end
  fail!("docs/pages-and-templates.md must name content/pages/headers.yml") unless doc.include?("headers.yml")
  fail!("docs/pages-and-templates.md must document `keep_empty`") unless doc.include?("`keep_empty`")
  fail!("docs/pages-and-templates.md must state the absent and empty rule") unless doc.match?(/absent/i) && doc.match?(/empty/i)

  %w[_includes/home/band-listing.html _includes/home/band-index.html _layouts/projects.html
     _layouts/cv.html _includes/cv/cv-box.html _includes/page/timeline-section.html].each do |rel|
    fail!("#{rel} carries an owner-specific string") if read(rel).match?(/Alexandre|Heinen|Loeblein/i)
  end
  home_css = read("assets/css/ledger/home.css").gsub(%r{/\*.*?\*/}m, "")
  fail!("assets/css/ledger/home.css uses !important") if home_css.include?("!important")
end

# 50.8 Studio keeps an emptied field ---------------------------------------------
item(8) do
  yaml_doc = strip_js_comments(read("studio-app/src/lib/yaml-doc.js"))
  prune = js_function(yaml_doc, "pruneEmptyFields")
  if prune.nil?
    fail!("studio-app/src/lib/yaml-doc.js lost pruneEmptyFields")
  else
    fail!("pruneEmptyFields must read keep_empty") unless prune.include?("keep_empty")
    ok, out = run_node(<<~JS)
      #{prune}
      var fields = [
        { name: 'cta', type: 'string', keep_empty: true },
        { name: 'others_title', type: 'string', keep_empty: true },
        { name: 'gone', type: 'string', keep_empty: true },
        { name: 'title', type: 'string' },
        { name: 'tags', type: 'string', list: true }
      ];
      var out = pruneEmptyFields({ cta: '', others_title: '  ', gone: null, title: '', tags: [], extra: '' }, fields);
      var fails = [];
      if (!Object.prototype.hasOwnProperty.call(out, 'cta') || out.cta !== '') fails.push('keep_empty "" must be kept as ""');
      if (out.others_title !== '  ') fails.push('keep_empty whitespace must be kept');
      if (Object.prototype.hasOwnProperty.call(out, 'gone')) fails.push('keep_empty null must be dropped');
      if (Object.prototype.hasOwnProperty.call(out, 'title')) fails.push('a field without keep_empty must still drop ""');
      if (Object.prototype.hasOwnProperty.call(out, 'tags')) fails.push('an empty list must still be dropped');
      if (out.extra !== '') fails.push('unknown keys must be kept');
      var kept = pruneEmptyFields({ cta: 'Ver todos', title: 'T' }, fields);
      if (kept.cta !== 'Ver todos' || kept.title !== 'T') fails.push('values must be kept');
      if (fails.length) { console.log(fails.join(' | ')); process.exit(1); }
    JS
    fail!("pruneEmptyFields: #{out}") if ok == false
  end

  html = read("studio/index.html")
  bundle = html[%r{/studio/assets/(index-[A-Za-z0-9_-]+\.js)}, 1]
  if bundle.nil? || !ROOT.join("studio/assets", bundle).file?
    fail!("studio/index.html does not load a committed bundle")
  elsif !ROOT.join("studio/assets", bundle).read.include?("keep_empty")
    fail!("the committed Studio bundle #{bundle} predates keep_empty; rebuild studio-app")
  end
end

if $failures.empty?
  puts "PLT-AC-50 studio section texts: OK"
else
  puts $failures
  warn "#{$failures.size} PLT-AC-50 check(s) failed"
  exit 1
end
