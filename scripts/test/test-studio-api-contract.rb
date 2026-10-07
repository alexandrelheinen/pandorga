#!/usr/bin/env ruby
# frozen_string_literal: true
# AC-STU-01, AC-STU-02, AC-STU-09 — API surface contract (static review).
# Spec: docs/features/studio.md §5

require "pathname"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

puts "Testing Studio API contract..."

api = REPO_ROOT.join("functions/api/studio/[[path]].js")
auth = REPO_ROOT.join("functions/api/studio/_lib/auth.js")
github = REPO_ROOT.join("functions/api/studio/_lib/paths.js")
gh = REPO_ROOT.join("functions/api/studio/_lib/github.js")

[api, auth, github, gh].each do |path|
  check!(path.file?, "missing #{path.relative_path_from(REPO_ROOT)}")
end

api_src = api.read
auth_src = auth.read
paths_src = github.read
gh_src = gh.read

%w[session tree file media search rewrite pipeline-status].each do |route|
  check!(api_src.include?(route), "API router missing #{route.inspect} route")
end

check!(gh_src.include?("getContentPipelineStatus"),
       "github helper must expose getContentPipelineStatus")
check!(gh_src.include?("STUDIO_CONTENT_WORKFLOW") || api_src.include?("STUDIO_CONTENT_WORKFLOW"),
       "pipeline status must read STUDIO_CONTENT_WORKFLOW")
check!(gh_src.include?("mapWorkflowRunState"),
       "pipeline status must map Actions run status to UI state")
check!(REPO_ROOT.join("studio-app/src/api/client.js").read.include?("pipelineStatus"),
       "SPA client must call pipeline-status")
check!(REPO_ROOT.join("studio-app/src/main.js").read.include?("armPipelineWatch"),
       "SPA must watch the content pipeline after save")

check!(api_src.include?("media/folder") || api_src.include?('"folder"'),
       "API router should expose media folder create")
check!(api_src.include?("content/media"),
       "media routes must be scoped under content/media")
check!(gh_src.include?("putBinaryFile") || api_src.include?("content_base64"),
       "media upload must accept base64 binary content")
check!(auth_src.include?("STUDIO_ALLOWLIST"), "auth must read STUDIO_ALLOWLIST")
check!(auth_src.include?("Bearer"), "auth must expect Bearer JWT")
check!(gh_src.include?("GITHUB_TOKEN"), "github helper must use GITHUB_TOKEN")
check!(gh_src.include?("GITHUB_REPO is required") || gh_src.include?("GITHUB_REPO"),
       "github helper must require GITHUB_REPO")
owner_repo = %w[alexandre lheinen].join + "/website"
check!(!gh_src.include?(owner_repo),
       "github helper must not default GITHUB_REPO to a personal repo")
check!(api_src.include?("STUDIO_ALLOWED_ORIGINS"),
       "API CORS must read STUDIO_ALLOWED_ORIGINS")
owner_slug = %w[alexandre lheinen].join
check!(!api_src.include?("origin.includes(\"#{owner_slug}\")"),
       "API CORS must not allow any origin containing the owner slug")
check!(!api_src.include?('origin.includes("pages.dev")'),
       "API CORS must not allow any pages.dev project")
check!(gh_src.include?("api.github.com"), "github helper must call Contents API")
check!(gh_src.include?('err.code = conflict ? "conflict" : "github_error"') ||
         gh_src.include?("conflict"),
       "GitHub 409 must be a conflict, not a bare server_error")
check!(api_src.include?("err.code || \"server_error\""),
       "API catch-all must keep a specific error code when the throw set one")
check!(REPO_ROOT.join("studio-app/src/api/client.js").read.include?("data?.message || data?.error"),
       "SPA must show the error sentence, not only the error code")
check!(REPO_ROOT.join("studio-app/src/main.js").read.include?("state.saving"),
       "Save must ignore a second tap while a save is in flight")
check!(REPO_ROOT.join("studio-app/src/main.js").read.include?("studio-error-banner"),
       "Editor must show the failure sentence outside the truncated toolbar pill")

bundles = Dir[REPO_ROOT.join("studio/assets/index-*.js").to_s]
check!(!bundles.empty?, "committed Studio bundle missing")
keyed = bundles.any? { |path| File.read(path).match?(/pk_(?:test|live)_[A-Za-z0-9_-]{20,}/) }
check!(keyed,
       "committed Studio bundle must include a Clerk publishable key; rebuild with VITE_CLERK_PUBLISHABLE_KEY")
html = REPO_ROOT.join("studio/index.html").read
check!(html.match?(%r{/studio/assets/index-[A-Za-z0-9_-]+\.js}),
       "studio/index.html must point at the built bundle")
referenced = html[/\/studio\/assets\/(index-[A-Za-z0-9_-]+\.js)/, 1]
check!(referenced && File.exist?(REPO_ROOT.join("studio/assets", referenced)),
       "studio/index.html references a missing bundle")
check!(File.read(REPO_ROOT.join("studio/assets", referenced)).match?(/pk_(?:test|live)_[A-Za-z0-9_-]{20,}/),
       "the bundle studio/index.html loads must contain the Clerk publishable key")
check!(paths_src.include?("content/"), "path allowlist must require content/")
check!(paths_src.include?(".."), "path allowlist must reject ..")
check!(!api_src.match?(/ghp_[A-Za-z0-9]+/), "no hardcoded PAT in API")
check!(!gh_src.match?(/ghp_[A-Za-z0-9]+/), "no hardcoded PAT in github helper")

# Rate limit on mutating surface only. GETs (tree prefetch, open, cite
# search) used to share the Save bucket and the commit returned rate_limited.
check!(api_src.include?("isMutatingMethod"),
       "rate limit must apply only to mutating methods")
check!(api_src.include?("Too many changes in a short time"),
       "rate_limited must include a sentence, not only the code")
check!(api_src.include?('error: "rate_limited"'),
       "API should rate-limit requests")
check!(!api_src.include?("if (!rateLimit(request, auth.userId))"),
       "do not rate-limit every authenticated request")
check!(gh_src.include?("github_rate_limited"),
       "GitHub 403/429 rate limits need their own sentence")

puts "All Studio API contract checks passed."
