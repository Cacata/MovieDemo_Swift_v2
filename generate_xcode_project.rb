#!/usr/bin/env ruby

require "xcodeproj"
require "fileutils"

project_path = File.join(__dir__, "MovieDemoSwift.xcodeproj")
FileUtils.rm_rf(project_path)
project = Xcodeproj::Project.new(project_path)

app_target = project.new_target(:application, "MovieDemoSwift", :ios, "17.0")
test_target = project.new_target(:unit_test_bundle, "MovieDemoSwiftTests", :ios, "17.0")
test_target.add_dependency(app_target)

configuration_group = project.main_group.new_group("Configuration", "Configuration")
base_configuration = configuration_group.new_file("Base.xcconfig")
configuration_group.new_file("Secrets.example.xcconfig")

app_group = project.main_group.new_group("MovieDemoSwift", "MovieDemoSwift")
%w[Core Data Presentation App].each do |folder_name|
  folder_group = app_group.new_group(folder_name, folder_name)
  Dir.glob(File.join(__dir__, "MovieDemoSwift", folder_name, "*.swift")).sort.each do |file_path|
    file_reference = folder_group.new_file(File.basename(file_path))
    app_target.add_file_references([file_reference])
  end
end

assets_reference = app_group.new_file("Assets.xcassets")
app_target.resources_build_phase.add_file_reference(assets_reference)

tests_group = project.main_group.new_group("MovieDemoSwiftTests", "MovieDemoSwiftTests")
Dir.glob(File.join(__dir__, "MovieDemoSwiftTests", "*.swift")).sort.each do |file_path|
  file_reference = tests_group.new_file(File.basename(file_path))
  test_target.add_file_references([file_reference])
end

sqlite_reference = project.frameworks_group.new_file("usr/lib/libsqlite3.tbd", :sdk_root)
app_target.frameworks_build_phase.add_file_reference(sqlite_reference)

dependencies_package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
dependencies_package.repositoryURL = "https://github.com/pointfreeco/swift-dependencies"
dependencies_package.requirement = { "kind" => "exactVersion", "version" => "1.16.0" }
project.root_object.package_references << dependencies_package

dependencies_product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
dependencies_product.package = dependencies_package
dependencies_product.product_name = "Dependencies"
[app_target, test_target].each do |target|
  target.package_product_dependencies << dependencies_product
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependencies_product
  target.frameworks_build_phase.files << build_file
end

app_target.build_configurations.each do |configuration|
  configuration.base_configuration_reference = base_configuration
  configuration.build_settings["PRODUCT_NAME"] = "MovieDemoSwift"
  configuration.build_settings["TARGETED_DEVICE_FAMILY"] = "1,2"
  configuration.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
end

test_target.build_configurations.each do |configuration|
  configuration.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.armando.moviedemo.swift.v2.tests"
  configuration.build_settings["SWIFT_VERSION"] = "6.0"
  configuration.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  configuration.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
  configuration.build_settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/MovieDemoSwift.app/MovieDemoSwift"
  configuration.build_settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
end

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.add_test_target(test_target)
scheme.set_launch_target(app_target)
scheme.save_as(project_path, "MovieDemoSwift", true)

puts "Generated #{project_path}"
