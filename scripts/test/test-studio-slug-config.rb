#!/usr/bin/env ruby
# frozen_string_literal: true
# AC-STU: Studio schema replaces .pages.yml as the live CMS model.
# Spec: docs/features/studio.md

require "date"
require "pathname"
require "yaml"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
CONFIG_PATH = REPO_ROOT.join("studio/schema.yml")

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

def each_content_entry(nodes, &block)
  Array(nodes).each do |entry|
    next unless entry.is_a?(Hash)

    type = entry["type"].to_s
    if type == "group"
      each_content_entry(entry["items"], &block)
    else
      yield entry
    end
  end
end

def find_collection(config, name)
  found = nil
  each_content_entry(config["content"]) do |entry|
    found = entry if entry["type"].to_s == "collection" && entry["name"].to_s == name
  end
  found
end

def field_names(collection)
  (collection["fields"] || []).map { |field| field["name"].to_s }
end

puts "Testing Studio schema (studio/schema.yml)..."

check!(CONFIG_PATH.file?, "missing studio/schema.yml")

config = YAML.safe_load(CONFIG_PATH.read, permitted_classes: [Date, Time], aliases: true) || {}
check!(config["media"].is_a?(Hash) || config["media"].is_a?(String) || config["media"].is_a?(Array),
       "studio/schema.yml must define media")

media = config["media"]
media_input = nil
if media.is_a?(Hash)
  media_input = media["input"].to_s
  check!(media_input.include?("content/media"),
         "schema media.input must point under content/media")
  check!(media["output"].to_s.start_with?("/media"),
         "schema media.output must be a /media public path")
elsif media.is_a?(Array)
  images = media.find { |entry| entry.is_a?(Hash) && entry["name"].to_s == "images" } || media.first
  media_input = images.is_a?(Hash) ? images["input"].to_s : nil
end

if media_input && !media_input.empty?
  each_content_entry(config["content"]) do |entry|
    (entry["fields"] || []).each do |field|
      next unless field.is_a?(Hash) && field["type"].to_s == "image"

      path = field.dig("options", "path").to_s
      next if path.empty?

      check!(path == media_input || path.start_with?("#{media_input}/"),
             "#{entry['name']}.#{field['name']} options.path must start with media.input " \
             "(#{media_input.inspect}); got #{path.inspect}")
    end
  end
end

posts = find_collection(config, "posts")
articles = find_collection(config, "articles")
check!(!posts.nil?, "missing posts collection in studio/schema.yml")
check!(!articles.nil?, "missing articles collection in studio/schema.yml")

check!(posts["format"].to_s == "yaml-frontmatter",
       "posts must use yaml-frontmatter")
check!(articles["format"].to_s == "yaml-frontmatter",
       "articles must use yaml-frontmatter")
check!(posts.dig("operations", "delete") == false,
       "posts operations.delete must be false")
check!(articles.dig("operations", "delete") == false,
       "articles operations.delete must be false")

posts_fields = field_names(posts)
articles_fields = field_names(articles)

check!(!posts_fields.include?("description"),
       "posts must not expose description (excerpts come from the body)")
check!(!posts_fields.include?("last_updated"),
       "posts must not expose last_updated (build derives it from Git)")
check!(!articles_fields.include?("last_updated"),
       "articles must not expose last_updated (build derives it from Git)")
check!(articles_fields.include?("description"),
       "articles must keep description for editorial deck copy")

filename = posts["filename"].to_s
check!(filename.include?("{year}") && filename.include?("{key}"),
       "posts filename must be dated + key (got #{filename.inspect})")
articles_filename = articles["filename"].to_s
check!(articles_filename.include?("{year}") && articles_filename.include?("{key}"),
       "articles filename must be dated + key (got #{articles_filename.inspect})")
check!(posts.dig("view", "primary").to_s == "title",
       "posts list primary should stay title (filename uses key separately)")
check!(articles.dig("view", "primary").to_s == "title",
       "articles list primary should stay title (filename uses key separately)")

%w[posts articles].each do |name|
  collection = name == "posts" ? posts : articles
  key_field = (collection["fields"] || []).find { |field| field["name"].to_s == "key" }
  check!(!key_field.nil?, "#{name} must define a key field")
  check!(key_field["required"] == true, "#{name} key must be required for filename creation")
end

products = find_collection(config, "products")
projects = find_collection(config, "projects")
check!(!products.nil?, "missing products collection")
check!(!projects.nil?, "missing projects collection")
check!(products["filename"].to_s.include?("{key}"),
       "products filename must use key (got #{products['filename'].inspect})")
check!(projects["filename"].to_s.include?("{key}"),
       "projects filename must use key (got #{projects['filename'].inspect})")

pipeline = REPO_ROOT.join(".github/workflows/content-pipeline.yml").read
on_push = pipeline[/\non:\n  push:\n(?:    .*\n)*/]
check!(!on_push.nil? && !on_push.include?("paths:"),
       "content-pipeline.yml on.push must not use paths: (CMS commits must always trigger)")
check!(!pipeline.include?("MODE=skip"),
       "content-pipeline.yml must not skip empty CMS commits: those still need an R2 publish")
check!(pipeline.include?("if: github.ref == 'refs/heads/main'"),
       "content-pipeline.yml must publish on main for push and manual run")
check!(!pipeline.match?(/sveltia/i),
       "content-pipeline.yml must not reference Sveltia")

index = REPO_ROOT.join("studio/index.html").read
check!(!index.include?("app.pagescms.org"),
       "studio/index.html must not redirect to Pages CMS (AC-STU-08)")
check!(!index.match?(/sveltia/i),
       "studio/index.html must not load or mention Sveltia")
check!(index.include?("studio-logo"),
       "studio/index.html must use the Studio logo favicon")
check!(index.include?('id="app"') || index.include?("src/main"),
       "studio/index.html must mount the Studio SPA")

api = REPO_ROOT.join("functions/api/studio/[[path]].js")
check!(api.file?, "missing functions/api/studio/[[path]].js")
api_src = api.read
check!(api_src.include?("STUDIO_ALLOWLIST") || REPO_ROOT.join("functions/api/studio/_lib/auth.js").read.include?("STUDIO_ALLOWLIST"),
       "Studio API must enforce STUDIO_ALLOWLIST")
check!(REPO_ROOT.join("functions/api/studio/_lib/github.js").read.include?("GITHUB_TOKEN"),
       "Studio API must use server-side GITHUB_TOKEN")
check!(!api_src.include?("ghp_"), "API must not hardcode a GitHub PAT (AC-STU-09)")

editor = REPO_ROOT.join("studio-app/src/editor/body-editor.js").read
check!(editor.include?("autolink: false"),
       "TipTap Link must set autolink: false (AC-STU-03)")
check!(editor.include?("linkOnPaste: false"),
       "TipTap Link must set linkOnPaste: false")

puts "All Studio schema / shell checks passed."
