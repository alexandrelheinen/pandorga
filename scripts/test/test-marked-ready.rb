#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-107. marked stays deferred, but every painted markdown path waits
# for window.marked.parse. A silent escapeHtml fallback must not ship.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-marked-ready: #{message}"
  exit 1
end

config = ROOT.join("_includes/content-runtime/00-config.html").read
markdown = ROOT.join("_includes/content-runtime/20-markdown.html").read
detail = ROOT.join("_includes/content-runtime/50-detail.html").read
fragments = ROOT.join("_includes/content-runtime/60-fragments.html").read
bootstrap = ROOT.join("_includes/content-runtime/90-bootstrap.html").read
home = ROOT.join("_layouts/home.html").read
cv = ROOT.join("_layouts/cv.html").read
spec = ROOT.join("docs/spec.md").read
feature = ROOT.join("docs/features/marked-ready.md").read
validate = ROOT.join("scripts/validate.sh").read

fail!("markdown library lost defer") unless config.match?(%r{<script defer src="https://cdn\.jsdelivr\.net/npm/marked@15\.0\.7/marked\.min\.js"></script>})
fail!("missing marked ready gate on window") unless config.include?("__pandorgaMarked")
fail!("missing deferred companion that resolves the marked gate") unless config.match?(/<script defer>\s*\(function \(\) \{[\s\S]*__pandorgaMarked[\s\S]*\}\)\(\);\s*<\/script>/m) ||
  config.match?(/<script defer>[\s\S]*__pandorgaMarked[\s\S]*<\/script>/m)
fail!("companion script must follow the marked library tag") unless config.index("marked.min.js") < config.index("__pandorgaMarked") &&
  config.rindex("<script defer>") > config.index("marked.min.js")

fail!("ensureMarked is missing") unless markdown.include?("function ensureMarked")
fail!("renderMarkdown still escapes raw source when marked is absent") if markdown.match?(/function renderMarkdown\([\s\S]*?if \(window\.marked && typeof window\.marked\.parse === 'function'\) \{[\s\S]*?\} else \{[\s\S]*?escapeHtml\(block\)/)
fail!("parseInlineMarkdown still escapes raw source when marked is absent") if markdown.match?(/function parseInlineMarkdown\([\s\S]*?if \(window\.marked && typeof window\.marked\.parse === 'function'\) \{[\s\S]*?\} else \{[\s\S]*?escapeHtml\(math\.text\)/)

fail!("renderRichContent does not wait for ensureMarked") unless detail.match?(/async function renderRichContent[\s\S]*ensureMarked\(/m) &&
  detail.match?(/async function renderRichContent[\s\S]*await markedPromise/m)
fail!("mountMarkdownFragment does not wait for ensureMarked") unless fragments.match?(/function mountMarkdownFragment[\s\S]*ensureMarked\(/m)
fail!("ensureMarked is not exported") unless bootstrap.include?("ensureMarked: ensureMarked")
fail!("home early paint does not wait for ensureMarked") unless home.match?(/ensureMarked\([\s\S]*renderMarkdown|renderMarkdown[\s\S]*ensureMarked/) ||
  home.include?("ensureMarked().then")
fail!("CV job markdown does not wait for ensureMarked") unless cv.include?("ensureMarked")

fail!("spec is missing PLT-AC-107") unless spec.include?("PLT-AC-107")
fail!("feature doc is missing PLT-AC-107") unless feature.include?("PLT-AC-107")
fail!("validate.sh does not run test-marked-ready") unless validate.include?("scripts/test/test-marked-ready.rb")

puts "PASS test-marked-ready"
