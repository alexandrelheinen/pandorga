#!/usr/bin/env ruby
# frozen_string_literal: true
# AC-PRF-01, AC-PRF-02, AC-PRF-04, AC-PRF-12 — rewrite API surface (static).
# Spec: docs/features/studio-proof.md §11

require "pathname"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

puts "Testing Studio rewrite API contract..."

api = REPO_ROOT.join("functions/api/studio/[[path]].js")
rewrite = REPO_ROOT.join("functions/api/studio/_lib/rewrite.js")
sanitize = REPO_ROOT.join("functions/api/studio/_lib/sanitize.js")
prompts = REPO_ROOT.join("functions/api/studio/_lib/prompts.js")
gemini = REPO_ROOT.join("functions/api/studio/_lib/gemini.js")
guidelines = REPO_ROOT.join("functions/api/studio/_lib/guidelines.js")
client = REPO_ROOT.join("studio-app/src/api/client.js")

[api, rewrite, sanitize, prompts, gemini, guidelines, client].each do |path|
  check!(path.file?, "missing #{path.relative_path_from(REPO_ROOT)}")
end

api_src = api.read
rewrite_src = rewrite.read
prompts_src = prompts.read
client_src = client.read

check!(api_src.include?('"rewrite"') || api_src.include?("head === \"rewrite\""),
       "API router must expose rewrite")
check!(api_src.include?("runRewrite"), "API must call runRewrite")
check!(api_src.include?("rewriteRateLimit"), "dedicated rewrite rate limit")
check!(!rewrite_src.include?("putFile"), "rewrite must not write GitHub")
check!(prompts_src.include?("CORRECT_SYSTEM") || prompts_src.include?("mechanical corrector"),
       "correct prompt present")
check!(prompts_src.include?("Writing guidelines") || prompts_src.include?("guidelines pack"),
       "refine prompt embeds guidelines")
check!(prompts_src.include?("tone consistency") || prompts_src.include?("Preserve tone"),
       "AC-PRF-17 tone instruction")
check!(prompts_src.include?("REFINE_SCHEMA") || prompts_src.include?("block"),
       "refine schema uses block-indexed patches")
blocks = REPO_ROOT.join("functions/api/studio/_lib/blocks.js")
check!(blocks.file?, "missing blocks.js chunker")
check!(rewrite_src.include?("splitIntoBlocks") || rewrite_src.include?("flattenBlockPatches"),
       "rewrite orchestrates block flatten")
check!(client_src.include?("rewrite:"), "SPA client exposes rewrite")
check!(!client_src.match?(/AIza[0-9A-Za-z_-]{10,}/), "no Gemini key in client")
check!(!api_src.match?(/AIza[0-9A-Za-z_-]{10,}/), "no Gemini key in API router")
main_spa = REPO_ROOT.join("studio-app/src/main.js")
check!(main_spa.file?, "missing studio-app main")
main_src = main_spa.read
check!(main_src.include?("resolveAiProofTarget") || main_src.include?("wholeBody"),
       "SPA falls back to full body when selection is empty")

puts "All Studio rewrite API contract checks passed."
