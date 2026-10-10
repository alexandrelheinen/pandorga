# frozen_string_literal: true

# Spec: docs/features/hero-name.md
# Refs: PLT-AC-14
module Pandorga
  # Given name, family name, and top-bar wordmark for the home hero.
  module IdentityName
    module_function

    # identity may use string or symbol keys. author and title are the
    # Jekyll site.author and site.title fallbacks.
    def resolve(identity, author: nil, title: nil)
      fields = normalize(identity)
      given_field = explicit(fields, "first_name")
      family_field = explicit(fields, "last_name")
      legacy = tokens(text(fields["name"]).empty? ? author : fields["name"])

      given = present(given_field) ? given_field : legacy.first.to_s
      family = present(family_field) ? family_field : legacy.drop(1).take(8).join(" ")
      wordmark = if present(given_field)
                   given_field
                 else
                   source = [fields["name"], author, title].map { |value| text(value) }.find { |value| !value.empty? }
                   tokens(source).first.to_s
                 end

      { "given" => given, "family" => family, "wordmark" => wordmark }
    end

    def normalize(identity)
      raw = case identity
            when Hash then identity
            else identity.respond_to?(:to_hash) ? identity.to_hash : {}
            end
      raw.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
    end

    # :missing when the key is absent or null. Blank is handled by present.
    def explicit(fields, key)
      return :missing unless fields.key?(key)
      return :missing if fields[key].nil?

      fields[key].to_s.strip
    end

    def present(value)
      value.is_a?(String) && !value.empty?
    end

    def text(value)
      value.to_s.strip
    end

    def tokens(value)
      text(value).split(" ")
    end
  end
end

# Liquid filter used by the home hero and the top bar.
module PandorgaHeroNameFilter
  def pandorga_hero_name(identity, author = nil, title = nil)
    Pandorga::IdentityName.resolve(identity, author: author, title: title)
  end
end

Liquid::Template.register_filter(PandorgaHeroNameFilter) if defined?(Liquid::Template)
