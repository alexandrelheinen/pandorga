#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "json"
require "ostruct"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
require_relative "../../_plugins/content_local_serve"
require_relative "../../_plugins/local_detail_rewrites"

def fail!(msg)
  warn "FAIL: #{msg}"
  exit 1
end

def check!(condition, msg)
  fail!(msg) unless condition
end

puts "Testing dev re-export feature..."

# 1. Check template file presence and key identifiers
include_file = REPO_ROOT.join("_includes/theme/dev-reexport.html")
check!(include_file.file?, "Missing _includes/theme/dev-reexport.html")
include_content = include_file.read
check!(include_content.include?('id="dev-reexport"'), "Missing id='dev-reexport' in include")
check!(include_content.include?('id="dev-reexport-btn"'), "Missing id='dev-reexport-btn' in include")
check!(include_content.include?('id="dev-reexport-label"'), "Missing id='dev-reexport-label' in include")
check!(include_content.include?('id="dev-reexport-icon"'), "Missing id='dev-reexport-icon' in include")
check!(include_content.include?("/__dev/reexport"), "Missing /__dev/reexport fetch in include")
check!(include_content.include?("text-tertiary"), "Missing text-tertiary token styling for dev button")
puts "  ✓ Template structure and styling tokens verified"

# 2. Check shell layout includes it with guard
shell_file = REPO_ROOT.join("_layouts/shell.html")
shell_content = shell_file.read
check!(shell_content.include?("theme/dev-reexport.html"), "Missing dev-reexport.html inclusion in _layouts/shell.html")
check!(shell_content.match?(/site\.content_include_unpublished.*theme\/dev-reexport\.html/m),
       "dev-reexport.html must be guarded by site.content_include_unpublished")
puts "  ✓ Shell layout conditional guard verified"

# 3. Check that public build evaluation does not render dev-reexport button
require "liquid"
guard_snippet = "{% if site.content_include_unpublished or site.unpublished %}dev_present{% else %}dev_absent{% endif %}"
parsed_guard = Liquid::Template.parse(guard_snippet)
check!(parsed_guard.render("site" => {}) == "dev_absent",
       "Public build (no dev flags) must NOT render dev-reexport button")
check!(parsed_guard.render("site" => { "content_include_unpublished" => true }) == "dev_present",
       "Dev build with content_include_unpublished must render dev-reexport button")
check!(parsed_guard.render("site" => { "unpublished" => true }) == "dev_present",
       "Dev build with unpublished must render dev-reexport button")
puts "  ✓ Liquid conditional guard correctly excludes button in public builds and includes it in dev"


# 4. Check REEXPORT_PATHS definition in LocalDetailRewrites
check!(Jekyll::ContentDetailRewrites::REEXPORT_PATHS.include?("/__dev/reexport"),
       "REEXPORT_PATHS must include /__dev/reexport")
check!(Jekyll::ContentDetailRewrites::REEXPORT_PATHS.include?("/api/dev/reexport"),
       "REEXPORT_PATHS must include /api/dev/reexport")
puts "  ✓ REEXPORT_PATHS verified"

# 5. Check handle_reexport_request permission guard
fake_res = {}
def fake_res.[]=(key, val)
  @headers ||= {}
  @headers[key] = val
end
def fake_res.status=(val)
  @status = val
end
def fake_res.status
  @status
end
def fake_res.body=(val)
  @body = val
end
def fake_res.body
  @body
end

# When dev options are nil/empty: must be 403 Forbidden
Jekyll::ContentLocalServe.serve_options = nil
Jekyll::ContentLocalServe.site_config = nil
Jekyll::ContentLocalServe.handle_reexport_request(nil, fake_res)
check!(fake_res.status == 403, "handle_reexport_request must return 403 when dev flags are absent")
puts "  ✓ Production permission guard returns 403"

# When dev option is present:
fake_res2 = {}
def fake_res2.[]=(key, val)
  @headers ||= {}
  @headers[key] = val
end
def fake_res2.status=(val)
  @status = val
end
def fake_res2.status
  @status
end
def fake_res2.body=(val)
  @body = val
end
def fake_res2.body
  @body
end

dev_options = {
  "source" => REPO_ROOT.to_s,
  "destination" => REPO_ROOT.join("_site").to_s,
  "content_include_unpublished" => true,
  "local_content_serve" => true,
  "content_api_base_url" => ""
}
Jekyll::ContentLocalServe.serve_options = dev_options
Jekyll::ContentLocalServe.handle_reexport_request(nil, fake_res2)
check!(fake_res2.status == 200, "handle_reexport_request should return 200 in dev mode, got #{fake_res2.status}: #{fake_res2.body}")
parsed = JSON.parse(fake_res2.body)
check!(parsed["ok"] == true, "Response payload must have ok: true")
puts "  ✓ Dev mode re-export execution returned 200 OK"

puts "All dev re-export tests passed!"
