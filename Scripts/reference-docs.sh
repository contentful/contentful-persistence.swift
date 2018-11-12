#!/bin/sh

source .env

echo "Generating Jazzy Reference Documentation for version $CONTENTFUL_PERSISTENCE_VERSION of the persistence library"

bundle exec jazzy \
  --clean \
  --author Contentful \
  --author_url https://www.contentful.com \
  --github_url https://github.com/contentful/contentful-persistence.swift \
  --github-file-prefix https://github.com/contentful/contentful-persistence.swift/tree/$CONTENTFUL_PERSISTENCE_VERSION \
  --xcodebuild-arguments -workspace,ContentfulPersistence.xcworkspace,-scheme,ContentfulPersistence_iOS \
  --module-version $CONTENTFUL_PERSISTENCE_VERSION \
  --module ContentfulPersistence \
  --theme apple

