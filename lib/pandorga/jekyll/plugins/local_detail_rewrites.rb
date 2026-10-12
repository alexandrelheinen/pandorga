# frozen_string_literal: true

require "jekyll/commands/serve"
require "json"
require "net/http"
require "uri"
require_relative "content_detail_paths"

# Mirrors Cloudflare _redirects detail rewrites during `jekyll serve` so
# /posts/:slug/ and /articles/:slug/ work locally without per-slug HTML files.
# Also handles the local dev re-export endpoint and proxies /api/studio/* to
# `wrangler pages dev` (./scripts/studio-api-dev.sh, default :8788).
module Jekyll
  module ContentDetailRewrites
    REEXPORT_PATHS = ["/__dev/reexport", "/api/dev/reexport"].freeze
    STUDIO_API_PREFIX = "/api/studio"
    STUDIO_API_DEFAULT_ORIGIN = "http://127.0.0.1:8788"

    module_function

    def studio_api_proxy_enabled?
      env = ENV["STUDIO_API_PROXY"]
      return false if env == "0" || env == "false"

      true
    end

    def studio_api_path?(path)
      path == STUDIO_API_PREFIX || path.start_with?("#{STUDIO_API_PREFIX}/")
    end

    def studio_api_origin
      ENV.fetch("STUDIO_API_ORIGIN", STUDIO_API_DEFAULT_ORIGIN)
    end

    def proxy_studio_api!(req, res)
      origin = studio_api_origin
      target = URI.join(origin.end_with?("/") ? origin : "#{origin}/", req.path.sub(%r{\A/}, ""))
      target.query = req.query_string unless req.query_string.to_s.empty?

      http = Net::HTTP.new(target.host, target.port)
      http.open_timeout = 2
      http.read_timeout = 60
      http.use_ssl = target.scheme == "https"

      upstream =
        case req.request_method
        when "GET" then Net::HTTP::Get.new(target)
        when "PUT" then Net::HTTP::Put.new(target)
        when "POST" then Net::HTTP::Post.new(target)
        when "OPTIONS" then Net::HTTP::Options.new(target)
        when "HEAD" then Net::HTTP::Head.new(target)
        else
          res.status = 405
          res["Content-Type"] = "application/json; charset=utf-8"
          res.body = '{"error":"method_not_allowed"}'
          return
        end

      %w[Authorization Content-Type Accept Origin].each do |name|
        value = req[name]
        upstream[name] = value if value && !value.empty?
      end

      if %w[PUT POST].include?(req.request_method)
        body = req.body
        upstream.body = body if body
      end

      begin
        response = http.request(upstream)
      rescue StandardError => e
        res.status = 502
        res["Content-Type"] = "application/json; charset=utf-8"
        res.body = JSON.generate(
          error: "studio_api_unavailable",
          message: "Proxy to #{origin} failed: #{e.class}: #{e.message}. " \
                   "Start ./scripts/studio-api-dev.sh (wrangler pages dev)."
        )
        return
      end

      res.status = response.code.to_i
      response.each_header do |key, value|
        next if %w[transfer-encoding connection content-length].include?(key.downcase)

        res[key] = value
      end
      res.body = response.body
    end

    def install_serve_patch!
      require "jekyll/commands/serve/servlet"
      servlet = Jekyll::Commands::Serve::Servlet
      return if servlet.method_defined?(:content_detail_do_GET)

      servlet.alias_method :content_detail_do_GET, :do_GET
      servlet.class_eval do
        def do_GET(req, res)
          if ContentDetailRewrites.studio_api_proxy_enabled? &&
             ContentDetailRewrites.studio_api_path?(req.path)
            ContentDetailRewrites.proxy_studio_api!(req, res)
            return
          end

          if ContentDetailRewrites::REEXPORT_PATHS.include?(req.path)
            if defined?(ContentLocalServe)
              ContentLocalServe.handle_reexport_request(req, res)
            else
              res.status = 501
              res["Content-Type"] = "text/plain"
              res.body = "Dev re-export handler not loaded"
            end
            return
          end

          target = ContentDetailPaths.rewrite_path(req.path)
          if target
            req.instance_variable_set(:@path, target)
            req.instance_variable_set(:@path_info, target)
          end
          content_detail_do_GET(req, res)

          if req.path.end_with?(".json")
            res["Cache-Control"] = "no-cache, no-store, must-revalidate"
            res["Pragma"] = "no-cache"
            res["Expires"] = "0"
          end
        end

        def do_POST(req, res)
          if ContentDetailRewrites.studio_api_proxy_enabled? &&
             ContentDetailRewrites.studio_api_path?(req.path)
            ContentDetailRewrites.proxy_studio_api!(req, res)
            return
          end

          if ContentDetailRewrites::REEXPORT_PATHS.include?(req.path)
            if defined?(ContentLocalServe)
              ContentLocalServe.handle_reexport_request(req, res)
            else
              res.status = 501
              res["Content-Type"] = "text/plain"
              res.body = "Dev re-export handler not loaded"
            end
            return
          end

          res.status = 405
          res["Content-Type"] = "text/plain"
          res.body = "Method Not Allowed"
        end

        def do_PUT(req, res)
          if ContentDetailRewrites.studio_api_proxy_enabled? &&
             ContentDetailRewrites.studio_api_path?(req.path)
            ContentDetailRewrites.proxy_studio_api!(req, res)
            return
          end

          res.status = 405
          res["Content-Type"] = "text/plain"
          res.body = "Method Not Allowed"
        end

        def do_OPTIONS(req, res)
          if ContentDetailRewrites.studio_api_proxy_enabled? &&
             ContentDetailRewrites.studio_api_path?(req.path)
            ContentDetailRewrites.proxy_studio_api!(req, res)
            return
          end

          res.status = 204
        end
      end
    end
  end

  module Commands
    class Serve
      class << self
        unless method_defined?(:content_detail_original_process)
          alias_method :content_detail_original_process, :process

          def process(options)
            ContentLocalServe.store_serve_options(options) if defined?(ContentLocalServe)
            ContentDetailRewrites.install_serve_patch!
            content_detail_original_process(options)
          end
        end
      end
    end
  end
end
