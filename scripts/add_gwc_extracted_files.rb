#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('IKEMEN Lab.xcodeproj')

# Find the main target
main_target = project.targets.find { |t| t.name == 'IKEMEN Lab' }

# Find groups
core_group = project.main_group.find_subpath('IKEMEN Lab/Core', false)
ui_group = project.main_group.find_subpath('IKEMEN Lab/UI', false)
shared_group = project.main_group.find_subpath('IKEMEN Lab/Shared', false)

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

# Core files
core_files = ['IkemenConfigManager.swift', 'VRAMMonitor.swift', 'InstallCoordinator.swift', 'StageCreationController.swift']
core_files.each { |f| add_file(core_group, f, main_target) }

# UI files
ui_files = ['NavButton.swift', 'DropZoneView.swift', 'ClickBlockingView.swift', 'SettingsView.swift']
ui_files.each { |f| add_file(ui_group, f, main_target) }

# Shared files
shared_files = ['NSView+Extensions.swift']
shared_files.each { |f| add_file(shared_group, f, main_target) }

project.save
puts "Project saved!"
