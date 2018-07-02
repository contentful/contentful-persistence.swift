# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) starting from 1.x releases.

### Merged, but not yet released
> All recent changes are published
---

## Table of contents

#### 0.x Releases
- `0.12.x` Releases - [0.12.0](#0120)
- `0.11.x` Releases - [0.11.0](#0110)
- `0.10.x` Releases - [0.10.0](#0100)
- `0.9.x` Releases - [0.9.0](#090) | [0.9.1](#091)
- `0.8.x` Releases - [0.8.0](#080)
- `0.7.x` Releases - [0.7.0](#070)
- `0.6.x` Releases - [0.6.0](#060) | [0.6.1](#061) | [0.6.2](#062)
- `0.5.x` Releases - [0.5.0](#050)
- `0.4.x` Releases - [0.4.0](#040)

---

## [`0.12.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.12.0)
Released on 2018-07-02

#### Changed
- If there are ever any (currently) unresolvable relationships returned on a page, they will now be cached to disk so that if the user quits the app, the relationship will still be resolved when the target resources are returned in subsequent sync operations. Thanks to [@marcin-bo](https://github.com/marcin-bo) for submitting the fix in [#60](https://github.com/contentful/contentful-persistence.swift/pull/60)

---

## [`0.11.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.11.0)
Released on 2018-04-18

#### Changed
- **BREAKING:** If you were using the methods to seed a CoreData database on first launch, you will need to re-run the command from [contentful-utilities.swift](https://github.com/contentful/contentful-utilties.swift) to generate the bundle files. This change coencides with the fact that environments are now locale specific.
- **BREAKING:** Upgrades project to Xcode 9.3 and Swift 4.1

---

## [`0.10.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.10.0)
Released on 2018-04-05

#### Added
- **BREAKING:** Ability to store _all_ asset metadata in `AssetPersistable` has been added. Conforming to the new protocol contstraints is a breaking change and you should make sure to resync all data to ensure this metedata is stored properly.
- You can now use the `fetchData(for:with:)` method from contentful.swift on `AssetPersistable` instances

#### Changed
- **BREAKING:** The library is now upgraded to Swift 4.1 and Xcode 9.3

#### FIXED
- Assets that contained media files that were not images failed to deserialize the metadata about the file properly, see [contentful.swift #182](https://github.com/contentful/contentful.swift/pull/182)

---

## [`0.9.1`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.9.1)
Released on 2018-02-07

#### Fixed
- Relationships were not resolving when seeding a database from bundled content if the source and destination resources were in different files. Fixed in [#48](https://github.com/contentful/contentful-persistence.swift/pull/48)

---

## [`0.9.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.9.0)
Released on 2017-01-09

#### Improved
- Improved test coverage to capture edge cases for various models.

#### Added
- `Contentful.Location` can now be stored as an 'Transformable' attribute on a CoreData entity in the Xcode data model editor and on your `NSManagedObject` subclasses.

---

## [`0.8.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.8.0)
Released on 2017-11-27

#### Changed
- Travis now deploys the [reference documentation](https://contentful.github.io/contentful-persistence.swift/) from the `gh-pages` branch when a new tag is pushed.
- Upgraded dependency on Contentful to [1.0.0-beta3](https://github.com/contentful/contentful.swift/releases/tag/1.0.0-beta3) and updated development dependencies.

#### Fixed
- Issue where seeding CoreData db from bundled JSON files only created entities for the spaces default locale in [#39](https://github.com/contentful/contentful-persistence.swift/pull/39)

---

## [`0.7.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.7.0)
Released on 2017-10-05

#### Changed
- **BREAKING:** Migrated to Swift 4; you must now use Xcode 9 in order to develop with the persistence library.

---

## [`0.6.2`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.6.2)
Released on 2017-09-20

#### Fixed
- Bug that caused `SynchronizationManager` to fail seeding a CoreData database from bundled content because of lack of localization context.

---

## [`0.6.1`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.6.1)
Released on 2017-09-08

#### Added
- Methods on `SynchronizationManager` to seed a CoreData database from bundled content.

#### Fixed
- Project configuration so that contentful-persistence.swift may be built from source without warnings. Implications:
  - Dependencies are still managed via Carthage but using the `--use-submodules` flag. Thus, dependencies are all tracked as submodules and the source (i.e. Carthage/Checkouts) is now tracked in git.
  - Now travis doesn't install carthage or use it at all to build the project and ContentfulPersistence.xcodeproj framework search paths are cleared.

---

## [`0.6.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.6.0)
Released on 2017-07-31

#### Added
- The ability to a `LocalizationScheme` on `SynchronizationManager` which determines for which locales data should be saved to your persistent store.

#### Changed
- **BREAKING:** `ContentPersistable` is now called `ContentSysPersistable`
- **BREAKING:** `mapping()` is now called `fieldMapping()` to clarify that only 'fields' from your Entries ContentModel must be mapped.
- **BREAKING:** `localeCode: String` is now a necessary property for `ContentSysPersistable` model classes.

#### Fixed
- Removed use of `try!` in the codebase Issue [#25](https://github.com/contentful/contentful.swift/issues/25). Fix by [@tapwork](https://github.com/tapwork) in [#26](https://github.com/contentful/contentful-persistence.swift/pull/26)

---

## [`0.5.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.5.0)
Released on 2017-07-18

#### Fixed
- Bug where "clearing" a field in an Entry did not nullify the corresponding persisted property.
- Bug where deleting a relationship in Contentful did not nullify the corresponding persisted relationship.
- Crash caused by explicitly defining mapping for relationships.

#### Changed
- **BREAKING:** Mapping must be explictly define for types conforming to `EntryPersistable`
---

## [`0.4.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.4.0)
Released on 2017-06-20

#### Changed
**BREAKING:** `ContentfulSynchronizer` is now called `SynchronizationManager`
**BREAKING:** Rather than initializing `SynchronizationManager` with a `Contentful.Client` instance, the `Contentful.Client` is now initialized with a `SynchronizationManager` instance as the `persistenceIntegration` parameter in the `Client` initializer.
**BREAKING:** The manner in which content type identifiers map Contentful responses to `NSManagedObject` model classes is now changed: `SynchronizationManager` is initialized with a `PersistenceModel` which is constructed by passing in your `NSManagedObject` subclasses that conform to either `SyncSpacePersistable` `AssetPersistable` or `EntryPersistable`.

---

