# frozen_string_literal: true

require "yaml"
require "pathname"

# Shared editorial license metadata (_config.yml → content_license).
module ContentLicense
  # No default rights_holder — sites must set content_license.rights_holder.
  DEFAULTS = {
    "id" => "CC-BY-4.0",
    "name" => "Creative Commons Attribution 4.0 International",
    "url" => "https://creativecommons.org/licenses/by/4.0/",
    "page_path" => "/pages/license/"
  }.freeze

  SOFTWARE = {
    "id" => "MIT",
    "name" => "MIT License",
    "url" => "https://opensource.org/licenses/MIT",
    "file" => "LICENSE"
  }.freeze

  EDITORIAL_TYPES = %w[article post product project job resource].freeze

  module_function

  def load(repo_root = Pathname.new(__dir__).join("..", "..").expand_path)
    config_path = repo_root.join("_config.yml")
    return DEFAULTS.dup unless config_path.file?

    config = YAML.safe_load(config_path.read) || {}
    raw = config["content_license"]
    return DEFAULTS.dup unless raw.is_a?(Hash)

    DEFAULTS.merge(raw.transform_keys(&:to_s))
  end

  def payload(license = load)
    license.slice("id", "name", "url", "rights_holder", "page_path")
  end

  def copyright_notice(license = load, year: Time.now.utc.year)
    holder = license["rights_holder"] || DEFAULTS["rights_holder"]
    "© #{year} #{holder}"
  end

  def editorial?(type)
    EDITORIAL_TYPES.include?(type)
  end
end
