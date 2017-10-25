#!/bin/sh

echo "Generating Jazzy Reference Documentation"

bundle exec jazzy \
  --clean \
  --author Contentful \
  --author_url https://www.contentful.com \ --github_url https://github.com/contentful/contentful-persistence.swift \
  --github-file-prefix https://github.com/contentful/contentful-persistence.swift/tree/${CONTENTFUL_PERSISTENCE_VERSION} \
  --module-version ${CONTENTFUL_PERSISTENCE_VERSION} \
  --module ContentfulPersistence \
  --theme apple

