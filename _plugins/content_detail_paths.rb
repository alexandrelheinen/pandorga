# frozen_string_literal: true

# Shared detail URL rewrite rules for Cloudflare _redirects and local jekyll serve.
module ContentDetailPaths
  POST_SHELL = "/pages/blog/"
  ARTICLE_SHELL = "/pages/articles/"
  PRODUCT_SHELL = "/pages/cv/"
  PROJECT_SHELL = "/pages/projects/"

  POST_DETAIL_RE = %r{\A/posts/[^./][^/]*/?\z}
  BLOG_DETAIL_RE = %r{\A/blog/[^./][^/]*/?\z}
  ARTICLE_DETAIL_RE = %r{\A/articles/[^./][^/]*/?\z}
  PRODUCT_DETAIL_RE = %r{\A/products/[^./][^/]*/?\z}
  PROJECT_DETAIL_RE = %r{\A/projects/[^./][^/]*/?\z}

  REWRITES = [
    [POST_DETAIL_RE, POST_SHELL],
    [BLOG_DETAIL_RE, POST_SHELL],
    [ARTICLE_DETAIL_RE, ARTICLE_SHELL],
    [PRODUCT_DETAIL_RE, PRODUCT_SHELL],
    [PROJECT_DETAIL_RE, PROJECT_SHELL]
  ].freeze

  RESERVED = [
    POST_SHELL,
    ARTICLE_SHELL,
    PRODUCT_SHELL,
    PROJECT_SHELL
  ].freeze

  module_function

  def rewrite_path(path)
    normalized = path.end_with?("/") ? path : "#{path}/"
    return nil if RESERVED.include?(normalized)

    REWRITES.each do |pattern, target|
      return target if pattern.match?(path) || pattern.match?(normalized)
    end
    nil
  end

  def post_detail_path(slug)
    "/posts/#{slug}/"
  end

  def article_detail_path(slug)
    "/articles/#{slug}/"
  end

  def product_detail_path(slug)
    "/products/#{slug}/"
  end

  def project_detail_path(slug)
    "/projects/#{slug}/"
  end
end
