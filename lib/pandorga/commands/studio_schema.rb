# frozen_string_literal: true

require "pathname"
require "yaml"
require "fileutils"
require "date"

module Pandorga
  module Commands
    # Compose studio/schema.yml from template studio.yml files + registry.
    # Refs: PLT-AC-3, PLT-AC-43, docs/spec.md §5.5
    class StudioSchema
      DEFAULT_MEDIA = {
        "name" => "media",
        "label" => "Media",
        "input" => "content/media",
        "output" => "/media",
        "categories" => %w[image video plot],
        "rename" => "safe"
      }.freeze

      DEFAULT_MARKDOWN_BODY = {
        "type" => "code",
        "label" => "Body",
        "description" =>
          "Markdown source (code editor). Paste Liquid {% include %} markers " \
          "as-is — figures, citations, embeds.",
        "options" => { "format" => "markdown" }
      }.freeze

      def self.apply_taxonomies!(schema, config)
        new.apply_taxonomies!(schema, config)
      end

      def self.apply_overrides!(schema, extra)
        new.apply_overrides!(schema, extra)
      end

      def run(argv)
        root = Pathname.new(argv[0] || Dir.pwd).expand_path
        templates_root = Pathname.new(Pandorga.gem_path("templates"))
        config_path = root.join("_config.yml")
        unless config_path.file?
          warn "error: no _config.yml in #{root}"
          return 1
        end

        config = YAML.safe_load(config_path.read, permitted_classes: [Date]) || {}
        schema = compose(config, templates_root)

        overrides_path = root.join("studio.overrides.yml")
        if overrides_path.file?
          extra = YAML.safe_load(overrides_path.read, permitted_classes: [Date]) || {}
          apply_overrides!(schema, extra) if extra.is_a?(Hash)
        end

        out = root.join("studio", "schema.yml")
        FileUtils.mkdir_p(out.dirname)
        out.write(YAML.dump(schema))
        puts "pandorga studio-schema: wrote #{out}"
        0
      end

      # Public for gates: build the schema hash without writing.
      def compose(config, templates_root)
        pages = config.dig("pandorga", "pages") || []
        groups = {}
        group_order = []
        needs_media = false
        needs_markdown = false
        collection_index = {}

        pages.each do |page|
          next unless page.is_a?(Hash)

          template = page["template"].to_s
          next if template.empty?

          studio_yml = Pathname.new(templates_root).join(template, "studio.yml")
          next unless studio_yml.file?

          fragment = YAML.safe_load(studio_yml.read, permitted_classes: [Date]) || {}
          next unless fragment.is_a?(Hash)

          needs_media ||= truthy?(fragment["needs_media"])
          contributions = expand_fragment(fragment, page)
          contributions.each do |contrib|
            group_name = contrib[:group]
            unless groups.key?(group_name)
              groups[group_name] = {
                "name" => group_name,
                "label" => contrib[:group_label],
                "type" => "group",
                "items" => []
              }
              group_order << group_name
            end

            contrib[:items].each do |item|
              needs_markdown ||= uses_markdown_body?(item)
              groups[group_name]["items"] << item
              if item["type"].to_s == "collection"
                # Deep copy so YAML.dump does not emit aliases shared with content.
                collection_index[item["name"].to_s] = deep_dup(item)
              end
            end
          end
        end

        schema = {
          "version" => 1,
          "generated_by" => "pandorga studio-schema #{Pandorga::VERSION}",
          "content" => group_order.map { |name| groups[name] },
          "collections" => collection_index
        }
        schema["media"] = deep_dup(DEFAULT_MEDIA) if needs_media
        if needs_markdown
          schema["components"] = { "markdown_body" => deep_dup(DEFAULT_MARKDOWN_BODY) }
        end
        apply_taxonomies!(schema, config)
        schema
      end

      def apply_taxonomies!(schema, config)
        return [] unless schema.is_a?(Hash)

        vocabularies = resolve_taxonomies(config)
        missing = []

        Array(schema["content"]).each do |group|
          next unless group.is_a?(Hash)

          Array(group["items"]).each do |item|
            next unless item.is_a?(Hash)
            next unless item["type"].to_s == "collection"

            name = item["name"].to_s
            next if name.empty?

            had_picker = apply_collection_taxonomy!(item, vocabularies[name])
            missing << name if had_picker && !vocabularies.key?(name)
          end
        end

        index = schema["collections"].is_a?(Hash) ? schema["collections"] : {}
        index.each do |key, entry|
          next unless entry.is_a?(Hash)

          name = entry["name"].to_s.empty? ? key.to_s : entry["name"].to_s
          next if name.empty?

          had_picker = apply_collection_taxonomy!(entry, vocabularies[name])
          missing << name if had_picker && !vocabularies.key?(name)
        end

        missing.uniq
      end

      def apply_overrides!(schema, extra)
        if extra["media"].is_a?(Hash)
          schema["media"] = deep_merge(schema["media"] || {}, extra["media"])
        end

        if extra["components"].is_a?(Hash)
          schema["components"] = deep_merge(schema["components"] || {}, extra["components"])
        end

        if extra["collections"].is_a?(Hash)
          extra["collections"].each do |name, patch|
            next unless patch.is_a?(Hash)

            item = find_content_item(schema, name.to_s)
            if item
              merged = deep_merge(item, patch)
              item.replace(merged)
            end
            if schema["collections"].is_a?(Hash) && schema["collections"][name.to_s]
              schema["collections"][name.to_s] =
                deep_merge(schema["collections"][name.to_s], patch)
            end
          end
        end

        return unless extra["content"].is_a?(Array)

        schema["content"] ||= []
        extra["content"].each do |group|
          next unless group.is_a?(Hash)

          existing = schema["content"].find { |g| g["name"].to_s == group["name"].to_s }
          if existing
            existing.replace(deep_merge(existing, group))
          else
            schema["content"] << deep_dup(group)
          end
        end
      end

      private

      def expand_fragment(fragment, page)
        contributions = []
        default_group = fragment["group"].to_s
        default_group = page["template"].to_s if default_group.empty?
        default_label = fragment["group_label"].to_s
        default_label = default_group.capitalize if default_label.empty?

        items = []

        if fragment["collection"].is_a?(Hash)
          name = page["collection"].to_s
          unless name.empty?
            items << instantiate_collection(fragment["collection"], name, page)
          end
        end

        if fragment["collections"].is_a?(Hash)
          slots = page["collections"].is_a?(Hash) ? page["collections"] : {}
          fragment["collections"].each do |slot, spec|
            next unless spec.is_a?(Hash)

            name = slots[slot].to_s
            name = slot.to_s if name.empty?
            next if name.empty? || name == "data" || name == "profile"

            items << instantiate_collection(spec, name, page)
          end
        end

        Array(fragment["files"]).each do |file_spec|
          next unless file_spec.is_a?(Hash)

          items << deep_dup(file_spec)
        end

        unless items.empty?
          contributions << {
            group: default_group,
            group_label: default_label,
            items: items
          }
        end

        profile = fragment["profile"]
        if profile.is_a?(Hash)
          profile_items = Array(profile["files"]).select { |f| f.is_a?(Hash) }.map { |f| deep_dup(f) }
          unless profile_items.empty?
            contributions << {
              group: profile["group"].to_s.empty? ? "profile" : profile["group"].to_s,
              group_label: profile["group_label"].to_s.empty? ? "Profile" : profile["group_label"].to_s,
              items: profile_items
            }
          end
        end

        contributions
      end

      def instantiate_collection(spec, name, page)
        entry = deep_dup(spec)
        entry["name"] = name
        entry["type"] ||= "collection"
        if page["collection"].to_s == name && !page["title"].to_s.empty?
          entry["label"] = page["title"].to_s
        elsif entry["label"].to_s.empty?
          entry["label"] = name.capitalize
        end
        entry["path"] ||= "content/collections/#{name}"
        entry["path"] = entry["path"].to_s.gsub("{collection}", name)
        entry
      end

      def resolve_taxonomies(config)
        return {} unless config.is_a?(Hash)

        vocab = {}
        pages = Array(config.dig("pandorga", "pages")).select { |p| p.is_a?(Hash) }
        taxonomies = config.dig("pandorga", "taxonomies")

        if taxonomies.is_a?(Hash)
          taxonomies.each do |collection, spec|
            next unless spec.is_a?(Hash)

            tags = spec["tags"]
            next unless tags.is_a?(Array) && !tags.empty?

            coll_name = collection.to_s
            page_tax = pages.find { |p| p["collection"].to_s == coll_name }&.fetch("taxonomy", nil)
            page_tax = nil unless page_tax.is_a?(Hash)

            max = spec["max"].nil? ? page_tax&.fetch("max", nil) : spec["max"]
            min = spec["min"].nil? ? page_tax&.fetch("min", nil) : spec["min"]

            vocab[coll_name] = build_taxonomy_entry(tags, max: max, min: min)
          end
        end

        pages.each do |page|
          coll_name = page["collection"].to_s
          next if coll_name.empty? || vocab.key?(coll_name)

          spec = page["taxonomy"]
          next unless spec.is_a?(Hash)

          tags = spec["tags"]
          next unless tags.is_a?(Array) && !tags.empty?

          vocab[coll_name] = build_taxonomy_entry(tags, max: spec["max"], min: spec["min"])
        end

        vocab
      end

      def build_taxonomy_entry(tags, max:, min:)
        entry = { "tags" => tags.map(&:to_s) }
        parsed_max = parse_int_or_nil(max)
        parsed_min = parse_int_or_nil(min)
        entry["max"] = parsed_max unless parsed_max.nil?
        entry["min"] = parsed_min unless parsed_min.nil?
        entry
      end

      def parse_int_or_nil(val)
        return nil if val.nil?

        Integer(val)
      rescue ArgumentError, TypeError
        nil
      end

      def apply_collection_taxonomy!(entry, tax)
        had_picker = false
        Array(entry["fields"]).each do |field|
          next unless tag_picker_field?(field)

          had_picker = true
          field["options"] = {} unless field["options"].is_a?(Hash)
          opts = field["options"]

          if tax.is_a?(Hash)
            opts["values"] = Array(tax["tags"]).map(&:to_s)
            opts["max"] = tax["max"] unless tax["max"].nil?
            if tax["min"].nil?
              opts.delete("min")
            else
              opts["min"] = tax["min"]
            end
          else
            opts["values"] = []
            opts.delete("min")
          end
        end
        had_picker
      end

      def tag_picker_field?(field)
        field.is_a?(Hash) &&
          field["name"].to_s == "tags" &&
          field["type"].to_s == "select"
      end

      def find_content_item(schema, name)
        Array(schema["content"]).each do |group|
          next unless group.is_a?(Hash)

          Array(group["items"]).each do |item|
            return item if item.is_a?(Hash) && item["name"].to_s == name
          end
        end
        nil
      end

      def uses_markdown_body?(node)
        case node
        when Hash
          return true if node["component"].to_s == "markdown_body"

          node.any? { |_, v| uses_markdown_body?(v) }
        when Array
          node.any? { |v| uses_markdown_body?(v) }
        else
          false
        end
      end

      def truthy?(value)
        value == true || value.to_s == "true"
      end

      def deep_dup(obj)
        case obj
        when Hash
          obj.transform_values { |v| deep_dup(v) }
        when Array
          obj.map { |v| deep_dup(v) }
        else
          obj
        end
      end

      def deep_merge(left, right)
        return deep_dup(right) unless left.is_a?(Hash) && right.is_a?(Hash)

        result = deep_dup(left)
        right.each do |key, value|
          result[key] =
            if result.key?(key) && result[key].is_a?(Hash) && value.is_a?(Hash)
              deep_merge(result[key], value)
            else
              deep_dup(value)
            end
        end
        result
      end
    end
  end
end
