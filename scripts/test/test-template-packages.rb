# frozen_string_literal: true

# Refs: PLT-AC-4 — each template ships README, template.yml, fixtures, screenshots.
require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
TEMPLATES = %w[cv articles blog media network bibliography portfolio].freeze
TEMPLATES_ROOT = ROOT.join("templates")

failed = false

TEMPLATES.each do |name|
  dir = TEMPLATES_ROOT.join(name)
  unless dir.directory?
    warn "FAIL test-template-packages: missing templates/#{name}/"
    failed = true
    next
  end

  readme = dir.join("README.md")
  unless readme.file? && readme.read.strip.length.positive?
    warn "FAIL test-template-packages: #{name} missing README.md"
    failed = true
  end

  yaml = dir.join("template.yml")
  unless yaml.file? && yaml.read.strip.length.positive?
    warn "FAIL test-template-packages: #{name} missing template.yml"
    failed = true
  end

  fixtures = dir.join("fixtures")
  unless fixtures.directory? && fixtures.children.any? { |c| c.file? }
    warn "FAIL test-template-packages: #{name} missing fixtures/ with sample files"
    failed = true
  end

  screenshots = dir.join("screenshots")
  has_shot_dir = screenshots.directory?
  has_shot_asset = has_shot_dir && screenshots.children.any? do |c|
    c.file? && (c.basename.to_s.match?(/\.(png|jpe?g|webp|gif)\z/i) || c.basename.to_s == "README.md" || c.basename.to_s == ".gitkeep")
  end
  unless has_shot_asset
    warn "FAIL test-template-packages: #{name} missing screenshots/ (asset, README, or .gitkeep)"
    failed = true
  end
end

%w[_includes/chord-tab.html _includes/transcription.html].each do |rel|
  text = ROOT.join(rel).read
  if text.include?("Exibe")
    warn "FAIL test-template-packages: #{rel} still has a Portuguese comment"
    failed = true
  end
end

exit 1 if failed

puts "PASS test-template-packages"
