import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

struct OutputConfiguration: Equatable {
    var suffix: String
    var rule: OutputConflictRule

    static let `default` = OutputConfiguration(suffix: "_clean", rule: .appendIndex)

    var sanitizedSuffix: String {
        suffix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func normalized() -> OutputConfiguration {
        OutputConfiguration(suffix: sanitizedSuffix, rule: rule)
    }
}

enum OutputConflictRule: String, CaseIterable, Identifiable {
    case appendIndex
    case overwrite
    case skip

    var id: String { rawValue }
}

enum ImageStripper {
    static func isSupportedImage(url: URL) -> Bool {
        let ext = url.pathExtension
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .image)
    }

    static func stripMetadata(
        inputURL: URL,
        outputFolder: URL,
        configuration: OutputConfiguration = .default
    ) throws -> URL {
        let fileManager = FileManager.default
        let ext = inputURL.pathExtension.isEmpty ? "jpg" : inputURL.pathExtension
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let suffix = configuration.sanitizedSuffix

        func makeCandidateName(index: Int?) -> String {
            var name = baseName
            if !suffix.isEmpty {
                name += suffix
            }
            if let index {
                name += "_\(index)"
            }
            return name
        }

        func candidateURL(index: Int?) -> URL {
            outputFolder.appendingPathComponent(makeCandidateName(index: index)).appendingPathExtension(ext)
        }

        let outputURL: URL

        switch configuration.rule {
        case .appendIndex:
            var index: Int? = nil
            var candidate = candidateURL(index: index)
            var counter = 1
            while fileManager.fileExists(atPath: candidate.path) {
                index = counter
                candidate = candidateURL(index: index)
                counter += 1
            }
            outputURL = candidate
        case .overwrite:
            let candidate = candidateURL(index: nil)
            if fileManager.fileExists(atPath: candidate.path) {
                try? fileManager.removeItem(at: candidate)
            }
            outputURL = candidate
        case .skip:
            let candidate = candidateURL(index: nil)
            guard !fileManager.fileExists(atPath: candidate.path) else {
                throw StripError.skippedByRule
            }
            outputURL = candidate
        }

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
        case skippedByRule

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return NSLocalizedString("error.invalidImage", comment: "")
            case .cannotCreateDestination:
                return NSLocalizedString("error.cannotCreateDestination", comment: "")
            case .cannotWrite:
                return NSLocalizedString("error.cannotWrite", comment: "")
            case .skippedByRule:
                return NSLocalizedString("error.skippedByRule", comment: "")
            }
        }
    }
}
