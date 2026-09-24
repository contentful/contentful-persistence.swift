#!/usr/bin/ruby

require 'dotenv/load'

# CocoaPods trunk becomes read-only on 2026-12-02 and this library is frozen there at 0.18.2.
# This podspec is kept for existing users, and new versions are not pushed (see RELEASING.md).

Pod::Spec.new do |spec|
  spec.name             = "ContentfulPersistenceSwift"
  spec.version          = ENV['CONTENTFUL_PERSISTENCE_VERSION']
  spec.summary          = "Simplified persistence for the Contentful Swift SDK."
  spec.homepage         = "https://github.com/contentful/contentful-persistence.swift/"
  spec.social_media_url = 'https://twitter.com/contentful'

  spec.license = {
    :type => 'MIT',
    :file => 'LICENSE'
  }

  spec.authors      = { "JP Wright" => "jp@contentful.com", "Boris Bügling" => "boris@buegling.com" }
  spec.source       = { :git => "https://github.com/contentful/contentful-persistence.swift.git",
                        :tag => spec.version.to_s }
  spec.requires_arc = true
  spec.swift_version             = '5.0'

  spec.source_files              = 'Sources/**/*.swift'
  spec.module_name               = 'ContentfulPersistence'
  spec.frameworks                = 'CoreData'

  spec.ios.deployment_target     = '12.0'
  spec.osx.deployment_target     = '10.13'
  spec.watchos.deployment_target = '4.0'
  spec.tvos.deployment_target    = '12.0'

  spec.dependency 'Contentful', '~> 5.5.9'
end

