require 'xcodeproj'

project_path = 'EXIF Remover.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Update known regions
['ru', 'ja', 'zh-Hant'].each do |lang|
  unless project.root_object.known_regions.include?(lang)
    project.root_object.known_regions << lang
  end
end

# Find variant group
variant_group = project.root_object.main_group.recursive_children.find { |c| c.isa == 'PBXVariantGroup' && c.name == 'Localizable.strings' }

if variant_group
  ['ru', 'ja', 'zh-Hant'].each do |lang|
    existing = variant_group.children.find { |c| c.name == lang }
    unless existing
      file_ref = variant_group.new_reference("#{lang}.lproj/Localizable.strings")
      file_ref.name = lang
    end
  end
else
  puts "Variant group Localizable.strings not found"
end

project.save
puts "Successfully added languages to Xcode project."
