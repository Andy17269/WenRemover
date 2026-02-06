import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

enum ImageStripper {
    static func isSupportedImage(url: URL) -> Bool {
        let ext = url.pathExtension
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .image)
    }

    static func stripMetadata(inputURL: URL, outputFolder: URL) throws -> URL {
        let fileManager = FileManager.default
        let ext = inputURL.pathExtension.isEmpty ? "jpg" : inputURL.pathExtension
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let outputName = "\(baseName)_clean.\(ext)"
        let outputURL = outputFolder.appendingPathComponent(outputName)

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw StripError.invalidImage
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw StripError.invalidImage
        }

        let destinationType = UTType(filenameExtension: ext)?.identifier as CFString? ?? UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, destinationType, 1, nil) else {
            throw StripError.cannotCreateDestination
        }

        var options: [CFString: Any] = [:]
        if destinationType == UTType.jpeg.identifier as CFString {
            options[kCGImageDestinationLossyCompressionQuality] = 1.0
        }

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            if fileManager.fileExists(atPath: outputURL.path) {
                try? fileManager.removeItem(at: outputURL)
            }
            throw StripError.cannotWrite
        }

        return outputURL
    }

    enum StripError: LocalizedError {
        case invalidImage
        case cannotCreateDestination
        case cannotWrite

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "无法读取图片。"
            case .cannotCreateDestination:
                return "无法创建输出文件。"
            case .cannotWrite:
                return "写入失败。"
            }
        }
    }
}
