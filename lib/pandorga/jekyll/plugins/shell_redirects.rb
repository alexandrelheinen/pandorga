# frozen_string_literal: true

require "jekyll"

require_relative "../../detail_routes"

# Jekyll skips underscore files, so a source `_redirects` never reaches
# the output unless the site lists it under `include`. The published
# file is the one Cloudflare reads. Detail URLs stay on the listing
# shell, so the splat 200 lines have to be in that file. The source
# file is not edited.
Jekyll::Hooks.register :site, :post_write do |site|
  dest = File.join(site.dest, "_redirects")
  source = File.join(site.source, "_redirects")
  text = if File.file?(source)
           File.read(source)
         elsif File.file?(dest)
           File.read(dest)
         else
           ""
         end
  updated = Pandorga::DetailRoutes.ensure_shell_rewrites(text)
  next if File.file?(dest) && File.read(dest) == updated

  File.write(dest, updated)
end
