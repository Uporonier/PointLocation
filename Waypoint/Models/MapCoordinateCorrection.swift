import Foundation

/// Optional approximate GCJ-02 -> WGS-84 conversion at the device boundary.
/// MapKit documents WGS-84, so never infer the input frame from coordinates alone.
/// Enable only after observing a mainland basemap offset; retain raw map points.
enum MapCoordinateCorrection {
    static let preferenceKey = "mainlandMapCoordinateCorrection"
    private static let axis = 6_378_245.0
    private static let eccentricity = 0.00669342162296594323

    static func deviceCoordinate(_ point: SelectedCoordinate, enabled: Bool) -> SelectedCoordinate {
        guard enabled, point.isValid, isWithinNumericBounds(point) else { return point }
        var estimate = point
        for _ in 0..<10 {
            let projected = forward(estimate)
            let latitudeError = projected.latitude - point.latitude
            let longitudeError = projected.longitude - point.longitude
            estimate.latitude -= latitudeError
            estimate.longitude -= longitudeError
            if max(abs(latitudeError), abs(longitudeError)) < 1e-9 { break }
        }
        return estimate.isValid ? estimate : point
    }

    // Numerical guard only, not a political/geographic mainland boundary.
    // The user opts in; overseas and border locations must use the unmodified mode.
    private static func isWithinNumericBounds(_ p: SelectedCoordinate) -> Bool {
        (72.004...137.8347).contains(p.longitude) &&
            (0.8293...55.8271).contains(p.latitude)
    }

    static func forward(_ p: SelectedCoordinate) -> SelectedCoordinate {
        let x = p.longitude - 105
        let y = p.latitude - 35
        var lat = -100 + 2*x + 3*y + 0.2*y*y + 0.1*x*y + 0.2*sqrt(abs(x))
        lat += (20*sin(6*x*Double.pi) + 20*sin(2*x*Double.pi))*2/3
        lat += (20*sin(y*Double.pi) + 40*sin(y/3*Double.pi))*2/3
        lat += (160*sin(y/12*Double.pi) + 320*sin(y*Double.pi/30))*2/3
        var lon = 300 + x + 2*y + 0.1*x*x + 0.1*x*y + 0.1*sqrt(abs(x))
        lon += (20*sin(6*x*Double.pi) + 20*sin(2*x*Double.pi))*2/3
        lon += (20*sin(x*Double.pi) + 40*sin(x/3*Double.pi))*2/3
        lon += (150*sin(x/12*Double.pi) + 300*sin(x/30*Double.pi))*2/3
        let radians = p.latitude / 180 * Double.pi
        let magic = 1 - eccentricity * pow(sin(radians), 2)
        let root = sqrt(magic)
        lat = lat * 180 / ((axis * (1 - eccentricity)) / (magic * root) * Double.pi)
        lon = lon * 180 / (axis / root * cos(radians) * Double.pi)
        return SelectedCoordinate(latitude: p.latitude + lat, longitude: p.longitude + lon)
    }
}
