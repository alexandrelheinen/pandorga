# Hero name and headline size

## Intent

The home hero should read the person's name as a given name and a family
name, and the line above that name should sit at the same size as the
summary under it. A site owner with a multi-word family name can say where
the name breaks, instead of hoping a space-split of one string is right.

## Scope

In:

- Optional `pandorga.identity.first_name` and `pandorga.identity.last_name`.
- Home hero given name and family name.
- Top-bar wordmark (first name only).
- Hero subtitle size (`home/subtitle`, the line above the name).
- Phone size and wrap of the hero name.

Out:

- `pandorga.identity.name` as the title suffix, default author, and BibTeX
  author. It stays required.
- `short_name`.
- Footer wordmark (still `site.author`).
- Font family of the subtitle. Only the size changes.

## Acceptance criteria

- `PLT-AC-13` When the home hero renders the subtitle, the system shall set
  its font size to `--type-body`, the size the summary under the name
  inherits from the page.
- `PLT-AC-14` When `first_name` or `last_name` is set, the system shall use
  that string whole (internal spaces kept). The top bar shall show
  `first_name`. When a key is omitted or blank, that part shall fall back
  to the 1.4.9 split of `identity.name` (else `site.author`): the first
  word, then up to eight remaining words. The top bar, when `first_name`
  is omitted, shall use the first word of `identity.name`, then
  `site.author`, then `site.title`.
- `PLT-AC-15` Below 768px the hero name shall be 3pt larger than the 1.4.9
  size at that width, and a wrap shall break only between the given name
  and the family name.

## Constraints

`name` remains required. Existing sites that set only `name` keep the
previous hero and, for the top bar, the first word of that name when it
is present. `last_name` is not split again.

## Design notes

`Pandorga::IdentityName.resolve` is the seam. The home layout and the shell
wordmark both call the `pandorga_hero_name` Liquid filter, so the bar and
the hero cannot drift. On a phone the two name spans are `inline-block`
with `white-space: nowrap`, so the only break is the gap between them.
The 3pt is added to the clamp that 1.4.9 already used: `--type-section`
below 640px, `--type-section-lg` from 640px to 767px.
