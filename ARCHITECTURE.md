# Architecture

`contentful-persistence.swift` maps a Contentful space onto a local CoreData
database. It does not define the CoreData model — the host application does, by
conforming its own `NSManagedObject` subclasses to protocols this library
declares. The library's job is to drive the Content Delivery API `/sync`
endpoint through [contentful.swift](https://github.com/contentful/contentful.swift)
and to write each page of results into those managed objects.

Everything shipped lives in `Sources/ContentfulPersistence/` — 18 files, about
2,300 lines. There is no separate app or example target in this repository.

## The seam with the host application

`Sources/ContentfulPersistence/Persistable.swift` defines the contract:

- `ContentSysPersistable` — `id`, `localeCode`, `createdAt`, `updatedAt`. The
  base for anything the library writes.
- `EntryPersistable` — an entry type. Carries `static var contentTypeId` and an
  optional `static func fieldMapping() -> [FieldName: String]` that overrides the
  automatic Contentful-field-to-CoreData-property mapping.
- `AssetPersistable` — a media asset: `title`, `assetDescription`, `urlString`,
  plus file metadata.
- `SyncSpacePersistable` — the sync bookkeeping row: `syncToken` and `dbVersion`.
  There is exactly one of these per store; the library reads and writes it.

The host bundles those three kinds into a `PersistenceModel`
(`spaceType`, `assetType`, `entryTypes`) and hands it to
`SynchronizationManager`. The types must also exist as entities in the app's
`.xcdatamodeld`; the library resolves them by `String(describing: class)`
(`CoreDataStore.fetchRequest(for:predicate:)`), so entity name and class name
have to match.

## Control flow of a sync

`Sources/ContentfulPersistence/SynchronizationManager.swift` (~925 lines, the
largest file in the repo) is the centre of the system. It conforms to
`Contentful.PersistenceIntegration`, and `init` sets
`client.persistenceIntegration = self`, so the SDK client pushes each sync page
back into this class rather than the manager pulling pages itself.

`sync(limit:dbVersion:then:)` does, in order:

1. `migrateDbIfNeeded(dbVersion:)` — compares the requested `dbVersion` against
   the one stored on the `SyncSpacePersistable` row. If the stored version is
   lower, it wipes the persistence store, wipes the relationship cache, and
   clears the in-memory mapping caches. This is a destructive resync, not a
   schema migration.
2. `resolveCachedRelationships` — replays relationships recorded on a previous
   run before any new data arrives.
3. `syncSafely` — calls `client.sync(for:)` with the stored `syncToken` if there
   is one, otherwise an initial sync.

Each page arrives at `update(with syncSpace:)`, which runs inside
`persistentStore.performAndWait` and creates assets, creates entries, applies
deletions, calls `resolveRelationships()`, and stores the new sync token.

`save()` is deliberately called **only when `syncSpace.hasMorePages == false`**.
The comment at `SynchronizationManager.swift:290` explains why: CoreData
validates non-optional relationships at `save()` time, and the two ends of a
relationship can arrive on different sync pages. Saving per page would fail
validation on a model that marks a relationship as required.

## Localization

`LocalizationScheme` (`.default`, `.one(LocaleCode)`, `.all`) decides how many
rows exist per Contentful resource. Under `.all`, one managed object is created
per locale, and the identity of a row is the pair `(id, localeCode)` — which is
why the `predicate(...)` free functions at the top of
`SynchronizationManager.swift` all match on both, and why `DataCache.cacheKey`
is `id + "_" + localeCode`. Callers fetching from CoreData under `.all` must
filter on `localeCode` themselves.

## Relationship resolution

CoreData alone cannot represent a Contentful link whose target is currently
unpublished — the reference is simply `nil`, and when the target is republished
CoreData has nothing left to reconnect. `Sources/ContentfulPersistence/Relationships/`
exists to solve that. It keeps its own record of every parent-field-child link
outside CoreData:

- `Relationship` — one link. Identity is
  `parentType,parentId,fieldName,localeCode` joined by commas, so it is stable
  across syncs and per-locale. `Codable`.
- `RelationshipChildren` / `RelationshipChildId` — the `.one` / `.many` cases and
  the child's `(id, localeCode)`.
- `RelationshipData` — the container, with a forward index
  (`parentId → fieldId → Relationship`) and a reverse index
  (`childId → Set<RelationshipKeyPath>`) so a republished child can be looked up
  without scanning.
- `RelationshipCache` — persists `RelationshipData` as JSON in the app's
  documents directory, under the filename
  `ContentfulPersistenceRelationships.data`
  (`SynchronizationManager.Constants.cacheFileName`).
- `RelationshipsManager` — the façade `SynchronizationManager` actually talks to.

The rationale, its history, and its trade-offs are recorded in
[docs/ADRs/2026-08-25-out-of-band-relationship-cache.md](docs/ADRs/2026-08-25-out-of-band-relationship-cache.md).

`deletedRelationshipSentinel = -1` (`SynchronizationManager.swift:38`) marks, in
the in-memory `relationshipsToResolve` dictionary, a relationship that should be
cleared rather than set — a sentinel is used because the dictionary values are
`Any`.

## Storage abstraction

`PersistenceStore` (`PersistenceStore.swift`) is the write surface:
`create`, `delete`, `fetchAll`, `fetchOne`, `properties(for:)`,
`relationships(for:)`, `save`, `wipe`, and the `performBlock` /
`performAndWait` scheduling hooks. `CoreDataStore` is the only implementation
shipped; `Tests/ContentfulPersistenceTests/Mocks/MockPersistenceStore.swift` is
the other one that exists. Nothing in `SynchronizationManager` references
`NSManagedObjectContext` directly for storage — it goes through the protocol.

`DataCache.swift` sits in front of reads during a sync. `DataCache` is
`NSCache`-backed; `NoDataCache` implements the same `DataCacheProtocol` but
reads straight through to the store, so caching can be turned off without
branching at the call sites.

## Two seeding paths

`Sources/ContentfulPersistence/Seeding/` ships two unrelated ways to start from
pre-existing content instead of a cold initial sync:

- **`JSON/`** — `seedDBFromJSONFiles(in:in:)` reads a directory of sync-response
  JSON files out of a bundle, decodes `locales.json` first to establish the
  localization context, then walks numbered page files (`0.json`, `1.json`, …)
  through the same `update(with:)` path a live sync uses.
- **`BundledDatabase/`** — copies a pre-built `.sqlite` out of the app bundle
  into the CoreData container directory. `PreseedConfiguration` names the
  resource and the target directory and carries a `dbVersion`;
  `PreseedStrategy` is the injectable protocol; `FilePreseedManager` is the
  default implementation (wipe the folder, copy, write back `dbVersion`).
  `FileManaging` exists purely so tests can substitute the file system.

The `dbVersion` on `SyncSpacePersistable` is what ties the bundled-database path
to `migrateDbIfNeeded` — bumping it in the app forces the newer seed to replace
an older local database.

## Build and packaging

The same `Sources/**/*.swift` is exposed four ways, and all four must agree:

| System | File | Notes |
| --- | --- | --- |
| Swift Package Manager | `Package.swift` | `swift-tools-version:4.0`. One `ContentfulPersistence` library target, one dependency: `contentful.swift` `.upToNextMajor(from: "5.5.13")`. No test target is declared — SPM builds the library only, which is what the `build` fastlane lane checks (`swift build`). |
| CocoaPods | `ContentfulPersistenceSwift.podspec` | Pod name `ContentfulPersistenceSwift`, module name `ContentfulPersistence`. Version comes from `ENV['CONTENTFUL_PERSISTENCE_VERSION']` via `require 'dotenv/load'`. Deployment targets: iOS 12.0, macOS 10.13, watchOS 4.0, tvOS 12.0. Frozen at 0.18.2: kept for existing users, and new versions are not pushed to trunk. |
| Carthage | `Cartfile`, `Cartfile.private` | `Cartfile` declares `contentful.swift ~> 5.5.1`; `Cartfile.private` adds the `mariuskatcontentful/OHHTTPStubs` fork used only by tests. Both are also `.gitmodules` submodules under `Carthage/Checkouts/`. |
| Xcode | `ContentfulPersistence.xcodeproj` / `.xcworkspace` | Four shared schemes: `ContentfulPersistence_iOS`, `_macOS`, `_tvOS`, `_watchOS`. The test bundles live here, not in SPM. |

Version is single-sourced: `Scripts/set-version.sh <version>` writes the same
value into `Config.xcconfig` (read by the Xcode targets) and `.env` (read by the
podspec and the release/docs scripts). `.env` is tracked and holds only that one
variable. `Scripts/release.sh validate` fails if the two disagree.

## CI

`.circleci/config.yml` runs four jobs in parallel on `macos` / `xcode: 27.0.0`,
each of them: select the Ruby from `.ruby-version`, `bundle install`, install
Carthage, `carthage bootstrap --use-xcframeworks` (the versions pinned in
`Cartfile.resolved`), then one fastlane lane — `test_ios`, `test_macos`, `test_tvos`,
or `build`. The three test lanes are `scan` invocations against the matching
scheme; `build` is `swift build`. The `_watchOS` scheme is not exercised by CI.

`.github/workflows/codeql.yml` runs CodeQL with `languages: actions` — it scans
the workflow files themselves, not the Swift source, and only triggers on
changes under `.github/workflows/**`.

`old-travis-integration.yml` and `Scripts/travis-build-test.sh` are leftovers
from the Travis era and are not wired to anything. The Travis and Coveralls
badges in `README.md` are likewise stale.

## Release

Releases run in CircleCI when a maintainer triggers a pipeline on `master` with
`run-release = true`: tests, `Scripts/release.sh validate`, build and zip
`ContentfulPersistence.xcframework` (with library evolution enabled for the
release build), then tag, create the GitHub release with the zip attached, and
regenerate the Jazzy docs onto `gh-pages`. `make release` runs the same script
locally. Nothing is pushed to CocoaPods trunk any more. `CHANGELOG.md` is
hand-written. See `RELEASING.md`.
