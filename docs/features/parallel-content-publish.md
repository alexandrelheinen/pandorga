# Parallel object-store publish

## Intent

`publish-content-to-object-store.sh` synced `collections/`, `data/` and
`pages/` one after another, then uploaded `manifest.json`, then synced
`media/`. Each step is mostly round trips to the bucket, so the publish took
about as long as the sum of its steps. The prefixes are disjoint, so they can
run at the same time. The manifest is the entry point readers fetch first,
so it goes up only once every object it can lead to is in place.

## Scope

In:

- `scripts/content/publish-content-to-object-store.sh`, which `pandorga
  publish` and CI content pipelines run.
- The `aws` availability check in `scripts/content/sync-content-json-to-r2.rb`.

Out:

- What each prefix sync uploads, skips, deletes and verifies
  (`sync-content-json-to-r2.rb`, `R2JsonSync`), and the `aws s3 sync`
  options of the media sync. They are unchanged.

## Acceptance criteria

- `PLT-AC-53` Parallel object-store publish.
  1. **Parallel prefixes.** The `collections/`, `data/` and `pages/` JSON
     syncs and the `media/` sync start together as background jobs. A
     prefix whose local directory is missing is skipped, as before.
  2. **Same semantics.** Each JSON prefix still runs
     `sync-content-json-to-r2.rb <export_root> <prefix>` (checksum skip,
     delete of remote keys absent locally, keyset, ETag and withdrawn-object
     verification). The media sync still runs `aws s3 sync` with
     `--delete --size-only` and the immutable cache control.
  3. **Manifest last.** `manifest.json` is uploaded after every job has
     finished, and only when all of them succeeded. If any job fails, the
     script exits non-zero, names the failed jobs, and does not upload the
     manifest.
  4. **Readable logs.** Each job writes to its own log, and the script
     prints the logs in a fixed order (collections, data, pages, media)
     once the jobs finish, so lines from parallel jobs never interleave.
  5. **Same PATH.** `sync-content-json-to-r2.rb` checks for `aws` on the
     PATH it runs `aws` from, not on a login shell's PATH.

## Verification

`scripts/test/test-parallel-content-publish.rb` runs the publish script
against a stateful fake `aws` on `PATH` that keeps the bucket in a
temporary directory and logs each call with its start and end time. It
checks that every object lands and stale keys are deleted, that the three
JSON prefix syncs overlap in time, that the manifest upload starts after
every other call ended, that the logs print in the fixed order, and that a
failing prefix stops the publish before the manifest. No credentials or
network are used.
