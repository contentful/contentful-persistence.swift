# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) starting from 1.x releases.

### Merged, but not yet released
> ~~All recent changes are published~~
> #### Fixed
> - Project configuration so that contentful-persistence.swift may be built from source without warnings. Implications:
>   - Dependencies are still managed via Carthage but using the `--use-submodules` flag. Thus, dependencies are all tracked as submodules and the source (i.e. Carthage/Checkouts) is now tracked in git.
>   - Now travis doesn't install carthage or use it at all to build the project and ContentfulPersistence.xcodeproj framework search paths are cleared.
---

## Table of contents

#### 0.x Releases

- `0.6.x` Releases - [0.6.0](#060) | [0.6.1](#061) | [0.6.2](#062)
- `0.5.x` Releases - [0.5.0](#050)
- `0.4.x` Releases - [0.4.0](#040)

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

