import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PrivacyImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let cgImage: CGImage
    let platformImage: PlatformImage
    var detectedRegions: [PrivacyRegion] = []
    var selectedRegionIDs: Set<UUID> = []
    var isDetecting: Bool = false
    var detectionError: String? = nil
    var exportProgress: Double = 0.0 // UI用

    static func == (lhs: PrivacyImageItem, rhs: PrivacyImageItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.detectedRegions == rhs.detectedRegions &&
        lhs.selectedRegionIDs == rhs.selectedRegionIDs &&
        lhs.isDetecting == rhs.isDetecting
    }
}
