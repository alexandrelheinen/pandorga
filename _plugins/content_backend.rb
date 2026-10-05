# frozen_string_literal: true

require "jekyll"

# Maps pandorga.content.backend / base_url onto the legacy content_api_base_url
# and local_content_serve flags the runtime and exporters already understand.
# Refs: PLT §5.2, PLT-AC-6
module Jekyll
  module PandorgaContentBackend
    module_function

    def apply!(site)
      require "pandorga/registry"

      config = site.config
      backend = PandorgaRegistry.content_backend(config)
      base = PandorgaRegistry.content_base_url(config)

      config["pandorga"] ||= {}
      config["pandorga"]["content"] ||= {}
      config["pandorga"]["content"]["backend"] = backend

      if PandorgaRegistry.static_backend?(config)
        config["content_api_base_url"] = ""
        # Serve exported JSON from _site unless the site opts out explicitly.
        config["local_content_serve"] = true unless config.key?("local_content_serve")
      else
        config["content_api_base_url"] = base
        config["pandorga"]["content"]["base_url"] = base
      end
    end
  end
end

Jekyll::Hooks.register :site, :after_init do |site|
  Jekyll::PandorgaContentBackend.apply!(site)
end
