#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('IKEMEN Lab.xcodeproj')

# Find the main target
main_target = project.targets.find { |t| t.name == 'IKEMEN Lab' }

# Find UI group
ui_group = project.main_group.find_subpath('IKEMEN Lab/UI', false)

def add_file(group, filename, target)
  existing = group.children.find { |f| f.respond_to?(:path) && f.path == filename }
  unless existing
    file_ref = group.new_file(filename)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{filename} to #{group.path}"
  else
    puts "#{filename} already exists in #{group.path}"
  end
end

# Dashboard extracted files
ui_files = [
  'DashboardTheme.swift',
  'DashboardDropZone.swift',
  'HoverableStatCard.swift',
  'HoverableToolButton.swift',
  'HoverableLaunchCard.swift',
  'RecentInstallRow.swift'
]
ui_files.each { |f| add_file(ui_group, f, main_target) }

project.save
puts "Project saved!"
