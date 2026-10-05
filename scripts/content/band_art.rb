# frozen_string_literal: true

# Draws the two plates in the home page's reference band from the real content.
#
# The band sends readers to Sources and to the Network of Ideas, and the brief
# for it asked for abstract illustration. Abstract art that is also *true* is
# better than abstract art that is only decorative, so both plates are
# projections of what the site already publishes:
#
#   sources - one square per entry in the resources collection, packed into the
#             block for its `category` and coloured by `type` from the medium
#             palette the Sources page itself uses. A block's size is its real
#             count.
#
#   network - the same graph `_includes/page/network-graph.html` draws, counted
#             rather than drawn. Same nodes, same two relations: a citation, and
#             a theme two or more entries share, under the same rule that an
#             entry appears only once it is joined to something. The page can
#             afford a force layout and the room to read it; the plate reports
#             the three totals and how the corpus splits between articles and
#             rascunhos.
#
# Nothing here may invent a quantity. Every number a plate prints is counted from
# the content at export time.
#
# This runs inside `export-content-json.rb` rather than as a script of its own
# because the plates went stale otherwise. Cloudflare Pages excludes `content/*`
# from its build watch paths, so a Studio save never rebuilds the shell, and art
# committed into a layout is art that stops counting the day it is written. See
# docs/features/home-band-art.md.
#
# The output is SVG whose every stroke and fill is a custom property, because the
# site has two complete palettes and switches between them on a `data-theme`
# attribute. The browser injects the markup inline for the same reason: an
# external document cannot see `--color-primary`, so an `<img>` would be right in
# one theme and wrong in the other.
module BandArt
  # Plate geometry, shared so the two drawings sit on the same baseline and read
  # as a pair rather than as two unrelated diagrams.
  VIEW_W = 640
  VIEW_H = 240
  PAD_X = 14
  BASELINE = 208
  SPAN = VIEW_W - PAD_X * 2

  # A tag carried by one entry connects that entry to nothing. The graph page
  # sets the same floor, so the two drawings count themes the same way.
  MIN_THEME_USES = 2

  WRITING_COLLECTIONS = %w[articles posts].freeze

  module_function

  # Public entry point. `writing_index` is the export's own index; `resources`
  # is the exported resource payload list. Returns a hash of plate name to SVG.
  def build(writing_index:, resources:)
    graph = idea_graph(writing_index)
    field = source_field(resources)

    {
      "sources" => sources_plate(resources, field),
      "network" => network_plate(graph)
    }
  end

  # ── Reading the content ──────────────────────────────────────────────────

  # The same two edge rules as the network page: an `xcites` key resolves to
  # another keyed entry, self-citations are dropped and a pair counts once; and a
  # theme is a tag two or more entries share. Writing only, since the index also
  # carries projects and products, which the page's legend never names.
  def idea_graph(entries)
    keyed = entries.select do |entry|
      key = entry["key"].to_s
      !key.empty? && WRITING_COLLECTIONS.include?(entry["collection"].to_s)
    end
    by_key = keyed.each_with_object({}) { |entry, acc| acc[entry["key"].to_s] = entry }

    seen = {}
    edges = []
    keyed.each do |entry|
      Array(entry["xcites"]).each do |cite|
        target = by_key[cite.to_s]
        next if target.nil? || target["url"] == entry["url"]

        pair = "#{entry['url']} #{target['url']}"
        next if seen.key?(pair)

        seen[pair] = true
        edges << { source: entry["url"], target: target["url"] }
      end
    end

    uses = Hash.new { |hash, key| hash[key] = [] }
    keyed.each do |entry|
      Array(entry["tags"]).each do |tag|
        name = tag.to_s.strip
        uses[name] << entry["url"] unless name.empty?
      end
    end

    themes = []
    connected = {}
    edges.each do |edge|
      connected[edge[:source]] = true
      connected[edge[:target]] = true
    end
    uses.each do |name, urls|
      next if urls.length < MIN_THEME_USES

      themes << { name: name, uses: urls.length }
      urls.each { |url| connected[url] = true }
    end

    nodes = keyed
            .select { |entry| connected[entry["url"]] }
            .sort_by { |entry| [entry["date"].to_s, entry["url"].to_s] }

    # Themes are ordered by how often the writing returns to them, so the
    # description that lists them opens on the ones that actually hold the
    # corpus together.
    { nodes: nodes,
      edges: edges,
      themes: themes.sort_by { |theme| [-theme[:uses], theme[:name]] },
      corpus: keyed.length,
      articles: nodes.count { |node| node["collection"] == "articles" },
      posts: nodes.count { |node| node["collection"] == "posts" } }
  end

  # ── The idea map ─────────────────────────────────────────────────────────

  # The plate used to draw the whole citation graph: an arc per citation over a
  # rail of entries, a thread per shared theme under it. At the size a home panel
  # gives it, ninety threads and forty arcs resolve into a smudge, and the reader
  # learns nothing the caption above it had not already said. So the graph is
  # reported rather than drawn. The three counts are the art, set large, over one
  # spine that splits the corpus by what kind of writing it is, which is the
  # graph page's own two-colour key and the only quantity here that needs a
  # colour to be read.
  METRIC_VIEW_W = 320
  METRIC_VIEW_H = 120
  METRIC_PAD = 10
  METRIC_COLUMNS = 3
  SPINE_Y = 96
  SPINE_H = 6

  def draw_metric_card(graph)
    return "" if graph[:nodes].empty?

    cells = [
      [graph[:nodes].length, "entries"],
      [graph[:edges].length, "citations"],
      [graph[:themes].length, "themes"]
    ]
    width = (METRIC_VIEW_W - METRIC_PAD * 2).to_f / METRIC_COLUMNS

    parts = cells.each_with_index.map do |(count, label), index|
      x = METRIC_PAD + width * (index + 0.5)
      divider = if index.zero?
                  ""
                else
                  %(<line class="home-index-divider" x1="#{round(METRIC_PAD + width * index)}" y1="12" ) +
                    %(x2="#{round(METRIC_PAD + width * index)}" y2="82" />)
                end
      divider +
        %(<text class="home-index-metric" x="#{round(x)}" y="58" text-anchor="middle">#{count}</text>) +
        %(<text class="home-index-metric-label" x="#{round(x)}" y="78" text-anchor="middle">#{label}</text>)
    end

    parts << draw_spine(graph)
    parts.join
  end

  # One bar, two segments, drawn to scale. A corpus that is mostly rascunhos
  # looks like one, and the day an entry falls out of the graph the bar stops
  # short of the right margin rather than quietly restating a full width.
  def draw_spine(graph)
    span = METRIC_VIEW_W - METRIC_PAD * 2
    scale = span.to_f / [graph[:corpus], 1].max
    articles = graph[:articles] * scale
    posts = graph[:posts] * scale

    %(<line class="home-index-spine-rule" x1="#{METRIC_PAD}" y1="#{SPINE_Y + SPINE_H}" ) +
      %(x2="#{METRIC_VIEW_W - METRIC_PAD}" y2="#{SPINE_Y + SPINE_H}" />) +
      %(<rect class="home-index-spine home-index-spine--articles" x="#{METRIC_PAD}" y="#{SPINE_Y}" ) +
      %(width="#{round(articles)}" height="#{SPINE_H}" />) +
      %(<rect class="home-index-spine home-index-spine--posts" x="#{round(METRIC_PAD + articles)}" ) +
      %(y="#{SPINE_Y}" width="#{round(posts)}" height="#{SPINE_H}" />)
  end

  # ── The source field ─────────────────────────────────────────────────────

  # Medium is a name, not a magnitude, so it gets a colour and nothing else. One
  # square is one source, and the only quantity is how many of them a collection
  # holds, which is a real property of the shelf.
  MEDIA = [
    { type: "youtube", label: "video", legend: "Video" },
    { type: "podcast", label: "podcast", legend: "Podcast" },
    { type: "website", label: "site", legend: "Site" }
  ].freeze

  # A tile and the air around it. Three to a row leaves the largest collection
  # four rows tall, which is the height the plate has once the shelf rules and
  # their labels are paid for.
  UNIT = 32
  UNIT_GAP = 5
  UNITS_PER_ROW = 3
  CELL_W = UNITS_PER_ROW * UNIT + (UNITS_PER_ROW - 1) * UNIT_GAP

  # Shelf labels sit under a ~106px column. At the plate's mono size the long
  # category names overflow; short forms keep the full vocabulary in captions
  # and descriptions while the drawing stays readable.
  COLLECTION_SHORT = {
    "Academic" => "Acad.",
    "Communication" => "Comm.",
    "Humor" => "Humor",
    "Music" => "Music",
    "Professional" => "Prof."
  }.freeze

  def collection_shelf_label(category)
    name = category.to_s
    COLLECTION_SHORT.fetch(name) { name.length <= 6 ? name : "#{name[0, 4]}." }
  end

  # Collections are ranked by how many sources they hold, which the content does
  # say. Inside one, the sources are sorted by medium so the colours block up
  # instead of speckling; nothing in the front matter orders them, so that part is
  # composition rather than a claim.
  def source_field(resources)
    order = MEDIA.each_with_index.to_h { |medium, index| [medium[:type], index] }
    resources
      .group_by { |resource| resource["category"].to_s }
      .map do |category, items|
        { category: category,
          items: items.sort_by { |item| [order.fetch(item["type"].to_s, 9), item["slug"].to_s] } }
      end
      .sort_by { |cluster| [-cluster[:items].length, cluster[:category]] }
  end

  # An empty shelf draws nothing rather than an empty frame, which is the same
  # rule the cards follow: an absent field produces no element. A fixture corpus
  # with no resources reaches here, and so would a freshly emptied collection.
  def draw_source_field(clusters)
    return "" if clusters.empty?

    order = MEDIA.each_with_index.to_h { |medium, index| [medium[:type], index] }
    gutter = clusters.length > 1 ? (SPAN - clusters.length * CELL_W).to_f / (clusters.length - 1) : 0
    tallest = (clusters.first[:items].length / UNITS_PER_ROW.to_f).ceil
    ceiling = BASELINE - UNIT - (tallest - 1) * (UNIT + UNIT_GAP)

    # The plate holds five collections of up to fifteen sources. Growing past
    # either is an editorial event worth noticing, not a rounding error, so say so
    # here rather than silently drawing a clipped or overlapping picture.
    if ceiling.negative?
      raise "band art: the largest collection (#{clusters.first[:category]}, " \
            "#{clusters.first[:items].length}) no longer fits the plate; raise VIEW_H or UNITS_PER_ROW"
    end
    if clusters.length > 1 && gutter < UNIT_GAP
      raise "band art: #{clusters.length} collections no longer fit side by side; lower UNIT or CELL_W"
    end

    parts = []
    clusters.each_with_index do |cluster, cluster_index|
      x0 = PAD_X + cluster_index * (CELL_W + gutter)
      cluster[:items].each_with_index do |resource, index|
        kind = order.key?(resource["type"].to_s) ? resource["type"] : "other"
        x = x0 + (index % UNITS_PER_ROW) * (UNIT + UNIT_GAP)
        y = BASELINE - UNIT - (index / UNITS_PER_ROW) * (UNIT + UNIT_GAP)
        parts << %(<rect class="home-index-unit home-index-unit--#{kind}" ) +
                 %(x="#{round(x)}" y="#{round(y)}" width="#{UNIT}" height="#{UNIT}" />)
      end
      # Every block stands on its own rule and says its own name. Five unlabelled
      # runs of identical squares tell the reader nothing.
      parts << %(<line class="home-index-shelf" x1="#{round(x0)}" y1="#{BASELINE + 7}" ) +
               %(x2="#{round(x0 + CELL_W)}" y2="#{BASELINE + 7}" />)
      parts << %(<text class="home-index-collection" x="#{round(x0 + CELL_W / 2.0)}" ) +
               %(y="#{BASELINE + 24}" text-anchor="middle">#{escape(collection_shelf_label(cluster[:category]))}</text>)
    end
    parts.join
  end

  # ── Assembling the plates ────────────────────────────────────────────────

  def sources_plate(resources, clusters)
    media_tally = MEDIA.map do |medium|
      count = resources.count { |resource| resource["type"].to_s == medium[:type] }
      plural(count, medium[:label], "#{medium[:label]}s")
    end.join(", ")
    blocks = clusters.map { |cluster| "#{cluster[:category]}, #{cluster[:items].length}" }.join("; ")

    plate(
      "sources",
      legend: MEDIA.map { |medium| [medium[:type], medium[:legend]] },
      tally: "#{plural(resources.length, 'source', 'sources')} · " \
             "#{plural(clusters.length, 'collection', 'collections')}",
      title: "The shelf, by collection and medium",
      description: "One square per source, packed into a block for the collection it belongs to and " \
                   "coloured by medium: #{media_tally}. The #{clusters.length} blocks, largest first: #{blocks}.",
      art: draw_source_field(clusters)
    )
  end

  # A tally in the caption would only repeat the three numerals, so the caption
  # carries the one thing the drawing does not: how much of the writing the
  # graph actually holds.
  def network_plate(graph)
    themes = graph[:themes].map { |theme| "#{theme[:name]}, #{theme[:uses]}" }.join("; ")

    plate(
      "network",
      width: METRIC_VIEW_W,
      height: METRIC_VIEW_H,
      legend: [%w[articles Articles], %w[posts Rascunhos]],
      tally: "#{graph[:nodes].length} of #{plural(graph[:corpus], 'piece', 'pieces')} joined",
      title: "What the idea graph holds",
      description: "#{plural(graph[:nodes].length, 'entry', 'entries')} of #{graph[:corpus]}, joined by " \
                   "#{plural(graph[:edges].length, 'citation', 'citations')} and by " \
                   "#{plural(graph[:themes].length, 'shared theme', 'shared themes')}, most returned to " \
                   "first: #{themes}. The bar beneath splits them into " \
                   "#{plural(graph[:articles], 'article', 'articles')} and " \
                   "#{plural(graph[:posts], 'rascunho', 'rascunhos')}.",
      art: draw_metric_card(graph)
    )
  end

  # The legend and the tally are the plate's own caption, and both are counted
  # rather than written, so they travel with the drawing. They ride as attributes
  # instead of as SVG text because text inside a viewBox scales with the box: the
  # browser lifts them back out into the plate's HTML caption, where they keep the
  # label register at whatever size the panel happens to be.
  def plate(name, legend:, tally:, title:, description:, art:, width: VIEW_W, height: VIEW_H)
    id = "home-index-#{name}"
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" class="home-index-art home-index-art--#{name}" viewBox="0 0 #{width} #{height}"
        preserveAspectRatio="xMidYMid meet" role="img" aria-labelledby="#{id}-title #{id}-desc"
        data-band-tally="#{escape(tally)}"
        data-band-legend="#{escape(legend.map { |kind, label| "#{kind}:#{label}" }.join(','))}"><title id="#{id}-title">#{escape(title)}</title><desc id="#{id}-desc">#{escape(description)}</desc>#{art}</svg>
    SVG
  end

  # ── Small helpers ────────────────────────────────────────────────────────

  # Integers print without a trailing ".0" so the path data reads like the
  # geometry constants above it.
  def round(value)
    rounded = value.to_f.round(2)
    rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
  end

  def plural(count, singular, plural_form)
    "#{count} #{count == 1 ? singular : plural_form}"
  end

  def escape(value)
    value.to_s
         .gsub("&", "&amp;")
         .gsub("<", "&lt;")
         .gsub(">", "&gt;")
         .gsub('"', "&quot;")
  end
end
