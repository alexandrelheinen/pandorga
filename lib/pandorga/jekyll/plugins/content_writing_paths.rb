# frozen_string_literal: true

# Canonical filesystem locations for articles and posts under content/.
# Shared by writing indexers, slug validation, and content-key resolution.
module ContentWritingPaths
  CONTENT_ROOT_SEGMENT = "content"

  BY_COLLECTION = {
    "articles" => "collections/articles",
    "posts" => "collections/posts"
  }.freeze

  BY_TYPE = {
    "article" => "collections/articles",
    "post" => "collections/posts"
  }.freeze

  TYPE_FOR_COLLECTION = {
    "articles" => "article",
    "posts" => "post"
  }.freeze

  COLLECTION_FOR_TYPE = TYPE_FOR_COLLECTION.invert.freeze

  # Slim runtime index covers every keyed collection xcite can resolve.
  INDEX_BY_COLLECTION = BY_COLLECTION.merge(
    "products" => "collections/products",
    "projects" => "collections/projects"
  ).freeze

  INDEX_TYPE_FOR_COLLECTION = TYPE_FOR_COLLECTION.merge(
    "products" => "product",
    "projects" => "project"
  ).freeze

  module_function

  def content_relative(type_or_collection)
    BY_COLLECTION[type_or_collection] || BY_TYPE.fetch(type_or_collection)
  end

  def repo_relative(type)
    File.join(CONTENT_ROOT_SEGMENT, BY_TYPE.fetch(type))
  end

  def repo_relative_for_collection(collection, filename = nil)
    base = File.join(CONTENT_ROOT_SEGMENT, BY_COLLECTION.fetch(collection))
    filename ? File.join(base, filename) : base
  end

  def repo_relative_for_index_collection(collection, filename = nil)
    base = File.join(CONTENT_ROOT_SEGMENT, INDEX_BY_COLLECTION.fetch(collection))
    filename ? File.join(base, filename) : base
  end
end
