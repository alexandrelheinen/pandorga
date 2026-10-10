# frozen_string_literal: true

# Spec: docs/features/fonts.md
# Refs: PLT-AC-30
module Pandorga
  # Google Fonts families for one site. An omitted role keeps the
  # Architectural Ledger face. A set role replaces that face only.
  module Fonts
    module_function

    ROLES = %i[title label body mono code subtitle cv_body].freeze
    # These follow another role when the theme used one family for both
    # and the site did not name them. Changing the body then changes the
    # tagline, instead of leaving Newsreader behind.
    FOLLOW = { subtitle: :body, code: :mono, cv_body: :body }.freeze
    MONO_FALLBACK = "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, monospace"
    FAMILY_NAME = /\A[\p{L}\p{N}][\p{L}\p{N} .+\-]*\z/

    DEFAULTS = {
      title: { family: "Cinzel Decorative", spec: "wght@400;700;900", fallback: "serif" },
      subtitle: {
        family: "Newsreader",
        spec: "ital,opsz,wght@0,6..72,300;0,6..72,400;0,6..72,500;0,6..72,600;0,6..72,700;1,6..72,300;1,6..72,400;1,6..72,500",
        fallback: "serif"
      },
      label: { family: "Marcellus SC", spec: "wght@400;700", fallback: "serif" },
      body: { family: "Newsreader", spec: "wght@300;400;500;600;700", fallback: "Georgia, serif" },
      mono: { family: "Courier Prime", spec: "ital,wght@0,400;0,700;1,400;1,700", fallback: MONO_FALLBACK },
      code: { family: "Courier Prime", spec: "ital,wght@0,300;0,400;0,700;1,400;1,700", fallback: MONO_FALLBACK },
      cv_body: { family: "Newsreader", spec: "wght@300;400;500;600;700", fallback: "Georgia, serif" }
    }.freeze

    def resolve(site_fonts, theme_fonts = nil)
      site = string_keys(site_fonts)
      theme = string_keys(theme_fonts)
      resolved = {}
      ROLES.each do |role|
        resolved[role] = resolve_role(role, site[role.to_s], theme)
      end
      FOLLOW.each do |role, source|
        next if named?(site[role.to_s])
        next unless same_family?(theme, role, source)

        resolved[role] = resolved[role].merge(
          family: resolved[source][:family],
          spec: resolved[source][:spec]
        )
      end
      resolved
    end

    def from_site(site)
      pandorga = lookup(site, "pandorga")
      fonts = lookup(pandorga, "fonts")
      data = lookup(site, "data")
      themes = lookup(data, "themes")
      shared = lookup(themes, "shared")
      resolve(fonts, lookup(shared, "fonts"))
    end

    def stylesheet_href(resolved)
      seen = []
      parts = []
      ROLES.each do |role|
        face = resolved[role]
        family = face[:family].to_s
        next if family.empty? || seen.include?(family)

        seen << family
        parts << "#{family.tr(' ', '+')}:#{face[:spec]}"
      end
      return "" if parts.empty?

      "https://fonts.googleapis.com/css2?family=#{parts.join('&family=')}&display=swap"
    end

    def css_stack(resolved, role)
      face = resolved[role.to_sym]
      return "" unless face

      quoted = face[:family].to_s.empty? ? nil : "'#{escape_css(face[:family])}'"
      [quoted, face[:fallback].to_s.strip].compact.reject(&:empty?).join(", ")
    end

    def resolve_role(role, override, theme)
      base = DEFAULTS.fetch(role)
      family = text(theme[role.to_s])
      family = base[:family] if family.empty?
      spec = text(theme["google_#{role}_spec"])
      spec = base[:spec] if spec.empty?
      fallback = fallback_for(role, theme, base)

      parsed = parse_override(override)
      return { family: family, spec: spec, fallback: fallback } unless parsed

      {
        family: parsed[:family],
        spec: spec_for(parsed, family, spec, base[:family]),
        fallback: fallback
      }
    end

    def fallback_for(role, theme, base)
      if role == :cv_body
        body = text(theme["body_fallback"])
        return body unless body.empty?
      end
      own = text(theme["#{role}_fallback"])
      own.empty? ? base[:fallback] : own
    end

    def spec_for(parsed, theme_family, theme_spec, default_family)
      if parsed[:weights] || !parsed[:italic].nil?
        weights = parsed[:weights] || [400, 700]
        if parsed[:italic]
          # Roman tuples first, then italic, so the axis list stays sorted.
          tuples = weights.map { |weight| "0,#{weight}" } + weights.map { |weight| "1,#{weight}" }
          "ital,wght@#{tuples.join(';')}"
        else
          "wght@#{weights.join(';')}"
        end
      elsif parsed[:family] == theme_family || parsed[:family] == default_family
        theme_spec
      else
        "wght@400;700"
      end
    end

    def parse_override(value)
      case value
      when String
        family = clean_family(value)
        family && { family: family, weights: nil, italic: nil }
      when Hash
        fields = string_keys(value)
        family = clean_family(fields["family"] || fields["name"])
        return nil unless family

        { family: family, weights: parse_weights(fields["weights"]), italic: italic_flag(fields) }
      end
    end

    def italic_flag(fields)
      return nil unless fields.key?("italic")

      value = fields["italic"]
      case value
      when true, "true", "yes", 1, "1" then true
      else false
      end
    end

    def parse_weights(value)
      return nil if value.nil?

      list = case value
             when Array then value
             when Integer then [value]
             when String then value.split(",")
             else return nil
             end
      numbers = []
      list.each do |item|
        text = item.to_s.strip
        next if text.empty?
        return nil unless text.match?(/\A\d+\z/)

        number = text.to_i
        return nil unless number.between?(1, 1000)

        numbers << number
      end
      return nil if numbers.empty?

      numbers.uniq.sort
    end

    def clean_family(value)
      family = value.to_s.strip
      return nil if family.empty? || !FAMILY_NAME.match?(family)

      family
    end

    def named?(value)
      !parse_override(value).nil?
    end

    def same_family?(theme, role, source)
      role_family = text(theme[role.to_s])
      source_family = text(theme[source.to_s])
      role_family = DEFAULTS.fetch(role)[:family] if role_family.empty?
      source_family = DEFAULTS.fetch(source)[:family] if source_family.empty?
      role_family == source_family
    end

    def text(value)
      value.to_s.strip
    end

    def string_keys(value)
      return {} unless value.is_a?(Hash)

      value.each_with_object({}) { |(key, item), out| out[key.to_s] = item }
    end

    def lookup(object, key)
      return nil if object.nil?

      string_key = key.to_s
      if object.is_a?(Hash)
        return object[string_key] if object.key?(string_key)
        return object[string_key.to_sym] if object.key?(string_key.to_sym)

        return nil
      end

      if object.respond_to?(:[])
        begin
          found = object[string_key]
          return found unless found.nil?
        rescue StandardError
          nil
        end
      end
      return object.public_send(string_key) if object.respond_to?(string_key)

      nil
    end

    def escape_css(family)
      family.to_s.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'").gsub(/[\r\n]/, "")
    end
  end
end
