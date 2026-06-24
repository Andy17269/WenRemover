import SwiftUI
import MapKit

struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct EXIFInfoWrapper: Identifiable {
    let id = UUID()
    let url: URL
    let data: EXIFData
}

struct EXIFInfoView: View {
    let url: URL
    let data: EXIFData
    
    @State private var region: MKCoordinateRegion
    
    init(url: URL, data: EXIFData) {
        self.url = url
        self.data = data
        if let coord = data.coordinate {
            _region = State(initialValue: MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion())
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    VStack(spacing: 8) {
                        infoRow(title: LocalizedStringKey("exif.make"), value: data.make)
                        infoRow(title: LocalizedStringKey("exif.model"), value: data.model)
                        infoRow(title: LocalizedStringKey("exif.lens"), value: data.lensModel)
                        infoRow(title: LocalizedStringKey("exif.datetime"), value: data.dateTimeOriginal)
                        infoRow(title: LocalizedStringKey("exif.colorProfile"), value: data.colorProfile)
                        infoRow(title: LocalizedStringKey("exif.colorDepth"), value: data.colorDepth.map { "\($0)-bit" })
                        infoRow(title: LocalizedStringKey("exif.focalLength"), value: data.focalLength.map { String(format: "%.1f mm", $0) })
                        infoRow(title: LocalizedStringKey("exif.aperture"), value: data.fNumber.map { String(format: "f/%.1f", $0) })
                        infoRow(title: LocalizedStringKey("exif.exposureTime"), value: data.exposureTime.map { formatExposureTime($0) })
                        infoRow(title: LocalizedStringKey("exif.iso"), value: data.isoSpeedRatings?.first.map { String($0) })
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                    
                    if let coord = data.coordinate {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("exif.location"))
                                .font(.headline)
                            
                            Map(coordinateRegion: $region, annotationItems: [MapLocation(coordinate: coord)]) { location in
                                MapMarker(coordinate: location.coordinate, tint: .red)
                            }
                            .frame(height: 200)
                            .cornerRadius(8)
                            
                            Text("\(coord.latitude), \(coord.longitude)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text(LocalizedStringKey("exif.noLocation"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 300)
    }
    
    @ViewBuilder
    private func infoRow(title: LocalizedStringKey, value: String?) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "-")
                .bold()
                .multilineTextAlignment(.trailing)
        }
    }
    
    private func formatExposureTime(_ time: Double) -> String {
        if time >= 1 {
            return String(format: "%.1f s", time)
        } else {
            return "1/\(Int(round(1/time))) s"
        }
    }
}
