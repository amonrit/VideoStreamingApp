#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

project_path = 'steam.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main app target
app_target = project.targets.find { |t| t.name == 'steam' }
unless app_target
  puts "❌ Could not find 'steam' target"
  exit 1
end

puts "📱 Found app target: #{app_target.name}"

# Create test target
test_target = project.new_target(:unit_test_bundle, 'steamTests', :ios)
puts "✅ Created test target: steamTests"

# Set up test target configurations
test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'steamTests'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/steam.app/steam'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['INFOPLIST_FILE'] = ''
  config.build_settings['CODE_SIGN_IDENTITY'] = ''
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = app_target.build_settings('Debug')['IPHONEOS_DEPLOYMENT_TARGET'] || '15.0'
  config.build_settings['SWIFT_VERSION'] = app_target.build_settings('Debug')['SWIFT_VERSION'] || '5.9'
end

# Add app target as dependency
test_target.add_dependency(app_target)
puts "✅ Added app target as dependency"

# Find all test files
test_dir = 'steamTests'
test_files = Dir.glob("#{test_dir}/**/*.swift").sort

puts "\n📂 Found #{test_files.count} test files"

# Add test files to target
test_files.each do |file|
  file_ref = project.files.find { |f| f.real_path.to_s == File.expand_path(file) }
  
  unless file_ref
    file_ref = project.new_file(file)
  end
  
  test_target.add_file_references([file_ref], '-fno-specific-heapcheck')
  puts "  ✅ #{File.basename(file)}"
end

# Create new scheme for tests
scheme = Xcodeproj::XCScheme.new(test_target, false)
scheme.test_action.build_configuration = 'Debug'
scheme.test_action.add_test_identifiers(test_target)
scheme.save_as(project_path, 'steamTests', false)
puts "✅ Created scheme: steamTests"

# Save project
project.save
puts "\n✅ Project saved successfully!"
puts "\n🎉 Test target 'steamTests' created and configured!"
puts "\n📊 Test Target Details:"
puts "  • Target: steamTests"
puts "  • Type: Unit Test Bundle"
puts "  • Test Files: #{test_files.count}"
puts "  • Scheme: steamTests"
puts "\n🚀 Next steps:"
puts "  1. Open Xcode: xed steam.xcodeproj"
puts "  2. Select 'steamTests' scheme in top-left"
puts "  3. Press Cmd+U to run all tests"
puts "  4. Or run: xcodebuild -scheme steamTests test"

