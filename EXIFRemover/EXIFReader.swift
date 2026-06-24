import Foundation
import ImageIO
import CoreLocation

struct EXIFData {
    var make: String?
    var model: String?
    var lensModel: String?
    var fNumber: Double?
    var exposureTime: Double?
    var isoSpeedRatings: [Int]?
    var focalLength: Double?
    var dateTimeOriginal: String?
    
    var coordinate: CLLocationCoordinate2D?
    var altitude: Double?
    
    var colorProfile: String?
    var colorDepth: Int?
}

class EXIFReader {
    static func readEXIF(from url: URL) -> EXIFData? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        var exifData = EXIFData()
        
        // 颜色和色深
        exifData.colorProfile = properties[kCGImagePropertyProfileName as String] as? String
        exifData.colorDepth = properties[kCGImagePropertyDepth as String] as? Int
        
        // 厂商和型号
        if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            exifData.make = tiffDict[kCGImagePropertyTIFFMake as String] as? String
            exifData.model = tiffDict[kCGImagePropertyTIFFModel as String] as? String
        }
        
        // EXIF
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exifData.lensModel = exifDict[kCGImagePropertyExifLensModel as String] as? String
            exifData.fNumber = exifDict[kCGImagePropertyExifFNumber as String] as? Double
            exifData.exposureTime = exifDict[kCGImagePropertyExifExposureTime as String] as? Double
            exifData.isoSpeedRatings = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int]
            exifData.focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
            exifData.dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String
        }
        
        // GPS
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
}
