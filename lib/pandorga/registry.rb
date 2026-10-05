# frozen_string_literal: true

# Page registry helpers (no Jekyll dependency — safe for the exporter CLI).
# Refs: PLT-AC-3, PLT-AC-5

module PandorgaRegistry
  KNOWN_TEMPLATES = %w[
    cv articles blog media network bibliography portfolio
  ].freeze

  # Template key → Jekyll layout name (existing top-level layouts).
  TEMPLATE_LAYOUTS = {
    "cv" => "cv",
    "articles" => "articles",
    "blog" => "blog",
    "media" => "resources",
    "network" => "network",
    "bibliography" => "bibliography",
    "portfolio" => "projects"
  }.freeze

  # Shell collections loaded from content/ for timeline / CV / media.
  DEFAULT_SHELL_COLLECTIONS = {
    "products" => "collections/products",
    "projects" => "collections/projects",
    "jobs" => "collections/jobs",
    "resources" => "collections/resources"
  }.freeze

  OBJECT_STORE_BACKENDS = %w[r2 object_store s3].freeze

  module_function

  def pages(config)
    raw = config.dig("pandorga", "pages")
    return [] unless raw.is_a?(Array)

    raw
  end

  def validate!(pages)
    keys = []
    paths = []
    pages.each_with_index do |page, i|
      raise ArgumentError, "pandorga.pages[#{i}] must be a mapping" unless page.is_a?(Hash)

      key = page["key"].to_s
      raise ArgumentError, "pandorga.pages[#{i}]: missing key" if key.empty?
      raise ArgumentError, "pandorga.pages: duplicate key #{key.inspect}" if keys.include?(key)

      keys << key

      template = page["template"].to_s
      raise ArgumentError, "pandorga.pages[#{key}]: missing template" if template.empty?
      unless KNOWN_TEMPLATES.include?(template)
        raise ArgumentError,
              "pandorga.pages[#{key}]: unknown template #{template.inspect} " \
              "(known: #{KNOWN_TEMPLATES.join(', ')})"
      end

      path = page["path"].to_s
      next if path.empty?
      raise ArgumentError, "pandorga.pages: conflicting path #{path.inspect}" if paths.include?(path)

      paths << path
    end
  end

  def build_nav(pages)
    groups = {}
    order = []
    pages.each do |page|
      next unless page.is_a?(Hash)
      next if page["nav"] == false

      nav = page["nav"].is_a?(Hash) ? page["nav"] : {}
      group = nav["group"] || "Pages"
      unless groups.key?(group)
        groups[group] = []
        order << group
      end
      item = { "key" => page["key"] }
      item["icon"] = nav["icon"] if nav["icon"]
      groups[group] << item
    end
    order.map { |label| { "label" => label, "pages" => groups[label] } }
  end

  def layout_for(page)
    return page["layout"].to_s unless page["layout"].to_s.empty?

    template = page["template"].to_s
    TEMPLATE_LAYOUTS.fetch(template, "pandorga/#{template}")
  end

  def writing_collections(pages)
    map = {}
    pages.each do |page|
      next unless page.is_a?(Hash)
      next unless %w[articles blog].include?(page["template"].to_s)

      collection = page["collection"].to_s
      next if collection.empty?

      type = case collection
             when "articles" then "article"
             when "posts" then "post"
             else collection.sub(/s\z/, "")
             end
      map[collection] = type
    end
    # Portfolio / CV keyed entries also feed the slim writing index.
    pages.each do |page|
      next unless page.is_a?(Hash)

      case page["template"].to_s
      when "portfolio"
        c = page["collection"].to_s
        map[c] = "project" unless c.empty?
      when "cv"
        cols = page["collections"]
        next unless cols.is_a?(Hash)

        products = cols["products"].to_s
        map[products] = "product" unless products.empty?
      end
    end
    map["products"] ||= "product"
    map["projects"] ||= "project"
    map
  end

  # Collection folders the shell injects at build time (jobs, projects, …).
  def shell_collection_dirs(pages)
    dirs = {}
    pages.each do |page|
      next unless page.is_a?(Hash)

      template = page["template"].to_s
      case template
      when "portfolio"
        name = page["collection"].to_s
        dirs[name] = "collections/#{name}" unless name.empty?
      when "media"
        name = page["collection"].to_s
        dirs[name] = "collections/#{name}" unless name.empty?
      when "cv"
        cols = page["collections"]
        next unless cols.is_a?(Hash)

        cols.each_value do |name|
          n = name.to_s
          next if n.empty? || n == "data" || n == "profile"

          dirs[n] = "collections/#{n}"
        end
      end
    end
    dirs.empty? ? DEFAULT_SHELL_COLLECTIONS.dup : DEFAULT_SHELL_COLLECTIONS.merge(dirs)
  end

  # Adapter collections used for timeline derived export.
  def adapter_collection_dirs(pages)
    dirs = shell_collection_dirs(pages)
    dirs.select { |name, _| %w[products projects jobs].include?(name) }
  end

  # Default home behaviour when `home` is omitted (PLT §5.2 / §5.4).
  TEMPLATE_HOME_DEFAULTS = {
    "cv" => { "band" => "hero" },
    "articles" => { "featured" => true, "limit" => 3 },
    "blog" => { "limit" => 4 },
    "portfolio" => { "limit" => 4 },
    "media" => { "band" => "index", "group" => "references" },
    "network" => { "band" => "index", "group" => "references" },
    "bibliography" => { "band" => "index", "group" => "references" }
  }.freeze

  # Homepage band plan in registry order (PLT §5.4).
  # Hero-only pages (`home.band: hero`) are skipped — the hero is separate.
  def home_bands(pages)
    bands = []
    pending_index = nil

    flush_index = lambda do
      return unless pending_index

      bands << pending_index
      pending_index = nil
    end

    pages.each do |page|
      next unless page.is_a?(Hash)
      next if page["home"] == false

      home = resolve_home(page)
      next if home["band"].to_s == "hero"

      if home["band"].to_s == "index" || !home["group"].to_s.empty?
        group = home["group"].to_s
        group = "index" if group.empty?
        if pending_index.nil? || pending_index["group"] != group
          flush_index.call
          pending_index = {
            "kind" => "index",
            "group" => group,
            "section_key" => group == "references" ? "index" : group,
            "pages" => []
          }
        end
        pending_index["pages"] << page_band_meta(page, home)
        next
      end

      flush_index.call
      template = page["template"].to_s
      bands << page_band_meta(page, home).merge(
        "kind" => template,
        "section_key" => page["key"].to_s
      )
    end
    flush_index.call
    apply_contrast!(bands)
  end

  def resolve_home(page)
    defaults = TEMPLATE_HOME_DEFAULTS[page["template"].to_s] || {}
    return defaults.dup unless page["home"].is_a?(Hash)

    defaults.merge(page["home"])
  end
  private_class_method :resolve_home

  def page_band_meta(page, home)
    {
      "key" => page["key"].to_s,
      "template" => page["template"].to_s,
      "path" => page["path"].to_s,
      "title" => page["title"].to_s,
      "collection" => page["collection"].to_s,
      "language" => page["language"].to_s,
      "accent" => page["accent"].to_s,
      "home" => home
    }
  end
  private_class_method :page_band_meta

  def apply_contrast!(bands)
    bands.each_with_index do |band, i|
      # Odd listing bands get contrast; index bands always contrast.
      band["contrast"] = band["kind"] == "index" || i.odd?
    end
    bands
  end
  private_class_method :apply_contrast!

  def content_backend(config)
    raw = config.dig("pandorga", "content", "backend").to_s.strip
    return raw unless raw.empty?

    # A public origin is the pre-registry signal that JSON lives on an object
    # store. Static is the default only when no origin is configured; an
    # explicit `backend: static` still wins and the build clears the URL.
    return "object_store" unless content_base_url(config).empty?

    "static"
  end

  def content_base_url(config)
    pandorga_url = config.dig("pandorga", "content", "base_url").to_s.strip
    return pandorga_url.chomp("/") unless pandorga_url.empty?

    legacy = config["content_api_base_url"].to_s.strip
    legacy.empty? ? "" : legacy.chomp("/")
  end

  def object_store_backend?(config)
    OBJECT_STORE_BACKENDS.include?(content_backend(config))
  end

  def static_backend?(config)
    content_backend(config) == "static"
  end
end
