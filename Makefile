__SIM_ID=`xcrun simctl list|egrep -m 1 '$(SIM_NAME) \([^(]*\) \([^(]*\)$$'|sed -e 's/.* (\(.*\)) (.*)/\1/'`
SIM_NAME=iPhone 6s
SIM_ID=$(shell echo $(__SIM_ID))

ifeq ($(strip $(SIM_ID)),)
$(error Could not find $(SIM_NAME) simulator)
endif

PROJECT=ContentfulPersistence.xcodeproj

.PHONY: test setup lint coverage carthage clean open

open:
	open $(PROJECT)

clean:
	rm -rf $(HOME)/Library/Developer/Xcode/DerivedData/*

test: clean
	set -x -o pipefail && xcodebuild test -project $(PROJECT) \
		-scheme ContentfulPersistence_iOS -destination 'platform=iOS Simulator,name=iPhone 6s,OS=10.3' | bundle exec xcpretty -c

setup_env:
	./Scripts/setup-env.sh

setup:
	bundle install
	bundle exec pod install --no-repo-update

lint:
	swiftlint
	bundle exec pod lib lint ContentfulPersistenceSwift.podspec --verbose

coverage:
	bundle exec slather coverage -s $(PROJECT)

carthage:
	carthage build --no-skip-current --platform all
	carthage archive ContentfulPersistence

