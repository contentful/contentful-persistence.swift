#!/bin/sh 

source .env

echo "Making release for version $CONTENTFUL_PERSISTENCE_VERSION of the persistence library"

git tag $CONTENTFUL_PERSISTENCE_VERSION
git push --tags
bundle exec pod trunk push ContentfulPersistenceSwift.podspec --allow-warnings
make carthage
git stash --all
git checkout gh-pages
git rebase master
./Scripts/reference-docs.sh
git add .
git commit --amend --no-edit
git push -f
git checkout master
git stash pop

echo "ContentfulPersistence v$CONTENTFUL_PERSISTENCE_VERSION is officially released! Attach the binary found at ContentfulPersistence.framework.zip to the release on Github"

