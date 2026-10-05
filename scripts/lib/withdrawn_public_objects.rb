# frozen_string_literal: true

# Public-store objects that must not exist after a clean publish.
module WithdrawnPublicObjects
  EXPORT_PATHS = %w[
    data/transcriptions/2026-04-11-choque-de-cultura.json
    data/tabs/roda-viva.json
    collections/posts/2026-04-17-roda-viva.json
    collections/posts/2026-04-12-falha-de-cobertura.json
    collections/posts/2026-04-11-falha-de-cobertura.json
    collections/articles/2026-07-17-soft-drones-went-to-war.json
    pages/cv/summary-detailed.json
    pages/cv/summary-short.json
    data/skills.json
  ].freeze

  STALE_PHRASES = [
    "every engineer feels",
    "three-ounce shaped explosive",
    "detecção de minas terrestres",
    "Este comentário no Reddit"
  ].freeze
end
