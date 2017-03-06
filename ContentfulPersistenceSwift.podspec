#!/usr/bin/ruby

Pod::Spec.new do |s|
  s.name             = "ContentfulPersistenceSwift"
  s.version          = "0.3.1"
  s.summary          = "Simplified persistence for the Contentful Swift SDK."
  s.homepage         = "https://github.com/contentful/contentful-persistence.swift/"
  s.social_media_url = 'https://twitter.com/contentful'

  s.license = {
    :type => 'MIT',
    :file => 'LICENSE'
  }

  s.authors      = { "Boris Bügling" => "boris@buegling.com", "JP Wright" => "jp@contentful.com" }
  s.source       = { :git => "https://github.com/contentful/contentful-persistence.swift.git",
                     :tag => s.version.to_s }
  s.requires_arc = true

  s.source_files         = 'Sources/*.swift'
  s.module_name          = 'ContentfulPersistence'

  s.ios.deployment_target     = '8.0'
  s.osx.deployment_target     = '10.10'
  s.watchos.deployment_target = '2.0'
  s.tvos.deployment_target    = '9.0'

  s.dependency 'Contentful', '~> 0.3.1'
end
