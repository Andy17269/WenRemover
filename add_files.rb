require 'xcodeproj'

project_path = 'EXIF Remover.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find EXIFRemover group
group = project.main_group.find_subpath('EXIFRemover', false)
target = project.targets.first

# The files to add
files_to_add = [
  'ContentView.swift',
  'EXIFRemoverView.swift',
  'PrivacyRegion.swift',
  'PrivacyDetector.swift',
  'PrivacyRenderer.swift',
  'PrivacyEditorViewModel.swift',
  'PrivacyProtectorView.swift',
  'EXIFReader.swift',
  'EXIFInfoView.swift',
  'EXIFViewerView.swift'
]

files_to_add.each do |file_name|
  file_path = "EXIFRemover/#{file_name}"
  
  # Remove if it already exists to avoid duplicates
  existing_ref = group.files.find { |f| f.path == file_name }
  if existing_ref
    target.source_build_phase.remove_file_reference(existing_ref)
    existing_ref.remove_from_project
  end

  # Add file reference
  file_ref = group.new_file(file_name)
  
  # Add to build phase
  target.source_build_phase.add_file_reference(file_ref, true)
end

project.save
puts "Successfully added files to Xcode project."
