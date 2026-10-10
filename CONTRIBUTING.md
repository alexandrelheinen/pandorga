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

## Releases

Lighthouse mobile is a mandatory validation tool. Run it once on the home
page. Do not stack runs to hunt a prettier number.

- A stable release must score 90 or above.
- A score from 75 to 89 is acceptable only to ship a bug fix. A slower release is better than a broken one.
- Immediately after that release, an urgent performance campaign must
  bring the score back to 90 or above.
- Below 75 is never acceptable.

CI runs `./scripts/lighthouse-home.sh` once on the built example home. The
run fails below 75 and warns below 90. A warning is not permission to ship
a feature under 90. The normative text is `PLT-AC-24` in
[docs/spec.md](docs/spec.md).
