use_frameworks!

target 'ContentfulPersistence' do

podspec :path => 'ContentfulPersistenceSwift.podspec'
#pod 'Contentful', :path => '../../Projects/contentful.swift'

end

target 'ContentfulPersistenceTests' do

pod 'CatchingFire'
pod 'Nimble', '~> 4.1.0'
pod 'Quick', '~> 0.9.3'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '2.3'
    end
  end
end
