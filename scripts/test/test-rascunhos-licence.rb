#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-27. Below 1024px the Rascunhos licence follows the entries.
# writing.css had this order. The per-page sheet split stopped loading that
# file on the blog layout, and `.rascunhos-body { display: block }` put the
# licence back above the texts. The winning rule lives in rascunhos.css.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-rascunhos-licence: #{message}"
  exit 1
end

shell = ROOT.join("_layouts/shell.html").read
blog = shell[/when "blog".*?assign _ledger = "([^"]+)"/m, 1]
fail!("blog layout has no ledger list") unless blog
sheets = blog.split("|")
rascunhos_at = sheets.index("rascunhos")
writing_at = sheets.index("writing")
fail!("blog layout does not load rascunhos.css") unless rascunhos_at
fail!("blog layout does not load writing.css after rascunhos.css") unless writing_at && writing_at > rascunhos_at

css = ROOT.join("assets/css/ledger/rascunhos.css").read
block_at = css.index(".rascunhos-body {\n  display: block;")
rule_at = css.index(".rascunhos-main .rascunhos-body {\n    display: flex;")
licence_at = css.index(".rascunhos-main .writing-rail-licence {")
ledger_at = css.index(".rascunhos-main .rascunhos-body>.rascunhos-ledger {")
hidden_at = css.index(".rascunhos-main .rascunhos-body.hidden {\n  display: none;")

fail!("rascunhos body is no longer display:block at rest") unless block_at
fail!("mobile column is missing from rascunhos.css") unless rule_at && rule_at > block_at
fail!("mobile column is not limited to the disclosure width") unless css.index("@media (max-width: 1023px)")&.< rule_at
fail!("licence has no colophon order") unless licence_at && css[licence_at, 180].include?("order: 2")
fail!("ledger is not ordered ahead of the licence") unless ledger_at && ledger_at < licence_at && css[ledger_at, 120].include?("order: 1")
fail!("detail view can no longer hide the listing") unless hidden_at && hidden_at > rule_at
fail!("rail no longer dissolves so the licence can leave it") unless css.include?(".rascunhos-main .rascunhos-body>.writing-rail:not([hidden])") &&
  css.include?("display: contents")

puts "PASS test-rascunhos-licence"
