# frozen_string_literal: true

require_relative "content_keys"

require "date"
require "set"

# Builds site.data["timeline"] at :post_read with normalized events and writing buckets.
# Spec: docs/features/timeline.md
module TimelineBuilder
  module_function

  def build(site)
    today = Date.today
    warnings = []
    errors = []
    events = []

    products_by_slug = index_products(site)
    referenced_product_slugs = Set.new

    build_jobs(site, today, events, warnings, errors, products_by_slug, referenced_product_slugs)
    build_education(site, events, errors)
    build_projects(site, today, events, errors)
    build_writing(site, events)

    products_by_slug.each_key do |slug|
      next if referenced_product_slugs.include?(slug)

      warnings << "Product '#{slug}' is not linked from any job; omitted from timeline"
    end

    writing_buckets = aggregate_writing(events)

    unless errors.empty?
      errors.each { |e| warn "Timeline validation error: #{e}" }
      raise "Timeline has #{errors.size} validation error(s). See docs/features/timeline.md."
    end

    warnings.each { |w| warn "Timeline: #{w}" }

    {
      "meta" => {
        "generated_at" => today.iso8601,
        "today" => today.iso8601,
        "warnings" => warnings
      },
      "events" => events,
      "writing_buckets" => writing_buckets
    }
  end

  def index_products(site)
    (site.collections["products"]&.docs || []).each_with_object({}) do |doc, hash|
      hash[doc_slug(doc)] = doc
    end
  end

  def build_jobs(site, today, events, warnings, errors, products_by_slug, referenced_product_slugs)
    # One product bar per slug. Jobs may list the same product across consecutive
    # roles; emitting once per job created duplicate clipped fragments (Anafi Ai / UKR).
    product_refs = {}

    (site.collections["jobs"]&.docs || []).each do |doc|
      slug = doc_slug(doc)
      raw_start = doc.data["start"]
      raw_end = doc.data["end"]

      if blank?(raw_start)
        errors << "Job '#{slug}': missing required 'start' field"
        next
      end

      ongoing = blank?(raw_end)
      start_info = normalize_start(raw_start)
      end_info = if ongoing
                   { date: today, precision: "day", raw: nil }
                 else
                   normalize_end(raw_end, start_info[:precision])
                 end

      job_id = "job:#{slug}"
      events << event_hash(
        id: job_id,
        source: "jobs",
        source_id: slug,
        type: "employment",
        title: doc.data["position"].to_s,
        subtitle: doc.data["company"].to_s,
        start_on: start_info[:date],
        end_on: end_info[:date],
        ongoing: ongoing,
        precision: start_info[:precision],
        url: doc.url,
        meta: {
          "raw_start" => start_info[:raw],
          "raw_end" => ongoing ? nil : end_info[:raw],
          "location" => doc.data["location"]
        }
      )

      job_start = start_info[:date]
      job_end = end_info[:date]

      Array(doc.data["products"]).each do |product_slug|
        product_slug = product_slug.to_s.strip
        next if product_slug.empty?

        product_doc = products_by_slug[product_slug]
        unless product_doc
          warnings << "Job '#{slug}': product slug '#{product_slug}' not found in products content"
          next
        end

        referenced_product_slugs << product_slug
        ref = product_refs[product_slug] ||= {
          "doc" => product_doc,
          "job_ids" => [],
          "job_starts" => [],
          "job_ends" => []
        }
        ref["job_ids"] << job_id
        ref["job_starts"] << job_start
        ref["job_ends"] << job_end
      end
    end

    product_refs.each do |product_slug, ref|
      add_product_event(
        ref["doc"],
        product_slug,
        ref["job_ids"],
        ref["job_starts"].min,
        ref["job_ends"].max,
        today,
        events,
        warnings
      )
    end
  end

  def add_product_event(doc, slug, job_ids, jobs_start, jobs_end, today, events, warnings)
    raw_start = doc.data["start_date"]
    raw_end = doc.data["end_date"]

    if blank?(raw_start)
      warnings << "Product '#{slug}': missing start_date; skipped"
      return
    end

    start_info = normalize_start(raw_start)
    ongoing = blank?(raw_end)
    end_info = if ongoing
                 { date: today, precision: "day", raw: nil }
               else
                 normalize_end(raw_end, start_info[:precision])
               end

    prod_start = start_info[:date]
    prod_end = end_info[:date]
    parent_ids = Array(job_ids)

    if prod_start < jobs_start || prod_end > jobs_end
      warnings << "Product '#{slug}': dates (#{prod_start}..#{prod_end}) outside linked jobs span (#{jobs_start}..#{jobs_end}); clipped"
      prod_start = [prod_start, jobs_start].max
      prod_end = [prod_end, jobs_end].min
    end

    if prod_end < prod_start
      warnings << "Product '#{slug}': no overlap with linked jobs; skipped"
      return
    end

    title = present(doc.data["product"]) || doc.data["title"].to_s
    events << event_hash(
      id: "product:#{slug}",
      source: "products",
      source_id: slug,
      type: "product",
      title: title,
      subtitle: doc.data["company"].to_s,
      start_on: prod_start,
      end_on: prod_end,
      ongoing: ongoing,
      precision: start_info[:precision],
      url: doc.url,
      parent_id: parent_ids.first,
      meta: {
        "raw_start" => start_info[:raw],
        "raw_end" => ongoing ? nil : end_info[:raw],
        "parent_ids" => parent_ids
      }
    )
  end

  def build_education(site, events, errors)
    (site.data["education"] || []).each_with_index do |entry, index|
      label = entry["institution"] || "entry #{index}"
      raw_start = entry["start"]
      raw_end = entry["end"]

      if blank?(raw_start) || blank?(raw_end)
        errors << "Education '#{label}': missing required 'start' or 'end' field"
        next
      end

      start_info = normalize_start(raw_start)
      end_info = normalize_end(raw_end, start_info[:precision])

      events << event_hash(
        id: "education:#{index}",
        source: "education",
        source_id: index.to_s,
        type: "education",
        title: entry["degree"].to_s,
        subtitle: entry["institution"].to_s,
        start_on: start_info[:date],
        end_on: end_info[:date],
        ongoing: false,
        precision: start_info[:precision],
        url: nil,
        meta: {
          "raw_start" => start_info[:raw],
          "raw_end" => end_info[:raw],
          "location" => entry["location"]
        }
      )
    end
  end

  def build_projects(site, today, events, errors)
    (site.collections["projects"]&.docs || []).each do |doc|
      slug = doc_slug(doc)
      raw_start = doc.data["start_date"]
      status = doc.data["status"].to_s.downcase
      raw_end = doc.data["end_date"]

      if blank?(raw_start)
        errors << "Project '#{slug}': missing required 'start_date' field"
        next
      end

      ongoing = status == "ongoing"
      start_info = normalize_start(raw_start)
      end_info = if ongoing
                   { date: today, precision: "day", raw: nil }
                 else
                   if blank?(raw_end)
                     errors << "Project '#{slug}': completed project requires 'end_date'"
                     next
                   end
                   normalize_end(raw_end, start_info[:precision])
                 end

      title = present(doc.data["project"]) || doc.data["title"].to_s
      events << event_hash(
        id: "project:#{slug}",
        source: "projects",
        source_id: slug,
        type: "project",
        title: title,
        subtitle: doc.data["label"].to_s,
        start_on: start_info[:date],
        end_on: end_info[:date],
        ongoing: ongoing,
        precision: start_info[:precision],
        url: doc.url,
        meta: {
          "raw_start" => start_info[:raw],
          "raw_end" => ongoing ? nil : end_info[:raw],
          "status" => status
        }
      )
    end
  end

  def build_writing(site, events)
    index = site.data["writing_index"]
    if index.is_a?(Array) && !index.empty?
      build_writing_from_index(index, events)
      return
    end

    article_docs = published_docs(site.collections["articles"]&.docs || [])

    article_docs.each do |doc|
      add_writing_event(doc, "articles", "article", events)
    end

    published_docs(site.collections["posts"]&.docs || []).each do |doc|
      add_writing_event(doc, "posts", "post", events)
    end
  end

  def build_writing_from_index(entries, events)
    entries.select { |entry| entry["type"] == "articles" }.each do |entry|
      add_writing_event_from_index(entry, "articles", "article", events)
    end

    entries.select { |entry| entry["type"] == "posts" }.each do |entry|
      add_writing_event_from_index(entry, "posts", "post", events)
    end
  end

  def add_writing_event_from_index(entry, source, type, events)
    raw_date = entry["date"]
    return if blank?(raw_date)

    day = parse_day(raw_date)
    slug = entry["slug"].to_s

    meta = { "raw_start" => day.iso8601, "raw_end" => day.iso8601 }
    if type == "article" && entry["last_updated"]
      meta["last_updated"] = entry["last_updated"].to_s
    end

    events << event_hash(
      id: "#{type}:#{slug}",
      source: source,
      source_id: slug,
      type: type,
      title: entry["title"].to_s,
      subtitle: type == "article" ? "Article" : "Post",
      start_on: day,
      end_on: day,
      ongoing: false,
      precision: "day",
      url: entry["url"],
      meta: meta
    )
  end

  def published_docs(docs)
    docs.reject { |doc| doc.data["published"] == false }
  end

  def add_writing_event(doc, source, type, events)
    raw_date = doc.data["date"]
    return if blank?(raw_date)

    day = parse_day(raw_date)
    slug = doc_slug(doc)

    meta = { "raw_start" => day.iso8601, "raw_end" => day.iso8601 }
    if type == "article" && doc.data["last_updated"]
      meta["last_updated"] = doc.data["last_updated"].to_s
    end

    events << event_hash(
      id: "#{type}:#{slug}",
      source: source,
      source_id: slug,
      type: type,
      title: doc.data["title"].to_s,
      subtitle: type == "article" ? "Article" : "Post",
      start_on: day,
      end_on: day,
      ongoing: false,
      precision: "day",
      url: doc.url,
      meta: meta
    )
  end

  def aggregate_writing(events)
    writing = events.select { |e| %w[post article].include?(e["type"]) }
    buckets = {}

    writing.each do |ev|
      month = ev["start"][0, 7]
      buckets[month] ||= { "month" => month, "count" => 0, "posts" => [], "articles" => [] }
      buckets[month]["count"] += 1
      item = {
        "id" => ev["id"],
        "title" => ev["title"],
        "url" => ev["url"],
        "date" => ev["start"]
      }
      if ev["type"] == "article"
        buckets[month]["articles"] << item
      else
        buckets[month]["posts"] << item
      end
    end

    buckets.values.sort_by { |b| b["month"] }
  end

  def event_hash(id:, source:, source_id:, type:, title:, subtitle:, start_on:, end_on:, ongoing:, precision:, url:, parent_id: nil, meta: {})
    {
      "id" => id,
      "source" => source,
      "source_id" => source_id,
      "type" => type,
      "title" => title,
      "subtitle" => subtitle,
      "start" => iso_date(start_on),
      "end" => iso_date(end_on),
      "ongoing" => ongoing,
      "precision" => precision,
      "url" => url,
      "parent_id" => parent_id,
      "meta" => meta
    }.compact
  end

  def normalize_start(raw)
    raw_s = raw.to_s.strip
    if raw_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      day = Date.parse(raw_s)
      { date: day, precision: "day", raw: raw_s }
    elsif raw_s.match?(/\A\d{4}-\d{2}\z/)
      y, m = raw_s.split("-").map(&:to_i)
      { date: Date.new(y, m, 1), precision: "month", raw: raw_s }
    elsif raw_s.match?(/\A\d{4}\z/)
      y = raw_s.to_i
      { date: Date.new(y, 1, 1), precision: "year", raw: raw_s }
    else
      raise ArgumentError, "Unrecognized date format: #{raw_s}"
    end
  end

  def normalize_end(raw, start_precision)
    raw_s = raw.to_s.strip
    if raw_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      day = Date.parse(raw_s)
      { date: day, precision: "day", raw: raw_s }
    elsif raw_s.match?(/\A\d{4}-\d{2}\z/)
      y, m = raw_s.split("-").map(&:to_i)
      { date: Date.new(y, m, -1), precision: "month", raw: raw_s }
    elsif raw_s.match?(/\A\d{4}\z/)
      y = raw_s.to_i
      { date: Date.new(y, 12, 31), precision: "year", raw: raw_s }
    else
      precision = start_precision || "day"
      { date: normalize_start(raw_s)[:date], precision: precision, raw: raw_s }
    end
  end

  def parse_day(raw)
    case raw
    when Date then raw
    when Time then raw.to_date
    else Date.parse(raw.to_s)
    end
  end

  def iso_date(value)
    case value
    when Date then value.iso8601
    when String then value
    else value.to_s
    end
  end

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def present(value)
    s = value.to_s.strip
    s.empty? ? nil : s
  end

  def doc_slug(doc)
    data = doc.data || {}
    type = infer_doc_type(doc)
    key = ContentKeys.normalize_key(data["key"])
    if ContentKeys::KEYED_TYPES.include?(type) && !key.empty?
      return ContentKeys.path_segment(type, key, date: data["date"])
    end

    slug = data["slug"].to_s.strip
    return slug unless slug.empty?

    File.basename(doc.path, File.extname(doc.path))
  end

  def infer_doc_type(doc)
    path = doc.path.to_s
    return "article" if path.include?("/articles/")
    return "post" if path.include?("/posts/") || path.include?("/collections/posts/")
    return "product" if path.include?("/products/") || path.include?("/collections/products/")
    return "project" if path.include?("/projects/") || path.include?("/collections/projects/")

    collection = doc.respond_to?(:collection) ? doc.collection&.label.to_s : ""
    return "article" if collection == "articles"
    return "post" if collection == "posts"
    return "product" if collection == "products"
    return "project" if collection == "projects"

    "job"
  end
end

module Jekyll
  class TimelineGenerator < Generator
    safe true
    priority :low

    def generate(site)
      return if site.config["shell_content_agnostic"]

      site.data["timeline"] = TimelineBuilder.build(site)
    end
  end
end if defined?(Jekyll::Generator)
