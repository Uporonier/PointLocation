import Foundation

func near(_ a: Double, _ b: Double, _ tolerance: Double = 1e-7) {
    precondition(abs(a - b) < tolerance, "Mismatch: \(a) / \(b)")
}
let beijing = SelectedCoordinate(latitude: 39.908823, longitude: 116.397470)
let projected = MapCoordinateCorrection.forward(beijing)
near(projected.latitude, 39.91022649807321)
near(projected.longitude, 116.4037135824225)
let restored = MapCoordinateCorrection.deviceCoordinate(projected, enabled: true)
near(restored.latitude, beijing.latitude)
near(restored.longitude, beijing.longitude)

let jinan = SelectedCoordinate(latitude: 36.674901, longitude: 117.055382)
precondition(MapCoordinateCorrection.deviceCoordinate(jinan, enabled: false) == jinan)
let corrected = MapCoordinateCorrection.deviceCoordinate(jinan, enabled: true)
// Screenshot shows the uncorrected device point east of the selected map point.
precondition(corrected.longitude < jinan.longitude)
let roundTrip = MapCoordinateCorrection.forward(corrected)
near(roundTrip.latitude, jinan.latitude)
near(roundTrip.longitude, jinan.longitude)
// Each heartbeat receives the raw map point, not the previously converted output.
precondition(MapCoordinateCorrection.deviceCoordinate(jinan, enabled: true) == corrected)
for p in [SelectedCoordinate(latitude: 48.8566, longitude: 2.3522),
          SelectedCoordinate(latitude: 40.7128, longitude: -74.0060),
          SelectedCoordinate(latitude: 90, longitude: 180)] {
    precondition(MapCoordinateCorrection.deviceCoordinate(p, enabled: true) == p)
}
print("Coordinate checks passed. Jinan device point: \(corrected.latitude), \(corrected.longitude)")
