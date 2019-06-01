/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The data model.
*/

import SwiftUI
import Combine

/// The data model for a single chart ring.
class Ring: BindableObject {
    /// A single wedge within a chart ring.
    struct Wedge: Equatable {
        /// The wedge's width, as an angle in radians.
        var width: Double
        /// The wedge's cross-axis depth, in range [0,1].
        var depth: Double
        /// The ring's hue.
        var hue: Double

        /// The wedge's start location, as an angle in radians.
        fileprivate(set) var start = 0.0
        /// The wedge's end location, as an angle in radians.
        fileprivate(set) var end = 0.0

        static var random: Wedge {
            return Wedge(
                width: .random(in: 0.5 ... 1),
                depth: .random(in: 0.2 ... 1),
                hue: .random(in: 0 ... 1))
        }
    }

    /// The collection of wedges, tracked by their id.
    private(set) var wedges = [Int: Wedge]()

    /// The display order of the wedges.
    private(set) var wedgeIDs = [Int]()

    /// When true, periodically updates the data with random changes.
    var randomWalk = false { didSet { updateTimer() } }

    /// The next id to allocate.
    private var nextID = 0

    /// Trivial publisher for our changes.
    let didChange = PassthroughSubject<Ring, Never>()

    /// Called after each change; updates derived model values and posts
    /// the notification.
    private func modelDidChange() {
        guard nestedUpdates == 0 else { return }

        /// Recalculate locations, to pack within circle.

        let total = wedgeIDs.reduce(0.0) { $0 + wedges[$1]!.width }
        let scale = (.pi * 2) / max(.pi * 2, total)

        var location = 0.0
        for id in wedgeIDs {
            var wedge = wedges[id]!
            wedge.start = location * scale
            location += wedge.width
            wedge.end = location * scale
            wedges[id] = wedge
        }
            
        didChange.send(self)
    }

    /// Non-zero while a batch of updates is being processed.
    private var nestedUpdates = 0

    /// Invokes `body()` such that any changes it makes to the model
    /// will only post a single notification to observers.
    func batch(_ body: () -> Void) {
        nestedUpdates += 1
        defer {
            nestedUpdates -= 1
            if nestedUpdates == 0 {
                modelDidChange()
            }
        }
        body()
    }

    /// Adds a new wedge description to `array`.
    func addWedge(_ value: Wedge) {
        let id = nextID
        nextID += 1
        wedges[id] = value
        wedgeIDs.append(id)
        modelDidChange()
    }

    /// Removes the wedge with `id`.
    func removeWedge(id: Int) {
        if let indexToRemove = wedgeIDs.firstIndex(where: { $0 == id }) {
            wedgeIDs.remove(at: indexToRemove)
            wedges.removeValue(forKey: id)
            modelDidChange()
        }
    }

    /// Clear all data.
    func reset() {
        if !wedgeIDs.isEmpty {
            wedgeIDs = []
            wedges = [:]
            modelDidChange()
        }
    }

    /// Randomly changes values of existing wedges.
    func randomize() {
        withAnimation(.fluidSpring(stiffness: 10, dampingFraction: 0.5)) {
            for id in wedgeIDs {
                var wedge = wedges[id]!
                wedge.width = .random(in: max(0.2, wedge.width - 0.2)
                    ... min(1, wedge.width + 0.2))
                wedge.depth = .random(in: max(0.2, wedge.depth - 0.2)
                    ... min(1, wedge.depth + 0.2))
                wedges[id] = wedge
            }
            modelDidChange()
        }
    }

    private var timer: Timer?

    /// Ensures the random-walk timer has the correct state.
    func updateTimer() {
        if randomWalk, timer == nil {
            randomize()
            timer = Timer.scheduledTimer(
                withTimeInterval: 1, repeats: true
            ) { [weak self] _ in
                self?.randomize()
            }
        } else if !randomWalk, let timer = self.timer {
            timer.invalidate()
            self.timer = nil
        }
        modelDidChange()
    }
}

/// Extend the wedge description to conform to the Animatable type to
/// simplify creation of custom shapes using the wedge.
extension Ring.Wedge: Animatable {
    // Use a composition of pairs to merge the interpolated values into
    // a single type. AnimatablePair acts as a single interpolatable
    // values, given two interpolatable input types.

    // We'll interpolate the derived start/end angles, and the depth
    // and color values. The width parameter is not used for rendering,
    // and so doesn't need to be interpolated.

    typealias AnimatableData = AnimatablePair<
        AnimatablePair<Double, Double>, AnimatablePair<Double, Double>>

    var animatableData: AnimatableData {
        get {
            .init(.init(start, end), .init(depth, hue))
        }
        set {
            start = newValue.first.first
            end = newValue.first.second
            depth = newValue.second.first
            hue = newValue.second.second
        }
    }
}
