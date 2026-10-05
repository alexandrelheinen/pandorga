# Contributing

Follow Specification-Driven Development and the V-cycle in `.guidelines/`
(initialize with `git submodule update --init .guidelines`).

1. Link work to `PLT-*` / `PLT-AC-*` ids in [docs/spec.md](docs/spec.md).
2. Write a failing gate first, then implement.
3. Run `mise exec -- ./scripts/validate.sh` before every push.
4. Use Conventional Commits with a `Refs: PLT-…` footer.
5. Do not merge your own PRs; a human merges.

Never commit secrets, real Clerk issuers, R2 bucket IDs, or personal identity
into this repository. Examples use `example.com` only.
