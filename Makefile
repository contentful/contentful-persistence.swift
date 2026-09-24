PROJECT=ContentfulPersistence.xcodeproj
WORKSPACE=ContentfulPersistence.xcworkspace

.PHONY: test setup lint coverage carthage clean open release release_dry_run trigger_release docs

open:
	open $(WORKSPACE)

clean:
	rm -rf $(HOME)/Library/Developer/Xcode/DerivedData/*

clean_simulators: kill_simulator
	xcrun simctl erase all

kill_simulator:
	killall "Simulator" || true

test: clean
	set -x -o pipefail && xcodebuild test -workspace $(WORKSPACE) \
		-scheme ContentfulPersistence_macOS -destination 'platform=macOS' | bundle exec xcpretty -c

setup_env:
	./Scripts/setup-env.sh

setup:
	bundle install
	git submodule sync
	git submodule update --init --recursive

lint:
	swiftlint
	bundle exec pod lib lint ContentfulPersistenceSwift.podspec --verbose

coverage:
	bundle exec slather coverage -s $(PROJECT)

carthage:
	./Scripts/release.sh xcframework

docs:
	./Scripts/reference-docs.sh

release:
	./Scripts/release.sh all

release_dry_run:
	DRY_RUN=1 ./Scripts/release.sh all

trigger_release:
	./Scripts/trigger-release.sh

