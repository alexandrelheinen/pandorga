# frozen_string_literal: true

# Refs: PLT-AC-11
require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
doc = ROOT.join("docs/configuration.md").read
registry = ROOT.join("lib/pandorga/registry.rb").read

%w[cv articles blog media network bibliography portfolio].each do |name|
  unless doc.include?(name) && registry.include?(name)
    warn "FAIL test-configuration-doc: template #{name} missing from doc or registry"
    exit 1
  end
end

unless doc.include?("pandorga.pages")
  warn "FAIL test-configuration-doc: missing pandorga.pages section"
  exit 1
end

puts "PASS test-configuration-doc"
