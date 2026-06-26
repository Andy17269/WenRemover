import SwiftUI
import MapKit
import CoreLocation

struct GPSMapView: View {
    @Binding var coordinate: CLLocationCoordinate2D?
    let isReadOnly: Bool
    @State private var region: MKCoordinateRegion
    @State private var addressString: String = ""
    @AppStorage("enableGlassmorphism") private var enableGlassmorphism = true
    @AppStorage("languagePreference") private var languagePreference: String = "system"
    
    private let geocoder = CLGeocoder()
    
    init(coordinate: Binding<CLLocationCoordinate2D?>, isReadOnly: Bool = false) {
        self._coordinate = coordinate
        self.isReadOnly = isReadOnly
        if let initial = coordinate.wrappedValue {
            _region = State(initialValue: MKCoordinateRegion(center: initial, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        } else {
            // Default to somewhere (e.g., Apple Park)
            let defaultCoord = CLLocationCoordinate2D(latitude: 37.334_900, longitude: -122.009_020)
            _region = State(initialValue: MKCoordinateRegion(center: defaultCoord, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Map(coordinateRegion: $region, annotationItems: coordinate != nil ? [MapPinItem(coordinate: coordinate!)] : []) { item in
                MapMarker(coordinate: item.coordinate, tint: .red)
            }
            .frame(height: 250)
            .cornerRadius(12)
            .padding()
            .onTapGesture { location in
                // Due to Map limitations in SwiftUI iOS 14-16, proper tap to add pin might need geometry reader or overlay.
                // For simplicity, we just use a button to "Set Pin at Center".
            }
            
            if !isReadOnly {
                HStack {
                    Button(action: {
                        coordinate = region.center
                        reverseGeocode(coordinate: region.center)
                    }) {
                        Label(localizedString("gps.setPinAtCenter"), systemImage: "mappin.and.ellipse")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        coordinate = nil
                        addressString = ""
                    }) {
                        Label(localizedString("button.remove"), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(coordinate == nil)
                }
                .padding(.horizontal)
            }
            
            if !addressString.isEmpty {
                Text(addressString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                Spacer().frame(height: 16)
            }
        }
        .background(enableGlassmorphism ? Color.clear : Color.windowBackground)
        .onAppear {
            if let c = coordinate {
                reverseGeocode(coordinate: c)
            }
        }
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                var address = ""
                if let name = placemark.name { address += name + ", " }
                if let locality = placemark.locality { address += locality + ", " }
                if let country = placemark.country { address += country }
                self.addressString = address.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            }
        }
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
}

struct MapPinItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
