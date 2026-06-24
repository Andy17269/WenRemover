import Foundation
import CoreGraphics

enum PrivacyType: String, CaseIterable {
    case face = "Face"
    case text = "Text"
    case barcode = "Barcode"
    case manual = "Manual"
    
    var priority: Int {
        switch self {
        case .manual: return 4
        case .face: return 3
        case .barcode: return 2
        case .text: return 1
        }
    }
}

struct PrivacyRegion: Identifiable, Equatable {
    let id: UUID
    var boundingBox: CGRect // 归一化坐标
    var type: PrivacyType
    
    init(id: UUID = UUID(), boundingBox: CGRect, type: PrivacyType) {
        self.id = id
        self.boundingBox = boundingBox
        self.type = type
    }
    
    func intersectionOverUnion(with other: PrivacyRegion) -> CGFloat {
        let intersection = self.boundingBox.intersection(other.boundingBox)
        if intersection.isNull || intersection.width < 0 || intersection.height < 0 {
            return 0
        }
        let intersectionArea = intersection.width * intersection.height
        let selfArea = self.boundingBox.width * self.boundingBox.height
        let otherArea = other.boundingBox.width * other.boundingBox.height
        let unionArea = selfArea + otherArea - intersectionArea
        
        if unionArea <= 0 { return 0 }
        return intersectionArea / unionArea
    }
    
    func merged(with other: PrivacyRegion) -> PrivacyRegion {
        let newBox = self.boundingBox.union(other.boundingBox)
        let newType = self.type.priority > other.type.priority ? self.type : other.type
        return PrivacyRegion(boundingBox: newBox, type: newType)
    }
}
