import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers
import SwiftUI

struct PrivacyImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let cgImage: CGImage
    let nsImage: NSImage
    var detectedRegions: [PrivacyRegion] = []
    var selectedRegionIDs: Set<UUID> = []
    var isDetecting: Bool = false
    var detectionError: String? = nil

    static func == (lhs: PrivacyImageItem, rhs: PrivacyImageItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.detectedRegions == rhs.detectedRegions &&
        lhs.selectedRegionIDs == rhs.selectedRegionIDs &&
        lhs.isDetecting == rhs.isDetecting
    }
}

enum PrivacyEditorState: Equatable {
    case idle
    case review
    case rendering
    case exported
    case error(String)
}

@MainActor
class PrivacyEditorViewModel: ObservableObject {
    @Published var state: PrivacyEditorState = .idle
    @Published var items: [PrivacyImageItem] = []
    @Published var currentIndex: Int = 0
    
    @Published var blurIntensity: BlurIntensity = .medium
    @Published var outputFolder: URL?
    
    @Published var statusMessage: String?
    
    private let detector: PrivacyDetector = VisionDetector()
    
    private var languagePreference: String {
        UserDefaults.standard.string(forKey: "languagePreference") ?? "system"
    }

    private func localizedString(_ key: String) -> String {
        if languagePreference == "system" {
            return NSLocalizedString(key, comment: "")
        }
        if let path = Bundle.main.path(forResource: languagePreference, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return NSLocalizedString(key, comment: "")
    }
    
    func loadImages(from urls: [URL]) {
        for url in urls {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
                  let rawCGImage = CGImageSourceCreateImageAtIndex(source, 0, options) else {
                continue
            }
            
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
            let orientationValue = properties?[kCGImagePropertyOrientation as String] as? Int32 ?? 1
            
            let ciImage = CIImage(cgImage: rawCGImage).oriented(forExifOrientation: orientationValue)
            let context = CIContext(options: [.cacheIntermediates: false])
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                continue
            }
            
            let nsImage = NSImage(cgImage: cgImage, size: NSZeroSize)
            let item = PrivacyImageItem(url: url, cgImage: cgImage, nsImage: nsImage)
            self.items.append(item)
        }
        
        if !self.items.isEmpty {
            self.state = .review
            self.statusMessage = localizedString("privacy.status.loaded")
            self.detectPrivacy()
        }
    }
    
    func clearImages() {
        self.items = []
        self.currentIndex = 0
        self.state = .idle
        self.statusMessage = nil
    }
    
    func detectPrivacy() {
        Task {
            // Process sequentially
            for i in 0..<items.count {
                // Must fetch current item in case items array changes
                guard i < items.count else { break }
                let item = items[i]
                guard !item.isDetecting, item.detectedRegions.isEmpty, item.detectionError == nil else { continue }
                
                await MainActor.run { items[i].isDetecting = true }
                
                let cgImage = item.cgImage
                let maxDimension: CGFloat = 1080
                let width = CGFloat(cgImage.width)
                let height = CGFloat(cgImage.height)
                var detectImage = cgImage
                
                if width > maxDimension || height > maxDimension {
                    let scale = maxDimension / max(width, height)
                    let newWidth = Int(width * scale)
                    let newHeight = Int(height * scale)
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    if let context = CGContext(data: nil, width: newWidth, height: newHeight, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                        context.interpolationQuality = .high
                        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                        if let resized = context.makeImage() {
                            detectImage = resized
                        }
                    }
                }
                
                do {
                    let regions = try await detector.detect(in: detectImage)
                    await MainActor.run {
                        // Re-check index since items might have been removed via swiping
                        if let actualIndex = items.firstIndex(where: { $0.id == item.id }) {
                            items[actualIndex].detectedRegions = regions
                            items[actualIndex].selectedRegionIDs = Set(regions.map { $0.id })
                            items[actualIndex].isDetecting = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        if let actualIndex = items.firstIndex(where: { $0.id == item.id }) {
                            items[actualIndex].detectionError = error.localizedDescription
                            items[actualIndex].isDetecting = false
                        }
                    }
                }
            }
            
            await MainActor.run {
                if !self.items.isEmpty {
                    self.statusMessage = String.localizedStringWithFormat(self.localizedString("privacy.status.items %lld"), self.items.count)
                }
            }
        }
    }
    
    func toggleRegionSelection(itemID: UUID, regionID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        
        if self.items[index].selectedRegionIDs.contains(regionID) {
            self.items[index].selectedRegionIDs.remove(regionID)
            
            if let regionIndex = self.items[index].detectedRegions.firstIndex(where: { $0.id == regionID }) {
                if self.items[index].detectedRegions[regionIndex].type == .manual {
                    self.items[index].detectedRegions.remove(at: regionIndex)
                }
            }
        } else {
            self.items[index].selectedRegionIDs.insert(regionID)
        }
    }

    func addManualRegion(itemID: UUID, boundingBox: CGRect) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        
        let newRegion = PrivacyRegion(boundingBox: boundingBox, type: .manual)
        self.items[index].detectedRegions.append(newRegion)
        self.items[index].selectedRegionIDs.insert(newRegion.id)
    }
    
