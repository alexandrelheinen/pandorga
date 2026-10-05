#!/usr/bin/env ruby
# frozen_string_literal: true

# Refs: PLT-AC-11
require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
GENERATOR = ROOT.join("scripts/generate-configuration-doc.rb")
SCHEMA = ROOT.join("lib/pandorga/registry/schema.yml")
DOC = ROOT.join("docs/configuration.md")

unless SCHEMA.file?
  warn "FAIL test-configuration-doc: missing #{SCHEMA}"
  exit 1
end

unless DOC.file?
  warn "FAIL test-configuration-doc: missing #{DOC}"
  exit 1
end

stdout, stderr, status = Open3.capture3("ruby", GENERATOR.to_s, "--check")
unless status.success?
  warn "FAIL test-configuration-doc: #{stderr}\n#{stdout}"
  exit 1
end

%w[cv articles blog media network bibliography portfolio].each do |name|
  next if DOC.read.include?(name) && SCHEMA.read.include?(name)

  warn "FAIL test-configuration-doc: template #{name} missing from doc or schema"
  exit 1
end

puts "PASS test-configuration-doc"
