# frozen_string_literal: true

require "pathname"
require "yaml"

# Shared reader for the public content store base URL (_config.yml → content_api_base_url).
module ContentStorageConfig
  PLACEHOLDER_MARKERS = [
    "__R2_PUBLIC_BASE_URL__",
    "REPLACE_WITH_R2_PUBLIC_BASE_URL"
  ].freeze
  LEGACY_GCS_HOST = "storage.googleapis.com"

  module_function

  def repo_root
    Pathname.new(__dir__).join("..", "..").expand_path
  end

  def config_path
    repo_root.join("_config.yml")
  end

  def load_config
    YAML.safe_load(config_path.read) || {}
  rescue Errno::ENOENT
    {}
  end

  def base_url
    env = ENV["R2_PUBLIC_BASE_URL"].to_s.strip
    env = ENV["CONTENT_API_BASE_URL"].to_s.strip if env.empty?
    unless env.empty?
      return env.chomp("/")
    end

    url = load_config["content_api_base_url"].to_s.strip
    url.empty? ? nil : url.chomp("/")
  end

  def placeholder?(url = base_url)
    return true if url.nil? || url.empty?

    PLACEHOLDER_MARKERS.any? { |marker| url.include?(marker) }
  end

  def legacy_gcs?(url = base_url)
    return false if url.nil? || url.empty?

    url.include?(LEGACY_GCS_HOST)
  end

  def configured_for_live_checks?
    url = base_url
    !url.nil? && !url.empty? && !placeholder?(url) && !legacy_gcs?(url)
  end
end
