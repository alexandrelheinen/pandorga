# frozen_string_literal: true

# PLT-AC-101 — pandorga.home.hero_overlay.strength reaches --home-hero-vignette on home.

require "fileutils"
require "open3"
require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXE = ROOT.join("exe/pandorga")
errors = []

home_layout = ROOT.join("_layouts/home.html").read
unless home_layout.include?("_hero_overlay.strength") && home_layout.include?("--home-hero-vignette:")
  errors << "home.html must emit --home-hero-vignette from hero_overlay.strength (PLT-AC-101)"
end
unless home_layout.include?("default: _hero_overlay.vignette")
  errors << "home.html must fall back to hero_overlay.vignette (PLT-AC-101)"
end

css = ROOT.join("assets/css/ledger/home.css").read
unless css.include?("var(--home-hero-vignette)")
  errors << "home.css must scale overlay with --home-hero-vignette (PLT-AC-101)"
end

%w[minimal full].each do |name|
  cfg = ROOT.join("examples", name, "_config.yml").read
  unless cfg.match?(/hero_overlay:[\s\S]*?strength:\s*[\d.]+/)
    errors << "examples/#{name} must document hero_overlay.strength (PLT-AC-101)"
  end
end

def run_cmd(*cmd, chdir:, env: {})
  base = {
    "RUBYOPT" => "-I#{ROOT.join('lib')}",
    "PANDORGA_SITE_ROOT" => chdir.to_s,
    "CONTENT_API_BASE_URL" => "",
    "CONTENT_EXPORT_SKIP_VALIDATE" => "1",
    "JEKYLL_ENV" => "production"
  }
  Open3.capture3(base.merge(env), *cmd, chdir: chdir.to_s)
end

example = ROOT.join("examples/minimal")
site_cfg = YAML.safe_load(example.join("_config.yml").read)
site_cfg["pandorga"] ||= {}
site_cfg["pandorga"]["home"] ||= {}
site_cfg["pandorga"]["home"]["hero_overlay"] = { "strength" => 0.82, "pool" => 0.94 }

# Mutate example config briefly, build, assert, restore — same pattern as other example gates.
cfg_path = example.join("_config.yml")
original = cfg_path.read
begin
  cfg_path.write(YAML.dump(site_cfg))
  FileUtils.rm_rf(example.join("_site"))
  FileUtils.rm_rf(example.join("_content_json"))

  if example.join("Gemfile").file?
    _o, err, st = run_cmd("bundle", "install", "--quiet", chdir: example)
    unless st.success?
      errors << "bundle install failed: #{err[0, 400]}"
    end
  end

  if errors.empty?
    _o, err, st = run_cmd("ruby", EXE.to_s, "export", "content", "_content_json", chdir: example)
    unless st.success?
      errors << "pandorga export failed: #{err[0, 400]}"
    end
  end

  if errors.empty?
    _o, err, st = run_cmd("bundle", "exec", "jekyll", "build", "--quiet", chdir: example)
    unless st.success?
      errors << "jekyll build failed: #{err[0, 400]}"
    end
  end

  if errors.empty?
    index = example.join("_site/index.html")
    html = index.file? ? index.read : ""
    unless html.match?(/--home-hero-vignette:\s*0\.82/)
      style = html[/<style>.*?<\/style>/m].to_s[0, 400]
      errors << "built home must emit --home-hero-vignette: 0.82 from config strength (PLT-AC-101); style=#{style.inspect}"
    end
  end
ensure
  cfg_path.write(original)
  FileUtils.rm_rf(example.join("_site"))
  FileUtils.rm_rf(example.join("_content_json"))
end

if errors.empty?
  puts "OK home-hero-overlay-strength (PLT-AC-101)"
else
  warn "FAIL test-home-hero-overlay-strength:\n#{errors.join("\n")}"
  exit 1
end
