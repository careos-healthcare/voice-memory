#!/usr/bin/env ruby
# file_picker's Swift package always depends on DKImagePickerController.
# Documents do not need that gallery. CocoaPods is disabled with
# Pod::PICKER_MEDIA = false; this rewrites the generated Swift package the
# same way before Xcode resolves it.

module FilePickerMedia
  module_function

  def strip(ios_root)
    roots = [
      File.join(ios_root, 'Flutter', 'ephemeral'),
      File.expand_path('../build/ios', ios_root),
    ]
    roots.each do |root|
      next unless Dir.exist?(root)

      Dir.glob(File.join(root, '**', 'Package.swift')).each do |path|
        original = File.read(path)
        next unless original.include?('DKImagePickerController')

        updated = original.gsub(
          /^\s*\.package\(url: "https:\/\/github\.com\/zhangao0086\/DKImagePickerController".*\n/,
          '',
        )
        updated = updated.gsub(
          /^\s*\.product\(name: "DKImagePickerController", package: "DKImagePickerController"\),?\n/,
          '',
        )
        updated = updated.gsub(/^\s*\.define\("PICKER_MEDIA"\),?\n/, '')
        File.write(path, updated) if updated != original
      end
    end
  end
end

FilePickerMedia.strip(File.expand_path(__dir__)) if $PROGRAM_NAME == __FILE__
