require 'date'
require 'time'

# This plugin automatically derives 'date' and 'last_updated' from Git history
# for articles and posts, ensuring Git is the single source of truth for chronology.
module Jekyll
  class GitMetadataGenerator < Generator
    safe true
    priority :high

    def generate(site)
      return unless GitChronology.git_repo?

      article_docs = site.collections["articles"]&.docs || []
      post_docs = site.collections["posts"]&.docs || []
      return if article_docs.empty? && post_docs.empty?

      (article_docs + post_docs).each do |doc|
        next unless doc.path.match?(/\.(md|markdown)$/)

        doc.data['language'] = doc.collection.label == 'articles' ? 'enus' : 'ptbr'
        GitChronology.apply!(doc.data, doc.path, doc.collection.label == 'articles' ? 'article' : 'post')

        if doc.data['date']
          begin
            doc.data['date'] = Time.parse(doc.data['date'].to_s)
          rescue ArgumentError
          end
        end

        if doc.data['last_updated']
          begin
            doc.data['last_updated'] = Time.parse(doc.data['last_updated'].to_s)
          rescue ArgumentError
          end
        end
      end

      article_docs.sort_by! { |d| d.data['last_updated'] || d.data['date'] || Time.now }.reverse!
      post_docs.sort_by! { |d| d.data['last_updated'] || d.data['date'] || Time.now }.reverse!
    end
  end
end
