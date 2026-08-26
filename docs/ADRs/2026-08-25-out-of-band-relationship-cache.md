# Store Contentful entry relationships outside CoreData, in a JSON cache

- **Date:** 2026-08-25
- **Status:** Accepted — in force since `0.15.3` (2020-08-31)

> This record was written on 2026-08-25 from the commit history and the source.
> It documents an existing decision rather than a new one. The rationale below
> is reconstructed from the code comments, the changelog entries, and the commits
> cited; it is not a contemporaneous record of the discussion that produced the
> decision, and no design document from that time was found in this repository.

## Context

The library syncs a Contentful space into a CoreData database owned by the host
application. Links between entries become CoreData relationships between the
host's `NSManagedObject` subclasses.

CoreData relationships cannot express "this link exists but its target is not
currently available." When an entry that other entries reference is unpublished,
the `/sync` endpoint reports it as a deletion, the library deletes the managed
object, and CoreData nulls out every reference to it. At that point the fact
that a link ever existed is gone from the database. If the entry is republished
later, a subsequent delta sync returns the entry itself but says nothing about
the entries that pointed at it — those parents did not change — so there is
nothing left to reconnect the relationship with, and it stays `nil`
indefinitely.

The doc comment on `RelationshipCache` states the failure sequence verbatim:

1. Fetch all data.
2. Unpublish an entry that is referenced by another entry.
3. The reference is now `nil` in CoreData.
4. Publish the entry again.
5. The reference is still `nil` instead of the republished entry.

A related, narrower problem was already known: links whose target simply had not
arrived yet, because the two ends of a relationship can land on different sync
pages. `CHANGELOG.md` for `0.12.0` (2018-07-02) records that such
currently-unresolvable relationships were cached to disk so they would survive
the app being quit — contributed in
[#60](https://github.com/contentful/contentful-persistence.swift/pull/60). That
established disk-backed link state as an accepted mechanism, but it only covered
links awaiting a first resolution, not links that CoreData had already destroyed.

## Decision

Keep a complete record of every parent → field → child link in a store the
library owns, independent of CoreData, and use it to re-resolve relationships on
every sync.

Concretely, in `Sources/ContentfulPersistence/Relationships/`:

- `Relationship` is a `Codable` value describing one link. Its identity is
  `parentType,parentId,fieldName,localeCode` joined with commas, so it is stable
  across syncs and distinct per locale.
- `RelationshipData` is the container, with a forward index
  (`parentId → fieldId → Relationship`) and a reverse index
  (`childId → Set<RelationshipKeyPath>`).
- `RelationshipCache` serialises `RelationshipData` with `JSONEncoder` to a
  single file, `ContentfulPersistenceRelationships.data`, in the app's
  `.documentDirectory`.
- `RelationshipsManager` is the only surface `SynchronizationManager` uses.

`SynchronizationManager.sync(limit:dbVersion:then:)` calls
`resolveCachedRelationships` **before** requesting any new data, and
`update(with:)` calls `resolveRelationships()` on every page, so the cache is
both replayed and refreshed on each run. `migrateDbIfNeeded` wipes the cache
alongside the persistence store, keeping the two from diverging on a version
bump.

The cache is a write-ahead record of intent, not a mirror of CoreData: it holds
what the link graph *should* be, so CoreData can be repaired from it.

### Evidence

| Commit | Date | What it did |
| --- | --- | --- |
| `ab92403` "Entries Relationship Caching (#95)" | 2020-09-01 | Introduced `Relationships/` — `Relationship`, `RelationshipCache`, `RelationshipChildId`, `RelationshipsManager`, `ToOneRelationship`, `ToManyRelationship` — plus the wiring in `SynchronizationManager` and five test suites. |
| `CHANGELOG.md` `0.15.3` | 2020-08-31 | "Fixed updating relationships between entry and its parent when that entry has been unpublished and published between synchronization calls." |
| `78ba9c3` "Speed up Core Data relationship resolving (#98)" | 2020-11-23 | Added `RelationshipData` with the forward and reverse indexes, replacing linear scans over the cache. |
| `a29d080` "Fix/stale relationship cache entries (#146)" | 2024-01-20 | Removed `ToOneRelationship` / `ToManyRelationship` in favour of a single `Relationship` with a `RelationshipChildren` enum, and made locale part of the identity — a fix for stale entries accumulating in the cache. |

## Consequences

**What this buys**

- A republished entry reconnects to its parents without a full resync, which for
  a large space is the difference between a delta sync and re-downloading
  everything.
- Link state survives app termination, since it is on disk rather than in memory.
- Resolution is index-driven rather than a scan, after `78ba9c3`.

**What it costs**

- **A second source of truth.** The link graph now lives in two places, and they
  can diverge. `a29d080` exists precisely because they did: entries went stale
  in the cache and were never cleaned up. Any change to deletion or locale
  handling in `SynchronizationManager` has to consider the cache too.
- **Unbounded growth.** `RelationshipData` retains a `Relationship` for every
  link ever seen. There is no eviction policy beyond explicit `delete(parentId:)`
  calls and the wholesale `wipe()` on a `dbVersion` bump.
- **Silent failure on write.** `RelationshipCache.save()` and `wipe()` catch
  their errors and `print` them; they do not propagate. A cache that cannot be
  written degrades quietly back to the original broken behaviour.
- **Fixed location.** The file is always `.documentDirectory` +
  `ContentfulPersistenceRelationships.data`, with no way for the host app to
  choose the path. On iOS `.documentDirectory` is user-visible and included in
  iCloud/iTunes backups, which is not obviously the right place for a derived
  cache.
- **Single file, no partial writes.** The whole graph is encoded and rewritten on
  each `save()`, so cost grows with total link count rather than with the size of
  the delta.
- **Locale coupling.** Because identity includes `localeCode`, a
  `LocalizationScheme` of `.all` multiplies the number of cached relationships by
  the number of locales in the space.
