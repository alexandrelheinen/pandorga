#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-50. Section texts in Studio (docs/features/studio-section-texts.md).
#
# Each check names the acceptance item it covers (50.1 … 50.7). Pass item
# numbers to run a subset: `ruby scripts/test/test-studio-section-texts.rb 1 2`.
# Source-level gate: it reads the schema as YAML, the runtime and the Liquid
# templates as text, and runs `headerText` under Node when Node is present.

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

NEW_FIELDS = {
  "page_projects" => %w[cta others_kicker others_title repositories_kicker repositories_title],
  "page_articles" => %w[cta],
  "page_rascunhos" => %w[cta],
  "page_sources" => %w[note cta],
  "page_network" => %w[note cta],
  "page_bibliography" => %w[cta],
  "page_cv" => %w[summary_title experience_title products_title education_title languages_title timeline_title contact_label]
}.freeze

def check_new_field(where, field)
  fail!("#{where}.#{field['name']} must be type string") unless field["type"].to_s == "string"
  fail!("#{where}.#{field['name']} must not be required") if field["required"]
  fail!("#{where}.#{field['name']} needs a description") if field["description"].to_s.strip.empty?
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
    fail!("hydrateHeaderTexts must keep the built text, not remove the element") if texts.match?(/\.remove\(\)/)
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
    node, = Open3.capture2e("node", "--version") rescue nil
    if node.nil? || node.empty?
      warn "test-studio-section-texts: node not found; headerText cases skipped"
    else
      cases = [
        [{ "projects" => { "others_title" => "  Mine  " } }, "projects", "others_title", "Other projects", "Mine"],
        [{ "projects" => { "others_title" => "   " } }, "projects", "others_title", "Other projects", "Other projects"],
        [{ "projects" => {} }, "projects", "others_title", "Other projects", "Other projects"],
        [{}, "projects", "others_title", "Other projects", "Other projects"],
        [nil, "projects", "others_title", "Other projects", "Other projects"],
        [{ "cv" => { "summary_title" => 3 } }, "cv", "summary_title", "Summary", "Summary"],
        [{ "cv" => { "summary_title" => ["x"] } }, "cv", "summary_title", "Summary", "Summary"]
      ]
      script = "#{helper}\nconst cases = #{JSON.generate(cases)};\n" \
               "const bad = cases.filter(c => headerText(c[0], c[1], c[2], c[3]) !== c[4]);\n" \
               "if (bad.length) { console.log(JSON.stringify(bad)); process.exit(1); }\n"
      out, status = Open3.capture2e("node", "-e", script)
      fail!("headerText returned the wrong value for #{out.strip}") unless status.success?
    end
  end
end

# 50.3 Home band call to action --------------------------------------------------
item(3) do
  band = strip_liquid_comments(read("_includes/home/band-listing.html"))
  fail!("band-listing CTA has no data-content-header-text=\"{{ band.section_key }}.cta\"") unless band.include?('data-content-header-text="{{ band.section_key }}.cta"')
  fail!("band-listing CTA must read page_headers[band.section_key].cta") unless band.match?(/page_headers\[band\.section_key\]|_section\.cta/)
  fail!("band-listing CTA must still fall back to band.home.cta") unless band.include?("band.home.cta")
  fail!("band-listing CTA must still fall back to \"View all\"") unless band.include?('"View all"')
  order = [band.index("_section.cta"), band.index("band.home.cta"), band.index('"View all"')]
  fail!("band-listing CTA default order must be headers cta, then band.home.cta, then \"View all\"") if order.include?(nil) || order != order.sort
end

# 50.4 Home panels ---------------------------------------------------------------
item(4) do
  band = strip_liquid_comments(read("_includes/home/band-index.html"))
  fail!("panel title has no data-content-header-text=\"{{ panel.key }}.title\"") unless band.match?(/<h3 class="home-index-title"[^>]*data-content-header-text="\{\{ panel\.key \}\}\.title"/)
  fail!("panel title must read page_headers[panel.key].title") unless band.match?(/page_headers\[panel\.key\]/) && band.match?(/\.title\b/)
  fail!("Open label has no data-content-header-text=\"{{ panel.key }}.cta\"") unless band.include?('data-content-header-text="{{ panel.key }}.cta"')
  fail!("Open label must default to \"Open\"") unless band.match?(/"Open"|>Open</)

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

  cv = strip_liquid_comments(read("_layouts/cv.html"))
  { "summary" => "Summary", "experience" => "Experience", "products" => "Products",
    "education" => "Education", "languages" => "Languages" }.each do |name, default|
    fail!("cv.html must read #{name}_title from page_headers with default \"#{default}\"") unless cv.match?(/#{name}_title\s*\|\s*default:\s*"#{default}"/)
    include_tag = cv[/\{%\s*include cv\/cv-box\.html id="#{name}"[^%]*%\}/]
    if include_tag.nil?
      fail!("cv.html lost the #{name} cv-box include")
    else
      fail!("cv-box #{name} must pass a text_key ending in .#{name}_title") unless include_tag.match?(/text_key=\S*#{name}_title/)
      fail!("cv-box #{name} must not pass the literal title \"#{default}\"") if include_tag.include?("title=\"#{default}\"")
    end
  end
  fail!("cv.html Contact label must carry data-content-header-text=\"{{ page.key }}.contact_label\"") unless cv.match?(/data-content-header-text="\{\{ page\.key \}\}\.contact_label"[^>]*>[^<]*(Contact|contact_label)/m)

  timeline = strip_liquid_comments(read("_includes/page/timeline-section.html"))
  unless timeline.match?(/<h2 class="section-title"[^>]*data-content-header-text="\{\{ page\.key \}\}\.timeline_title"[^>]*>[^<]*(Timeline|timeline_title)/m)
    fail!("timeline-section.html heading must carry data-content-header-text=\"{{ page.key }}.timeline_title\" with Timeline as default")
  end
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

  %w[_includes/home/band-listing.html _includes/home/band-index.html _layouts/projects.html
     _layouts/cv.html _includes/cv/cv-box.html _includes/page/timeline-section.html].each do |rel|
    fail!("#{rel} carries an owner-specific string") if read(rel).match?(/Alexandre|Heinen|Loeblein/i)
  end
  home_css = read("assets/css/ledger/home.css").gsub(%r{/\*.*?\*/}m, "")
  fail!("assets/css/ledger/home.css uses !important") if home_css.include?("!important")
end

if $failures.empty?
  puts "PLT-AC-50 studio section texts: OK"
else
  puts $failures
  warn "#{$failures.size} PLT-AC-50 check(s) failed"
  exit 1
end
