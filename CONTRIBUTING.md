# Contributing

Thanks for helping improve `contentful-persistence.swift`. This document covers
setup, the test suites, and what a reviewable change looks like. For how the
library is put together, read [ARCHITECTURE.md](ARCHITECTURE.md).

The default branch is **`master`**. Open pull requests against it.

## Prerequisites

- macOS with Xcode. CircleCI pins **Xcode 15.4** (`.circleci/config.yml`); use
  that or newer.
- [Homebrew](https://brew.sh) — `Scripts/setup-env.sh` requires it and will exit
  with an error if it is missing.
- Ruby with Bundler. Development tooling (CocoaPods, xcpretty, slather, jazzy,
  dotenv, fastlane) comes from the `Gemfile`.
- Because the project depends on Carthage submodules, clone with submodules or
  run `make setup`, which does `git submodule sync` and
  `git submodule update --init --recursive` for you.

Familiarity with Apple's CoreData framework is genuinely required here — as the
README notes, a large share of issues reported against this library turn out to
be CoreData behaviour rather than Contentful behaviour.

## Setting up

```bash
make setup_env                      # brew-installs/upgrades carthage and swiftlint, then bundle install
make setup                          # bundle install + sync and init the git submodules
carthage bootstrap --platform all   # build the pinned dependencies
```

`make open` opens `ContentfulPersistence.xcworkspace`. Always work in the
**workspace**, not the bare `.xcodeproj` — the test targets resolve their
dependencies through it.

## Running the tests

From the command line:

```bash
make test    # xcodebuild test on the ContentfulPersistence_macOS scheme, piped through xcpretty
```

Note that `make test` depends on the `clean` target, which deletes
**everything** under `~/Library/Developer/Xcode/DerivedData/` — not just this
project's build products.

The suites also run directly from Xcode. Pick one of the four shared schemes:
`ContentfulPersistence_iOS`, `ContentfulPersistence_macOS`,
`ContentfulPersistence_tvOS`, `ContentfulPersistence_watchOS`.

To run what CI runs, use the fastlane lanes from `fastlane/Fastfile`:

```bash
bundle exec fastlane test_ios
bundle exec fastlane test_macos
bundle exec fastlane test_tvos
bundle exec fastlane build      # swift build — verifies the SPM package compiles
```

CI runs the first three plus `build`, in parallel, each after a fresh
`carthage update --use-xcframeworks`. The `_watchOS` scheme builds but is not
covered by CI, so verify it locally if you touch platform-conditional code.

Coverage is generated separately:

```bash
make coverage   # bundle exec slather coverage -s ContentfulPersistence.xcodeproj
```

`.slather.yml` reports against the `ContentfulPersistence_iOS` scheme.

### Test layout

Tests live in `Tests/ContentfulPersistenceTests/`. A few conventions worth
knowing before you add one:

- HTTP responses are stubbed, not fetched. Stubbing uses the
  `mariuskatcontentful/OHHTTPStubs` fork pinned in `Cartfile.private`; there is
  also a `Mocks/MockURLProtocol.swift`. **No test requires Contentful
  credentials**, and new tests should not introduce that requirement.
- JSON fixtures are grouped by suite: `ContentStubs/`, `ComplexTestStubs/`,
  `LocalizationTestStubs/`, `PreseedJSONFiles/`, `MultifilePreseedJSONFiles/`,
  `MultilocalePreseedJSONFiles/`.
- CoreData models used by tests are their own `.xcdatamodeld` bundles —
  `Test`, `ComplexTest`, `LocalizationTest`,
  `RichTextDocumentTransformableTest`. If your change needs a new entity shape,
  add it to the model that matches the suite rather than reshaping `Test`.
- `TestHelpers.managedObjectContext(forMOMInTestBundleNamed:)` gives you an
  in-memory store (no state leaks between test methods);
  `TestHelpers.sqliteBackedContext(forMOMInTestBundleNamed:)` gives you a
  file-backed one, which is what the preseeding tests need.
- `Mocks/MockPersistenceStore.swift` is the non-CoreData implementation of
  `PersistenceStore`; use it when the thing under test is the sync logic rather
  than CoreData itself.

## Linting

```bash
make lint    # swiftlint, then bundle exec pod lib lint ContentfulPersistenceSwift.podspec --verbose
```

`.swiftlint.yml` excludes `Carthage`, `Packages`, `Tests`, `.build`, and
`build`, and disables a specific set of rules. Please do not add rules to
`disabled_rules` to get a new warning to go away — fix the code instead. The
parameterized limits are `line_length` warning at 150 (comments and URLs
ignored), `file_length` warning at 800, `function_body_length` 110,
`vertical_whitespace` max 2 empty lines.

`pod lib lint` matters as much as SwiftLint: the podspec is one of four build
descriptions and it is the one most easily broken.

## Making a change

1. Branch off `master`.
2. If you change the public API or the dependency on `contentful.swift`, update
   **all four** build descriptions together: `Package.swift`,
   `ContentfulPersistenceSwift.podspec`, `Cartfile`, and the Xcode project.
   Commit the refreshed `Package.resolved` / `Cartfile.resolved` too.
3. Add or update tests. Every existing behaviour in
   `Sources/ContentfulPersistence/Relationships/` and `Seeding/` has a
   corresponding suite; match that.
4. Add an entry to `CHANGELOG.md` under **"Merged, but not yet released"**. The
   changelog is maintained by hand and has a table of contents at the top —
   update both when you add a release heading.
5. Run `make lint` and at least `make test` before opening the PR.
6. Do not edit anything under `docs/` except `docs/ADRs/` — the rest is
   generated Jazzy output, regenerated at release time by
   `Scripts/reference-docs.sh`.
7. Do not hand-edit `Config.xcconfig`, `.env`, or `.envrc`. Those three are
   written together by `Scripts/set-version.sh` and must not drift apart.

### Commit messages

Recent history uses `feat:`, `fix:`, `chore:`, and `docs:` prefixes, with the
Jira key in brackets when there is one — for example
`chore: set up Renovate for dependency updates [MEC-3447]`. Keep the subject
line in the imperative.

### Architectural decisions

If your change makes or reverses a non-obvious decision — a dependency choice, a
storage format, a deliberate deviation from CoreData conventions — add a record
to `docs/ADRs/` and list it in `docs/ADRs/README.md`.

## Dependencies

`renovate.json` opens automated dependency PRs (see `44126dd`,
`chore: set up Renovate for dependency updates [MEC-3447]`). When a Renovate PR
bumps `contentful.swift`, check that the version reached all four build
descriptions before merging; Renovate does not necessarily update every one of
them.

## Releasing

Releases are cut by maintainers and are a **local, manual** process — there is
no automated publish in this repository:

```bash
./Scripts/set-version.sh <version>   # writes Config.xcconfig, .env, .envrc
make release                         # Scripts/release.sh
```

`Scripts/release.sh` tags the version, pushes tags, runs
`pod trunk push ContentfulPersistenceSwift.podspec --allow-warnings`, builds
xcframeworks via `make carthage`, then rebuilds the API docs on the `gh-pages`
branch and force-pushes it. It ends by reminding you to attach
`ContentfulPersistence.framework.zip` to the GitHub release manually.

`pod trunk push` needs a CocoaPods trunk session with push rights to
`ContentfulPersistenceSwift`. If you do not have one, do not start the release —
the script tags and pushes before it ever reaches the publish step.

## Reporting bugs

Open a GitHub issue and include: the library version, the Contentful SDK
version, how you install (SPM / CocoaPods / Carthage), the platform and
deployment target, your `LocalizationScheme`, and the relevant part of your
`.xcdatamodeld` (entity, attribute optionality, relationship arrangement). Most
reproductions hinge on model configuration, so a screenshot of the Data Model
Inspector is more useful than prose.

The repository is owned by `@contentful/team-developer-experience`
(`.github/CODEOWNERS`).
