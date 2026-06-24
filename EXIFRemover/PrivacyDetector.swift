import Foundation
import CoreGraphics
import Vision

protocol PrivacyDetector {
    func detect(in cgImage: CGImage) async throws -> [PrivacyRegion]
}

class VisionDetector: PrivacyDetector {
    func detect(in cgImage: CGImage) async throws -> [PrivacyRegion] {
        // Run vision requests in a detached task to avoid blocking the caller
        return try await Task.detached(priority: .userInitiated) {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let faceRequest = VNDetectFaceRectanglesRequest()
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            let barcodeRequest = VNDetectBarcodesRequest()
            
            try requestHandler.perform([faceRequest, textRequest, barcodeRequest])
            
            var allRegions: [PrivacyRegion] = []
            
            // Collect Faces
            if let faceResults = faceRequest.results {
                let faces = faceResults.map { PrivacyRegion(boundingBox: $0.boundingBox, type: .face) }
                allRegions.append(contentsOf: faces)
            }
            
            // Collect Texts
            if let textResults = textRequest.results {
                for observation in textResults {
                    if let candidate = observation.topCandidates(1).first, candidate.confidence > 0.3 {
                        allRegions.append(PrivacyRegion(boundingBox: observation.boundingBox, type: .text))
                    }
                }
            }
            
            // Collect Barcodes
            if let barcodeResults = barcodeRequest.results {
                let barcodes = barcodeResults.map { PrivacyRegion(boundingBox: $0.boundingBox, type: .barcode) }
                allRegions.append(contentsOf: barcodes)
            }
            
            return Self.merge(regions: allRegions)
        }.value
    }
    
    static func merge(regions: [PrivacyRegion]) -> [PrivacyRegion] {
        var merged: [PrivacyRegion] = []
        var remaining = regions
        
        while !remaining.isEmpty {
            var current = remaining.removeFirst()
            var didMerge = true
            
            while didMerge {
                didMerge = false
                var i = 0
                while i < remaining.count {
                    // Intersection over Union or just simple intersection
                    // simple intersection is safer to group close overlapping boxes
                    if current.boundingBox.intersects(remaining[i].boundingBox) || current.intersectionOverUnion(with: remaining[i]) > 0.05 {
                        current = current.merged(with: remaining[i])
                        remaining.remove(at: i)
                        didMerge = true
                    } else {
                        i += 1
                    }
                }
            }
            merged.append(current)
        }
        
        return merged
    }
}