    func popItem(id: UUID, keep: Bool) {
        withAnimation(.spring()) {
            if keep {
                if currentIndex < items.count - 1 {
                    currentIndex += 1
                }
            } else {
                items.removeAll { $0.id == id }
                if currentIndex >= items.count && items.count > 0 {
                    currentIndex = items.count - 1
                }
            }
            
            if items.isEmpty {
                state = .idle
                statusMessage = nil
                currentIndex = 0
            } else {
                statusMessage = String.localizedStringWithFormat(localizedString("privacy.status.items %lld"), items.count)
            }
        }
    }
    
    func exportAllImages(configuration: OutputConfiguration) {
        guard !items.isEmpty, let outputFolder = outputFolder else { return }
        
        state = .rendering
        statusMessage = localizedString("privacy.status.rendering")
        
        let intensity = self.blurIntensity
        let currentItems = self.items
        
        Task.detached(priority: .userInitiated) {
            do {
                for item in currentItems {
                    let cgImage = item.cgImage
                    let url = item.url
                    let regionsToRender = item.detectedRegions.filter { item.selectedRegionIDs.contains($0.id) }
                    let finalCGImage = try PrivacyRenderer.render(cgImage: cgImage, regions: regionsToRender, intensity: intensity)
                    
                    let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                    let baseName = url.deletingPathExtension().lastPathComponent
                    let suffix = configuration.sanitizedSuffix
                    
                    func candidateURL(index: Int?) -> URL {
                        var name = baseName
                        if !suffix.isEmpty { name += suffix }
                        if let index { name += "_\(index)" }
                        return outputFolder.appendingPathComponent(name).appendingPathExtension(ext)
                    }
                    
                    let fileManager = FileManager.default
                    var outputURL: URL
                    
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
                            continue // Skip this image
                        }
                        outputURL = candidate
                    }
                    
                    try PrivacyRenderer.export(cgImage: finalCGImage, to: outputURL)
                }
                
                await MainActor.run {
                    self.state = .exported
                    self.statusMessage = self.localizedString("privacy.status.exported")
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    func copySingleImageToClipboard(configuration: OutputConfiguration) {
        guard items.count == 1, let item = items.first else { return }
        
        state = .rendering
        statusMessage = localizedString("privacy.status.rendering")
        
        let intensity = self.blurIntensity
        let regionsToRender = item.detectedRegions.filter { item.selectedRegionIDs.contains($0.id) }
        
        Task.detached(priority: .userInitiated) {
            do {
                let finalCGImage = try PrivacyRenderer.render(cgImage: item.cgImage, regions: regionsToRender, intensity: intensity)
                
                let ext = item.url.pathExtension.isEmpty ? "jpg" : item.url.pathExtension
                let tempFolder = FileManager.default.temporaryDirectory
                let tempURL = tempFolder.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
                
                try PrivacyRenderer.export(cgImage: finalCGImage, to: tempURL)
                
                if let image = NSImage(contentsOf: tempURL) {
                    await MainActor.run {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.writeObjects([image])
                        if let urlRef = tempURL as? NSURL {
                            pb.writeObjects([urlRef])
                        }
                        self.state = .exported
                        self.statusMessage = self.localizedString("status.copiedToClipboard")
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
}
