# frozen_string_literal: true

# PLT-AC-101 — pandorga.home.hero_overlay.strength reaches --home-hero-vignette on home.

require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

ROOT = File.expand_path("../..", __dir__)
errors = []

# 1) Layout prefers strength over vignette and emits the custom property.
home_layout = File.read(File.join(ROOT, "_layouts/home.html"))
unless home_layout.include?("_hero_overlay.strength") && home_layout.include?("--home-hero-vignette:")
  errors << "home.html must emit --home-hero-vignette from hero_overlay.strength (PLT-AC-101)"
end
unless home_layout.include?("default: _hero_overlay.vignette")
  errors << "home.html must fall back to hero_overlay.vignette (PLT-AC-101)"
end

# 2) Soft overlay still scales with the custom property.
css = File.read(File.join(ROOT, "assets/css/ledger/home.css"))
unless css.include?("var(--home-hero-vignette)")
  errors << "home.css must scale overlay with --home-hero-vignette (PLT-AC-101)"
end

# 3) Built example HTML carries the configured strength value.
example = File.join(ROOT, "examples/minimal")
cfg_path = File.join(example, "_config.yml")
cfg = File.read(cfg_path)
unless cfg.match?(/hero_overlay:[\s\S]*?strength:\s*0\.60/)
  errors << "examples/minimal must document hero_overlay.strength (PLT-AC-101)"
end

Dir.mktmpdir("hero-overlay-strength-") do |tmpdir|
  site = File.join(tmpdir, "site")
  FileUtils.cp_r(example, site)
  # Force a distinctive strength so we can assert it in output (not the default alone).
  conf = YAML.safe_load(File.read(File.join(site, "_config.yml")))
  conf["pandorga"] ||= {}
  conf["pandorga"]["home"] ||= {}
  conf["pandorga"]["home"]["hero_overlay"] = { "strength" => 0.82, "pool" => 0.94 }
  File.write(File.join(site, "_config.yml"), YAML.dump(conf))

  dest = File.join(tmpdir, "_site")
  cmd = [
    "mise", "exec", "--", "bundle", "exec", "jekyll", "build",
    "--source", site,
    "--destination", dest,
    "--quiet",
  ]
  # Prefer gem path from ROOT
  env = { "BUNDLE_GEMFILE" => File.join(ROOT, "Gemfile") }
  out, err, st = Open3.capture3(env, *cmd, chdir: ROOT)
  unless st.success?
    # Fallback: jekyll via mise without bundle if examples use path gem differently
    cmd2 = ["mise", "exec", "--", "jekyll", "build", "--source", site, "--destination", dest, "--quiet"]
    out, err, st = Open3.capture3(cmd2.join(" "), chdir: site)
  end
  unless st.success?
    errors << "jekyll build for strength assert failed: #{err[0, 500]}"
  else
    index = Dir[File.join(dest, "**/index.html")].find { |f| File.read(f).include?("home-hero") || File.read(f).include?("--home-hero-vignette") } ||
            File.join(dest, "index.html")
    html = File.exist?(index) ? File.read(index) : ""
    unless html.include?("--home-hero-vignette: 0.82") || html.include?("--home-hero-vignette:0.82")
      # Also accept quoted/spaced variants from liquid
      unless html.match?(/--home-hero-vignette:\s*0\.82/)
        errors << "built home must emit --home-hero-vignette: 0.82 from config strength (PLT-AC-101); got snippet: #{html[/<style>.*?<\/style>/m].to_s[0, 300]}"
      end
    end
  end
end

if errors.empty?
  puts "OK home-hero-overlay-strength (PLT-AC-101)"
else
  warn errors.join("\n")
  exit 1
end
