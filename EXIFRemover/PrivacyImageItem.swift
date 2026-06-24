import Foundation
import AppKit

struct PrivacyImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let cgImage: CGImage
    let nsImage: NSImage
    var detectedRegions: [PrivacyRegion] = []
    var selectedRegionIDs: Set<UUID> = []
    var isDetecting: Bool = false
    var detectionError: String? = nil
    var exportProgress: Double = 0.0 // optional for UI

    static func == (lhs: PrivacyImageItem, rhs: PrivacyImageItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.detectedRegions == rhs.detectedRegions &&
        lhs.selectedRegionIDs == rhs.selectedRegionIDs &&
        lhs.isDetecting == rhs.isDetecting
    }
}
