import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreLocation
import AVFoundation

public enum EXIFManagerError: Error {
    case invalidSource
    case cannotCreateDestination
    case unsupportedFormatForWriting
    case cannotWrite
}

public class EXIFManager {
    
    public static func isVideo(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "avi"].contains(ext)
    }
    
    public static func isRAW(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["cr2", "nef", "arw", "dng"].contains(ext)
    }
    
    public static func readEXIF(from url: URL) async -> EXIFData? {
        if isVideo(url: url) {
            return await readVideoMetadata(from: url)
        } else {
            return readImageMetadata(from: url)
        }
    }
    
    private static func readVideoMetadata(from url: URL) async -> EXIFData? {
        let asset = AVAsset(url: url)
        var data = EXIFData()
        
        do {
            let duration = try await asset.load(.duration)
            data.duration = duration.seconds
            
            let metadata = try await asset.load(.metadata)
            for item in metadata {
                if let commonKey = item.commonKey {
                    if commonKey == .commonKeyCreationDate, let stringValue = try? await item.load(.stringValue) {
                        data.dateTimeOriginal = stringValue
                    }
                    if commonKey == .commonKeyLocation, let stringValue = try? await item.load(.stringValue) {
                        // iOS ISO 6709 string parse e.g. "+37.3323-122.0312/"
                        if let coords = parseISO6709(stringValue) {
                            data.coordinate = coords
                        }
                    }
                    if commonKey == .commonKeyMake, let stringValue = try? await item.load(.stringValue) {
                        data.make = stringValue
                    }
                    if commonKey == .commonKeyModel, let stringValue = try? await item.load(.stringValue) {
                        data.model = stringValue
                    }
                }
            }
            return data
        } catch {
            return nil
        }
    }
    
    private static func parseISO6709(_ string: String) -> CLLocationCoordinate2D? {
        // very basic parse for "+37.3323-122.0312/"
        let pattern = "([+-][0-9.]+)([+-][0-9.]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = string as NSString
        let results = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        if let match = results.first {
            let latStr = nsString.substring(with: match.range(at: 1))
            let lonStr = nsString.substring(with: match.range(at: 2))
            if let lat = Double(latStr), let lon = Double(lonStr) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        return nil
    }
    
    private static func readImageMetadata(from url: URL) -> EXIFData? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        var exifData = EXIFData()
        
        exifData.colorProfile = properties[kCGImagePropertyProfileName as String] as? String
        exifData.colorDepth = properties[kCGImagePropertyDepth as String] as? Int
        
        if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            exifData.make = tiffDict[kCGImagePropertyTIFFMake as String] as? String
            exifData.model = tiffDict[kCGImagePropertyTIFFModel as String] as? String
            exifData.software = tiffDict[kCGImagePropertyTIFFSoftware as String] as? String
            exifData.artist = tiffDict[kCGImagePropertyTIFFArtist as String] as? String
            exifData.copyright = tiffDict[kCGImagePropertyTIFFCopyright as String] as? String
        }
        
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exifData.lensModel = exifDict[kCGImagePropertyExifLensModel as String] as? String
            exifData.fNumber = exifDict[kCGImagePropertyExifFNumber as String] as? Double
            exifData.exposureTime = exifDict[kCGImagePropertyExifExposureTime as String] as? Double
            exifData.isoSpeedRatings = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int]
            exifData.focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
            exifData.dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String
        }
        
        if let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let lat = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
               let lon = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double {
                let latRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String == "S" ? -1.0 : 1.0
                let lonRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String == "W" ? -1.0 : 1.0
                exifData.coordinate = CLLocationCoordinate2D(latitude: lat * latRef, longitude: lon * lonRef)
            }
            exifData.altitude = gpsDict[kCGImagePropertyGPSAltitude as String] as? Double
        }
        
        return exifData
    }
    
    // Writing EXIF to image files. RAW and Videos are not supported for native write here.
    public static func writeEXIF(to outputURL: URL, originalURL: URL, newEXIF: EXIFData) throws {
        if isVideo(url: originalURL) || isRAW(url: originalURL) {
            throw EXIFManagerError.unsupportedFormatForWriting
        }
        
        guard let source = CGImageSourceCreateWithURL(originalURL as CFURL, nil) else {
            throw EXIFManagerError.invalidSource
        }
        
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        var mutableProperties = properties
        
        // Update TIFF dict
        var tiffDict = mutableProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        tiffDict[kCGImagePropertyTIFFMake as String] = newEXIF.make
        tiffDict[kCGImagePropertyTIFFModel as String] = newEXIF.model
        tiffDict[kCGImagePropertyTIFFSoftware as String] = newEXIF.software
        tiffDict[kCGImagePropertyTIFFArtist as String] = newEXIF.artist
        tiffDict[kCGImagePropertyTIFFCopyright as String] = newEXIF.copyright
        mutableProperties[kCGImagePropertyTIFFDictionary as String] = tiffDict
        
        // Update EXIF dict
        var exifDict = mutableProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        exifDict[kCGImagePropertyExifLensModel as String] = newEXIF.lensModel
        exifDict[kCGImagePropertyExifFNumber as String] = newEXIF.fNumber
        exifDict[kCGImagePropertyExifExposureTime as String] = newEXIF.exposureTime
        exifDict[kCGImagePropertyExifISOSpeedRatings as String] = newEXIF.isoSpeedRatings
        exifDict[kCGImagePropertyExifFocalLength as String] = newEXIF.focalLength
        exifDict[kCGImagePropertyExifDateTimeOriginal as String] = newEXIF.dateTimeOriginal
        mutableProperties[kCGImagePropertyExifDictionary as String] = exifDict
        
        // Update GPS dict
        var gpsDict = mutableProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
        if let coordinate = newEXIF.coordinate {
            gpsDict[kCGImagePropertyGPSLatitude as String] = abs(coordinate.latitude)
            gpsDict[kCGImagePropertyGPSLatitudeRef as String] = coordinate.latitude >= 0 ? "N" : "S"
            gpsDict[kCGImagePropertyGPSLongitude as String] = abs(coordinate.longitude)
            gpsDict[kCGImagePropertyGPSLongitudeRef as String] = coordinate.longitude >= 0 ? "E" : "W"
        } else {
            gpsDict.removeValue(forKey: kCGImagePropertyGPSLatitude as String)
            gpsDict.removeValue(forKey: kCGImagePropertyGPSLatitudeRef as String)
            gpsDict.removeValue(forKey: kCGImagePropertyGPSLongitude as String)
            gpsDict.removeValue(forKey: kCGImagePropertyGPSLongitudeRef as String)
        }
        
        if let altitude = newEXIF.altitude {
            gpsDict[kCGImagePropertyGPSAltitude as String] = abs(altitude)
            gpsDict[kCGImagePropertyGPSAltitudeRef as String] = altitude >= 0 ? 0 : 1
        }
        mutableProperties[kCGImagePropertyGPSDictionary as String] = gpsDict
        
        guard let uti = CGImageSourceGetType(source) else {
            throw EXIFManagerError.invalidSource
        }
        
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, uti, 1, nil) else {
            throw EXIFManagerError.cannotCreateDestination
        }
        
        CGImageDestinationAddImageFromSource(destination, source, 0, mutableProperties as CFDictionary)
        
        if !CGImageDestinationFinalize(destination) {
            throw EXIFManagerError.cannotWrite
        }
    }
}
