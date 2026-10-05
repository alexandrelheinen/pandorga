#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "../../_plugins/git_chronology"

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

def assert_equal(expected, actual, message = nil)
  return if expected == actual

  label = message || "expected #{expected.inspect}, got #{actual.inspect}"
  raise "Assertion failed: #{label}"
end

def git!(argv, env: {}, chdir:)
  full_env = {
    "GIT_AUTHOR_NAME" => "Test",
    "GIT_AUTHOR_EMAIL" => "test@example.com",
    "GIT_COMMITTER_NAME" => "Test",
    "GIT_COMMITTER_EMAIL" => "test@example.com"
  }.merge(env)
  system(full_env, *argv, chdir: chdir) || raise("git command failed: #{argv.join(' ')}")
end

def with_temp_git_repo
  GitChronology.reset_cache!
  Dir.mktmpdir("git-chronology") do |tmpdir|
    git!(%w[git init -b main], chdir: tmpdir)
    git!(%w[git config user.name Test], chdir: tmpdir)
    git!(%w[git config user.email test@example.com], chdir: tmpdir)
    yield tmpdir
  end
end

puts "Testing GitChronology..."

with_temp_git_repo do |repo|
  path = "content/collections/articles/sample.md"
  file = File.join(repo, path)
  FileUtils.mkdir_p(File.dirname(file))

  File.write(
    file,
    <<~MARKDOWN
      ---
      title: Original title
      ---
      Body version one.
    MARKDOWN
  )
  git!(
    %W[git add #{path}],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-01-10T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-01-10T12:00:00"
    }
  )
  git!(
    %w[git commit -m create],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-01-10T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-01-10T12:00:00"
    }
  )

  File.write(
    file,
    <<~MARKDOWN
      ---
      title: Renamed title
      thumbnail: /media/images/new-thumb.png
      ---
      Body version one.
    MARKDOWN
  )
  git!(%W[git add #{path}], chdir: repo)
  git!(
    %w[git commit -m front-matter-only],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-02-15T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-02-15T12:00:00"
    }
  )

  File.write(
    file,
    <<~MARKDOWN
      ---
      title: Renamed title
      thumbnail: /media/images/new-thumb.png
      ---
      Body version two.
    MARKDOWN
  )
  git!(%W[git add #{path}], chdir: repo)
  git!(
    %w[git commit -m body-edit],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-03-20T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-03-20T12:00:00"
    }
  )

  File.write(
    file,
    <<~MARKDOWN
      ---
      title: Another title tweak
      thumbnail: /media/images/another-thumb.png
      ---
      Body version two.
    MARKDOWN
  )
  git!(%W[git add #{path}], chdir: repo)
  git!(
    %w[git commit -m front-matter-only-after-body],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-04-01T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-04-01T12:00:00"
    }
  )

  Dir.chdir(repo) do
    chronology = GitChronology.chronology_for(path, type: "article")
    assert_equal "2026-01-10", chronology["date"]
    assert_equal "2026-03-20", chronology["last_updated"], "front-matter-only commits must not advance last_updated"
    assert_equal "2026-04-01", GitChronology.git_date(path, :updated), "file-level git_date still tracks any edit"
  end
end

with_temp_git_repo do |repo|
  path = "content/collections/posts/do-avesso.md"
  file = File.join(repo, path)
  FileUtils.mkdir_p(File.dirname(file))

  File.write(
    file,
    <<~MARKDOWN
      ---
      title: Do avesso
      date: '2026-05-15'
      thumbnail: "/media/thumbnails/old.png"
      ---
      <div class="poem" markdown="1">

      Minha goela,
      meus entréns.

      </div>
    MARKDOWN
  )
  git!(
    %W[git add #{path}],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-05-15T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-05-15T12:00:00"
    }
  )
  git!(
    %w[git commit -m create-post],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-05-15T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-05-15T12:00:00"
    }
  )

  File.write(
    file,
    <<~MARKDOWN
      ---
      title: Do avesso
      date: 2026-05-15
      thumbnail: https://example.com/new-thumb.jpg
      last_updated: 2026-08-28
      ---
      <div class="poem" markdown="1">
      Minha goela,
      meus entréns.

      </div>
    MARKDOWN
  )
  git!(%W[git add #{path}], chdir: repo)
  git!(
    %w[git commit -m studio-front-matter-and-whitespace],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-08-28T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-08-28T12:00:00"
    }
  )

  Dir.chdir(repo) do
    chronology = GitChronology.chronology_for(path, type: "post")
    assert_equal "2026-05-15", chronology["date"]
    assert_equal "2026-05-15", chronology["last_updated"],
                 "CMS whitespace reformat with front-matter edits must not advance last_updated"
  end
end

with_temp_git_repo do |repo|
  # Regression for the 2026-06-19 content-path migration class of bugs: git log --follow
  # reaches _posts/… history but git show sha:content/collections/posts/… fails on those
  # commits unless the historical path is used. See docs/content/architecture.md.
  old_path = "_posts/sample.md"
  new_path = "content/collections/posts/sample.md"
  old_file = File.join(repo, old_path)
  new_file = File.join(repo, new_path)
  FileUtils.mkdir_p(File.dirname(old_file))

  File.write(
    old_file,
    <<~MARKDOWN
      ---
      title: Original
      ---
      Body version one.
    MARKDOWN
  )
  git!(%W[git add #{old_path}], chdir: repo)
  git!(
    %w[git commit -m create-at-old-path],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-05-01T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-05-01T12:00:00"
    }
  )

  File.write(
    old_file,
    <<~MARKDOWN
      ---
      title: Original
      ---
      Body version two.
    MARKDOWN
  )
  git!(%W[git add #{old_path}], chdir: repo)
  git!(
    %w[git commit -m body-edit-before-rename],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-05-15T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-05-15T12:00:00"
    }
  )

  FileUtils.mkdir_p(File.dirname(new_file))
  git!(%W[git mv #{old_path} #{new_path}], chdir: repo)
  git!(
    %w[git commit -m rename-only],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-06-19T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-06-19T12:00:00"
    }
  )

  File.write(
    new_file,
    <<~MARKDOWN
      ---
      title: Retitled after rename
      ---
      Body version two.
    MARKDOWN
  )
  git!(%W[git add #{new_path}], chdir: repo)
  git!(
    %w[git commit -m front-matter-after-rename],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-06-20T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-06-20T12:00:00"
    }
  )

  Dir.chdir(repo) do
    chronology = GitChronology.chronology_for(new_path, type: "post")
    assert_equal "2026-05-01", chronology["date"]
    assert_equal "2026-05-15", chronology["last_updated"], "rename-only migration must not advance last_updated"
  end
end

with_temp_git_repo do |repo|
  # Regression for content/articles → content/collections/articles rename (2026-07).
  old_path = "content/articles/sample.md"
  new_path = "content/collections/articles/sample.md"
  old_file = File.join(repo, old_path)
  new_file = File.join(repo, new_path)
  FileUtils.mkdir_p(File.dirname(old_file))

  File.write(
    old_file,
    <<~MARKDOWN
      ---
      title: Original
      ---
      Body version one.
    MARKDOWN
  )
  git!(%W[git add #{old_path}], chdir: repo)
  git!(
    %w[git commit -m create-at-old-article-path],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-05-10T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-05-10T12:00:00"
    }
  )

  File.write(
    old_file,
    <<~MARKDOWN
      ---
      title: Original
      ---
      Body version two.
    MARKDOWN
  )
  git!(%W[git add #{old_path}], chdir: repo)
  git!(
    %w[git commit -m body-edit-before-article-rename],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-05-18T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-05-18T12:00:00"
    }
  )

  FileUtils.mkdir_p(File.dirname(new_file))
  git!(%W[git mv #{old_path} #{new_path}], chdir: repo)
  git!(
    %w[git commit -m rename-article-into-collections],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-07-12T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-07-12T12:00:00"
    }
  )

  File.write(
    new_file,
    <<~MARKDOWN
      ---
      title: Retitled after rename
      ---
      Body version two.
    MARKDOWN
  )
  git!(%W[git add #{new_path}], chdir: repo)
  git!(
    %w[git commit -m front-matter-after-article-rename],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-07-13T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-07-13T12:00:00"
    }
  )

  Dir.chdir(repo) do
    chronology = GitChronology.chronology_for(new_path, type: "article")
    assert_equal "2026-05-10", chronology["date"]
    assert_equal "2026-05-18", chronology["last_updated"], "article rename into collections must not advance last_updated"
  end
end

with_temp_git_repo do |repo|
  # Legacy imports: filename carries the original publication date; Git first-add is later.
  path = "content/collections/posts/2021-03-17-o-espaco.md"
  file = File.join(repo, path)
  FileUtils.mkdir_p(File.dirname(file))

  File.write(
    file,
    <<~MARKDOWN
      ---
      title: O espaco
      date: 2021-03-17
      ---
      Body from the legacy platform.
    MARKDOWN
  )
  git!(%W[git add #{path}], chdir: repo)
  git!(
    %w[git commit -m import-legacy-post],
    chdir: repo,
    env: {
      "GIT_AUTHOR_DATE" => "2026-05-01T12:00:00",
      "GIT_COMMITTER_DATE" => "2026-05-01T12:00:00"
    }
  )

  Dir.chdir(repo) do
    chronology = GitChronology.chronology_for(path, type: "post")
    assert_equal "2021-03-17", chronology["date"], "creation date must follow filename/front matter, not Git first-add"
    assert_equal "2021-03-17", chronology["last_updated"], "body-only chronology with a single commit falls back to creation date"
  end
end

puts "GitChronology OK"
