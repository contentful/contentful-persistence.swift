# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) starting from 1.x releases.

### Merged, but not yet released
> #### Changed
> **BREAKING:** `ContentfulSynchronizer` is now called `SynchronizationManager`
> **BREAKING:** Rather than initializing `SynchronizationManager` with a `Contentful.Client` instance, the `Contentful.Client` is now initialized with a `SynchronizationManager` instance as the `persistenceIntegration` parameter in the `Client` initializer.
> **BREAKING:** The manner in which content type identifiers map Contentful responses to `NSManagedObject` model classes is now changed: `SynchronizationManager` is initialized with a `PersistenceModel` which is constructed by passing in your `NSManagedObject` subclasses that conform to either `SyncSpacePersistable` `AssetPersistable` or `EntryPersistable`.

---

## Table of contents

#### 0.x Releases
- `0.4.x` Releases - [0.4.0](#040)

---

## [`0.4.0`](https://github.com/contentful/contentful-persistence.swift/releases/tag/0.4.0)
Released on 2017-06-20

---

