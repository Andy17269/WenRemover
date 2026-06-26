import Foundation
import SwiftUI
import CoreLocation

public struct EXIFFileItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public var originalEXIF: EXIFData
    public var currentEXIF: EXIFData
    
    public init(id: UUID = UUID(), url: URL, exif: EXIFData) {
        self.id = id
        self.url = url
        self.originalEXIF = exif
        self.currentEXIF = exif
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: EXIFFileItem, rhs: EXIFFileItem) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
public class EXIFEditorViewModel: ObservableObject {
    @Published public var files: [EXIFFileItem] = []
    @Published public var selectedFileIDs: Set<UUID> = []
    
    @Published public var isProcessing = false
    @Published public var processingProgress: Double = 0.0
    
    @Published public var searchText: String = ""
    
    public init() {}
    
    public var filteredFiles: [EXIFFileItem] {
        if searchText.isEmpty { return files }
        return files.filter { item in
            let makeMatch = item.currentEXIF.make?.localizedCaseInsensitiveContains(searchText) == true
            let modelMatch = item.currentEXIF.model?.localizedCaseInsensitiveContains(searchText) == true
            let nameMatch = item.url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
            return makeMatch || modelMatch || nameMatch
        }
    }
    
    public func addFiles(urls: [URL]) async {
        isProcessing = true
        var count = 0
        for url in urls {
            if let data = await EXIFManager.readEXIF(from: url) {
                let item = EXIFFileItem(url: url, exif: data)
                self.files.append(item)
            }
            count += 1
            self.processingProgress = Double(count) / Double(urls.count)
        }
        isProcessing = false
        self.processingProgress = 0
    }
    
    public func removeSelected() {
        files.removeAll { selectedFileIDs.contains($0.id) }
        selectedFileIDs.removeAll()
    }
    
    public func clearAll() {
        files.removeAll()
        selectedFileIDs.removeAll()
    }
    
    // Batch rename
    public func batchRename(format: String, outputFolder: URL) async throws {
        isProcessing = true
        let targets = files.filter { selectedFileIDs.contains($0.id) }
        var count = 0
        
        for i in 0..<targets.count {
            let item = targets[i]
            let newName = BatchProcessingEngine.generateNewFileName(for: item.url, with: item.currentEXIF, format: format)
            _ = try BatchProcessingEngine.processFile(url: item.url, newEXIF: item.currentEXIF, newName: newName, outputFolder: outputFolder)
            count += 1
            self.processingProgress = Double(count) / Double(targets.count)
        }
        
        isProcessing = false
        self.processingProgress = 0
    }
    
    public func batchTimeShift(timeInterval: TimeInterval) {
        for i in 0..<files.count {
            if selectedFileIDs.contains(files[i].id) {
                BatchProcessingEngine.shiftTime(in: &files[i].currentEXIF, by: timeInterval)
            }
        }
    }
    
    public func applyPreset(_ preset: EXIFData) {
        for i in 0..<files.count {
            if selectedFileIDs.contains(files[i].id) {
                BatchProcessingEngine.applyPreset(preset: preset, to: &files[i].currentEXIF)
            }
        }
    }
    
    public func updateLocation(coordinate: CLLocationCoordinate2D, for id: UUID) {
        if let index = files.firstIndex(where: { $0.id == id }) {
            files[index].currentEXIF.coordinate = coordinate
        }
    }
    
    public func batchExport(outputFolder: URL) async throws {
        isProcessing = true
        let targets = files.filter { selectedFileIDs.contains($0.id) }
        var count = 0
        
        for item in targets {
            _ = try BatchProcessingEngine.processFile(url: item.url, newEXIF: item.currentEXIF, newName: nil, outputFolder: outputFolder)
            count += 1
            self.processingProgress = Double(count) / Double(targets.count)
        }
        
        isProcessing = false
        self.processingProgress = 0
    }
}
