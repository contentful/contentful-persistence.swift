# Architectural Decision Records

Records of non-obvious decisions this repository has made, why, and what they
cost. One file per decision, named `YYYY-MM-DD-<kebab-case-title>.md`.

Everything else under `docs/` is generated Jazzy API reference output
(`Scripts/reference-docs.sh`) — this directory is the only hand-written part.

## Records

- [2026-08-25 — Store Contentful entry relationships outside CoreData, in a JSON cache](2026-08-25-out-of-band-relationship-cache.md) — why `Sources/ContentfulPersistence/Relationships/` keeps its own on-disk link graph instead of relying on CoreData relationships alone.

## Adding a record

Add the file, add one line to the list above, and reference it from
[ARCHITECTURE.md](../../ARCHITECTURE.md) if it explains something a reader of
that document would otherwise trip over. See
[CONTRIBUTING.md](../../CONTRIBUTING.md) for when a record is warranted.
