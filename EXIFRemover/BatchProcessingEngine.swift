import Foundation

public enum BatchProcessingError: Error {
    case unsupportedFormat
    case processFailed(String)
}

public class BatchProcessingEngine {
    
    // Batch Rename: e.g. "{Year}-{Make}-{Model}.jpg"
    public static func generateNewFileName(for url: URL, with data: EXIFData, format: String) -> String {
        var newName = format
        
        // Year/Month/Day from dateTimeOriginal
        if let dateTime = data.dateTimeOriginal, dateTime.count >= 10 {
            // "yyyy:MM:dd HH:mm:ss"
            let year = String(dateTime.prefix(4))
            let month = String(dateTime.dropFirst(5).prefix(2))
            let day = String(dateTime.dropFirst(8).prefix(2))
            
            newName = newName.replacingOccurrences(of: "{Year}", with: year)
            newName = newName.replacingOccurrences(of: "{Month}", with: month)
            newName = newName.replacingOccurrences(of: "{Day}", with: day)
        } else {
            newName = newName.replacingOccurrences(of: "{Year}", with: "Unknown")
            newName = newName.replacingOccurrences(of: "{Month}", with: "Unknown")
            newName = newName.replacingOccurrences(of: "{Day}", with: "Unknown")
        }
        
        newName = newName.replacingOccurrences(of: "{Camera}", with: data.make ?? "UnknownMake")
        newName = newName.replacingOccurrences(of: "{Model}", with: data.model ?? "UnknownModel")
        
        let ext = url.pathExtension
        if ext.isEmpty {
            return newName
        } else {
            return "\(newName).\(ext)"
        }
    }
    
    // Batch Time Shift
    public static func shiftTime(in data: inout EXIFData, by timeInterval: TimeInterval) {
        guard let dateTimeStr = data.dateTimeOriginal else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if let date = formatter.date(from: dateTimeStr) {
            let shiftedDate = date.addingTimeInterval(timeInterval)
            data.dateTimeOriginal = formatter.string(from: shiftedDate)
        }
    }
    
    // Batch Apply Presets
    public static func applyPreset(preset: EXIFData, to data: inout EXIFData) {
        if let artist = preset.artist { data.artist = artist }
        if let copyright = preset.copyright { data.copyright = copyright }
        if let make = preset.make { data.make = make }
        if let model = preset.model { data.model = model }
        if let lens = preset.lensModel { data.lensModel = lens }
        if let software = preset.software { data.software = software }
        // Depending on needs, could extend to override anything
    }
    
    // Perform processing and write to output folder
    // Returns the URL of the new file
    public static func processFile(url: URL, newEXIF: EXIFData?, newName: String?, outputFolder: URL) throws -> URL {
        var finalName = url.lastPathComponent
        if let newName = newName, !newName.isEmpty {
            finalName = newName
        }
        
        let outputURL = outputFolder.appendingPathComponent(finalName)
        
        // Prevent overwrite directly
        var finalOutputURL = outputURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalOutputURL.path) {
            let base = outputURL.deletingPathExtension().lastPathComponent
            let ext = outputURL.pathExtension
            let name = "\(base)_\(counter).\(ext)"
            finalOutputURL = outputFolder.appendingPathComponent(name)
            counter += 1
        }
        
        if let newEXIF = newEXIF, !EXIFManager.isVideo(url: url) && !EXIFManager.isRAW(url: url) {
            try EXIFManager.writeEXIF(to: finalOutputURL, originalURL: url, newEXIF: newEXIF)
        } else {
            // Either read-only format or no EXIF change, just copy
            try FileManager.default.copyItem(at: url, to: finalOutputURL)
        }
        
        return finalOutputURL
    }
}
