#!/usr/bin/env node
// build-site-pages-json.js — Build the site-pages.json file used by take-screenshots.js.
//
// Takes the static page list from visual-inspection-pages.json, appends the most
// recent article and post (from content/), and writes site-pages.json.
//
// Usage (run from repo root):
//   node scripts/visual/build-site-pages-json.js [outputFile]
//
// Arguments:
//   outputFile — Output path for the JSON file (default: site-pages.json)

'use strict';

const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const REPO_ROOT = path.resolve(path.join(__dirname, '..', '..'));
const CONTENT_ROOT = path.join(REPO_ROOT, 'content');
const ARTICLES_DIR = path.join(CONTENT_ROOT, 'collections', 'articles');
const POSTS_DIR = path.join(CONTENT_ROOT, 'collections', 'posts');

function gitChronology(repoRelativePath, type) {
  const quotedPath = repoRelativePath.replace(/'/g, "'\\''");
  const quotedType = type.replace(/'/g, "'\\''");
  const raw = execSync(
    `bundle exec ruby -rjson -e "require_relative '_plugins/git_chronology'; puts JSON.generate(GitChronology.chronology_for(ARGV[0], type: ARGV[1]))" -- '${quotedPath}' '${quotedType}'`,
    { cwd: REPO_ROOT, encoding: 'utf8' }
  ).trim();
  const chronology = JSON.parse(raw || '{}');
  return {
    date: chronology.date || '',
    last_updated: chronology.last_updated || chronology.date || '',
  };
}

function latestMarkdownSlug(dir, repoRelativeDir) {
  if (!fs.existsSync(dir)) {
    throw new Error(`Directory not found: ${dir}`);
  }

  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.md'));

  if (files.length === 0) {
    throw new Error(`No markdown files found in ${dir}`);
  }

  return files
    .map((file) => {
      const slug = file.replace(/\.md$/, '');
      const writingType = repoRelativeDir.includes('posts') ? 'post' : 'article';
      const chronology = gitChronology(path.posix.join(repoRelativeDir, file), writingType);
      return {
        slug,
        sortKey: chronology.last_updated || chronology.date || slug,
      };
    })
    .sort((a, b) => String(b.sortKey).localeCompare(String(a.sortKey)))[0].slug;
}

function main() {
  const outputFile = path.resolve(process.argv[2] || path.join(REPO_ROOT, 'site-pages.json'));

  const cfg = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'visual-inspection-pages.json'), 'utf8')
  );

  const latestArticleSlug = latestMarkdownSlug(ARTICLES_DIR, 'content/collections/articles');
  const latestPostSlug = latestMarkdownSlug(POSTS_DIR, 'content/collections/posts');

  const pages = [
    ...cfg.site,
    {
      id: 'latest-article',
      name: 'Latest Article',
      url: `/articles/${encodeURIComponent(latestArticleSlug)}/`,
    },
    {
      id: 'latest-post',
      name: 'Latest Post',
      url: `/posts/${encodeURIComponent(latestPostSlug)}/`,
    },
  ];

  fs.writeFileSync(outputFile, JSON.stringify(pages, null, 2), 'utf8');

  console.log(`Wrote ${pages.length} page(s) to ${outputFile}`);
  pages.forEach((p) => console.log(`  ${p.name} → ${p.url}`));
}

main();
