#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('IKEMEN Lab.xcodeproj')

# Find the main target
main_target = project.targets.find { |t| t.name == 'IKEMEN Lab' }
test_target = project.targets.find { |t| t.name == 'IKEMEN Lab Tests' }

# Find the Core and Models groups
core_group = project.main_group.find_subpath('IKEMEN Lab/Core', false)
models_group = project.main_group.find_subpath('IKEMEN Lab/Models', false)

# Add FilterRule.swift to Models
existing = models_group.children.find { |f| f.respond_to?(:path) && f.path == 'FilterRule.swift' }
unless existing
  file_ref = models_group.new_file('FilterRule.swift')
  main_target.source_build_phase.add_file_reference(file_ref)
  puts "Added FilterRule.swift"
else
  puts "FilterRule.swift already exists"
end

# Add SmartCollectionEvaluator.swift to Core
existing = core_group.children.find { |f| f.respond_to?(:path) && f.path == 'SmartCollectionEvaluator.swift' }
unless existing
  file_ref = core_group.new_file('SmartCollectionEvaluator.swift')
  main_target.source_build_phase.add_file_reference(file_ref)
  puts "Added SmartCollectionEvaluator.swift"
else
  puts "SmartCollectionEvaluator.swift already exists"
end

# For the test target, we need to find the correct group
# The Tests folder might be set up differently
project.targets.each do |target|
  next unless target.name == 'IKEMEN Lab Tests'
  
  # Find the tests group in the project
  tests_group = project.main_group.children.find { |g| g.respond_to?(:path) && g.path == 'IKEMEN Lab Tests' }
  if tests_group.nil?
    tests_group = project.main_group.children.find { |g| g.respond_to?(:name) && g.name == 'IKEMEN Lab Tests' }
  end
  
  if tests_group
    existing = tests_group.children.find { |f| f.respond_to?(:path) && f.path == 'SmartCollectionEvaluatorTests.swift' }
    unless existing
      file_ref = tests_group.new_file('SmartCollectionEvaluatorTests.swift')
      target.source_build_phase.add_file_reference(file_ref)
      puts "Added SmartCollectionEvaluatorTests.swift"
    else
      puts "SmartCollectionEvaluatorTests.swift already exists"
    end
  else
    puts "Could not find IKEMEN Lab Tests group"
  end
end

project.save
puts "Project saved!"
