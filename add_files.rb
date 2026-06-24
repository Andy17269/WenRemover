require 'xcodeproj'

project_path = 'EXIF Remover.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找分组
group = project.main_group.find_subpath('EXIFRemover', false)
target = project.targets.first

# 待加文件
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
  
  # 去重
  existing_ref = group.files.find { |f| f.path == file_name }
  if existing_ref
    target.source_build_phase.remove_file_reference(existing_ref)
    existing_ref.remove_from_project
  end

  # 加引用
  file_ref = group.new_file(file_name)
  
  # 加到 build
  target.source_build_phase.add_file_reference(file_ref, true)
end

project.save
puts "Successfully added files to Xcode project."
