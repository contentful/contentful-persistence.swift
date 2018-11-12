#!/bin/sh 

source .env

echo "Making release for version $CONTENTFUL_PERSISTENCE_VERSION of the persistence library"

git tag $CONTENTFUL_PERSISTENCE_VERSION
git push --tags
bundle exec pod trunk push ContentfulPersistenceSwift.podspec
make carthage
git checkout gh-pages
git rebase master
./Scripts/reference-docs.sh
git add .
git commit --amend --no-edit
git push -f

echo "ContentfulPersistence v$CONTENTFUL_PERSISTENCE_VERSION is officially released! Attach the binary found at ContentfulPersistence.framework.zip to the release on Github"

