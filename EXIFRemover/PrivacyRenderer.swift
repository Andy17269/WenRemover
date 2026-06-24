import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

enum BlurIntensity: String, CaseIterable, Identifiable {
    case light = "Light"
    case medium = "Medium"
    case heavy = "Heavy"
    
    var id: String { rawValue }
    
    var scale: Float {
        switch self {
        case .light: return 10
        case .medium: return 25
        case .heavy: return 50
        }
    }
}

class PrivacyRenderer {
    static let context = CIContext(options: [.cacheIntermediates: false])
    
    static func render(cgImage: CGImage, regions: [PrivacyRegion], intensity: BlurIntensity) throws -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)
        let imageSize = ciImage.extent.size
        
        // Base image
        var finalImage = ciImage
        
        for region in regions {
            // Convert normalized coordinates (origin bottom-left) to absolute coordinates
            let rect = CGRect(
                x: region.boundingBox.origin.x * imageSize.width,
                y: region.boundingBox.origin.y * imageSize.height,
                width: region.boundingBox.width * imageSize.width,
                height: region.boundingBox.height * imageSize.height
            )
            
            // Inflate rect slightly to ensure full coverage
            let expandedRect = rect.insetBy(dx: -5, dy: -5)
            
            // Create a mask for this region
            // Since CoreImage origin is bottom-left, rect matches CI coordinates.
            let maskImage = CIFilter(name: "CIConstantColorGenerator")!
            maskImage.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: kCIInputColorKey)
            let mask = maskImage.outputImage!.cropped(to: expandedRect)
            
            // Pixellate filter
            let pixellate = CIFilter.pixellate()
            pixellate.inputImage = finalImage
            pixellate.scale = intensity.scale
            
            guard let pixellated = pixellate.outputImage else { continue }
            
            // Blend with mask
            let blend = CIFilter.blendWithMask()
            blend.inputImage = pixellated
            blend.backgroundImage = finalImage
            blend.maskImage = mask
            
            if let output = blend.outputImage {
                finalImage = output
            }
        }
        
        guard let outputCGImage = context.createCGImage(finalImage, from: finalImage.extent) else {
            throw RenderError.cannotRender
        }
        
        return outputCGImage
    }
    
    static func export(cgImage: CGImage, to outputURL: URL) throws {
        let destinationType = UTType(filenameExtension: outputURL.pathExtension)?.identifier as CFString? ?? UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, destinationType, 1, nil) else {
            throw RenderError.cannotCreateDestination
        }
        
        // This naturally drops EXIF metadata as we are not copying properties from the original image source
        var options: [CFString: Any] = [:]
        if destinationType == UTType.jpeg.identifier as CFString {
            options[kCGImageDestinationLossyCompressionQuality] = 1.0
        }
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw RenderError.cannotWrite
        }
    }
    
    enum RenderError: LocalizedError {
        case cannotRender
        case cannotCreateDestination
        case cannotWrite
        
        var errorDescription: String? {
            switch self {
            case .cannotRender: return "Failed to render image filters."
            case .cannotCreateDestination: return "Cannot create output destination."
            case .cannotWrite: return "Failed to write image to disk."
            }
        }
    }
}
