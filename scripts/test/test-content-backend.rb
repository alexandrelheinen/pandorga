# frozen_string_literal: true

# An omitted backend must not discard a configured public origin.
# Explicit static still serves JSON from _site.
require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
$LOAD_PATH.unshift(ROOT.join("lib").to_s)
require "pandorga/registry"

def check!(condition, message)
  return if condition

  warn "FAIL test-content-backend: #{message}"
  exit 1
end

url = "https://pub-example.r2.dev"

check!(PandorgaRegistry.content_backend({}) == "static",
       "no origin must stay static")
check!(PandorgaRegistry.static_backend?({}),
       "static_backend? must be true when no origin is set")

legacy = { "content_api_base_url" => url }
check!(PandorgaRegistry.content_backend(legacy) == "object_store",
       "legacy content_api_base_url must select object_store, got #{PandorgaRegistry.content_backend(legacy).inspect}")
check!(PandorgaRegistry.object_store_backend?(legacy),
       "object_store_backend? must be true for a legacy URL")
check!(PandorgaRegistry.content_base_url(legacy) == url,
       "legacy URL must remain the public origin")

base_only = { "pandorga" => { "content" => { "base_url" => "#{url}/" } } }
check!(PandorgaRegistry.content_backend(base_only) == "object_store",
       "base_url without backend must select object_store")
check!(PandorgaRegistry.content_base_url(base_only) == url,
       "base_url must be stripped of a trailing slash")

explicit_static = {
  "content_api_base_url" => url,
  "pandorga" => { "content" => { "backend" => "static" } }
}
check!(PandorgaRegistry.content_backend(explicit_static) == "static",
       "explicit static must win over a leftover URL")

explicit_r2 = { "pandorga" => { "content" => { "backend" => "r2", "base_url" => url } } }
check!(PandorgaRegistry.content_backend(explicit_r2) == "r2",
       "explicit r2 must be preserved")

puts "PASS test-content-backend"
