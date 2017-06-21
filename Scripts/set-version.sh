#!/bin/bash


echo "CONTENTFUL_PERSISTENCE_VERSION=$1" > Config.xcconfig
echo "CONTENTFUL_PERSISTENCE_VERSION=$1" > .env
echo "export CONTENTFUL_PERSISTENCE_VERSION=$1" > .envrc
direnv allow

