import SwiftUI

/// A visible alignment guide line on the editor canvas.
struct SnapGuide: Identifiable, Equatable {
    let id = UUID()
    let orientation: Orientation
    let position: CGFloat   // x for vertical, y for horizontal

    enum Orientation: Equatable {
        case horizontal  // runs left-to-right at y = position
        case vertical    // runs top-to-bottom at x = position
    }
}

/// Result of a snap computation.
struct SnapResult {
    var snappedRect: CGRect
    var activeGuides: [SnapGuide]
}

/// Engine that computes snap alignment guides for widget positioning.
enum SnapGuideEngine {

    /// Compute snapped position for a proposed rect.
    /// Checks alignment with container edges/center, grid lines, and other widgets' edges (not centers).
    /// Uses deduplicated reference sets to avoid over-snapping.
    static func computeSnap(
        for proposed: CGRect,
        in containerSize: CGSize,
        others: [WidgetConfig],
        threshold: CGFloat = 5,
        gridSpacing: CGFloat = 0
    ) -> SnapResult {
        var snappedRect = proposed
        var guides: [SnapGuide] = []

        // Collect reference lines as Sets to auto-deduplicate
        var hRefs = Set<CGFloat>()  // horizontal reference y-values
        var vRefs = Set<CGFloat>()  // vertical reference x-values

        // Container edges and center
        hRefs.formUnion([0, round(containerSize.height / 2), containerSize.height])
        vRefs.formUnion([0, round(containerSize.width / 2), containerSize.width])

        // Grid lines (if spacing > 0)
        if gridSpacing > 0 {
            var gx: CGFloat = gridSpacing
            while gx < containerSize.width {
                vRefs.insert(round(gx))
                gx += gridSpacing
            }
            var gy: CGFloat = gridSpacing
            while gy < containerSize.height {
                hRefs.insert(round(gy))
                gy += gridSpacing
            }
        }

        // Other widgets — edges only (no center), rounded to avoid float noise
        for widget in others {
            guard let wx = widget.x, let wy = widget.y,
                  let ww = widget.width, let wh = widget.height else { continue }
            hRefs.formUnion([round(wy), round(wy + wh)])
            vRefs.formUnion([round(wx), round(wx + ww)])
        }

        // Candidate edges of the proposed rect
        let proposedLeft = proposed.minX
        let proposedRight = proposed.maxX
        let proposedCenterX = proposed.midX
        let proposedTop = proposed.minY
        let proposedBottom = proposed.maxY
        let proposedCenterY = proposed.midY

        // Snap X axis — find the single closest reference within threshold
        var bestSnapX: (offset: CGFloat, guide: CGFloat)? = nil

        for ref in vRefs {
            for candidateX in [proposedLeft, proposedCenterX, proposedRight] {
                let dist = abs(candidateX - ref)
                if dist < threshold {
                    if bestSnapX == nil || dist < abs(bestSnapX!.offset) {
                        bestSnapX = (ref - candidateX, ref)
                    }
                }
            }
        }

        if let snap = bestSnapX {
            snappedRect.origin.x += snap.offset
            guides.append(SnapGuide(orientation: .vertical, position: snap.guide))
        }

        // Snap Y axis — find the single closest reference within threshold
        var bestSnapY: (offset: CGFloat, guide: CGFloat)? = nil

        for ref in hRefs {
            for candidateY in [proposedTop, proposedCenterY, proposedBottom] {
                let dist = abs(candidateY - ref)
                if dist < threshold {
                    if bestSnapY == nil || dist < abs(bestSnapY!.offset) {
                        bestSnapY = (ref - candidateY, ref)
                    }
                }
            }
        }

        if let snap = bestSnapY {
            snappedRect.origin.y += snap.offset
            guides.append(SnapGuide(orientation: .horizontal, position: snap.guide))
        }

        return SnapResult(snappedRect: snappedRect, activeGuides: guides)
    }
}
