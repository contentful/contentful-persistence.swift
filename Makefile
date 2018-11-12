PROJECT=ContentfulPersistence.xcodeproj
WORKSPACE=ContentfulPersistence.xcworkspace

.PHONY: test setup lint coverage carthage clean open release

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
	carthage build ContentfulPersistence --no-skip-current --platform all
	carthage archive ContentfulPersistence

release:
	./Scripts/release.sh

