#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('IKEMEN Lab.xcodeproj')

# Find the main target
main_target = project.targets.find { |t| t.name == 'IKEMEN Lab' }
test_target = project.targets.find { |t| t.name == 'IKEMEN Lab Tests' }

# Find the Core, Models, and UI groups
core_group = project.main_group.find_subpath('IKEMEN Lab/Core', false)
models_group = project.main_group.find_subpath('IKEMEN Lab/Models', false)
ui_group = project.main_group.find_subpath('IKEMEN Lab/UI', false)

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

# Add UI files
ui_files = ['SmartCollectionSheet.swift', 'RuleRowView.swift', 'TagInputView.swift']
ui_files.each do |filename|
  existing = ui_group.children.find { |f| f.respond_to?(:path) && f.path == filename }
  unless existing
    file_ref = ui_group.new_file(filename)
    main_target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{filename}"
  else
    puts "#{filename} already exists"
  end
end

project.save
puts "Project saved!"
