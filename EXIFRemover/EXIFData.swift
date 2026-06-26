import Foundation
import CoreLocation

public struct EXIFData: Equatable {
    public var make: String?
    public var model: String?
    public var lensModel: String?
    public var software: String?
    public var artist: String?
    public var copyright: String?
    
    public var fNumber: Double?
    public var exposureTime: Double?
    public var isoSpeedRatings: [Int]?
    public var focalLength: Double?
    public var dateTimeOriginal: String?
    
    // GPS
    public var latitude: Double?
    public var longitude: Double?
    public var altitude: Double?
    
    public var colorProfile: String?
    public var colorDepth: Int?
    
    // Video specific
    public var duration: Double?
    public var videoCodec: String?
    
    public init() {}
    
    public var coordinate: CLLocationCoordinate2D? {
        get {
            guard let lat = latitude, let lon = longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    }
}
