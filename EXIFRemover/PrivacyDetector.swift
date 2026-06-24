import Foundation
import CoreGraphics
import Vision

protocol PrivacyDetector {
    func detect(in cgImage: CGImage) async throws -> [PrivacyRegion]
}

class VisionDetector: PrivacyDetector {
    func detect(in cgImage: CGImage) async throws -> [PrivacyRegion] {
        // 异步跑 Vision，防卡顿
        return try await Task.detached(priority: .userInitiated) {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let faceRequest = VNDetectFaceRectanglesRequest()
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            let barcodeRequest = VNDetectBarcodesRequest()
            
            try requestHandler.perform([faceRequest, textRequest, barcodeRequest])
            
            var allRegions: [PrivacyRegion] = []
            
            if let faceResults = faceRequest.results {
                let faces = faceResults.map { PrivacyRegion(boundingBox: $0.boundingBox, type: .face) }
                allRegions.append(contentsOf: faces)
            }
            
            if let textResults = textRequest.results {
                for observation in textResults {
                    if let candidate = observation.topCandidates(1).first, candidate.confidence > 0.3 {
                        allRegions.append(PrivacyRegion(boundingBox: observation.boundingBox, type: .text))
                    }
                }
            }
            
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
                    // 合并重叠框
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
