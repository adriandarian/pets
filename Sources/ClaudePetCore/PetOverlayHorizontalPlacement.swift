import CoreGraphics

public enum PetOverlayHorizontalPlacement: String, Codable, Equatable, Sendable {
    case leading
    case trailing

    public static func preferred(
        for panelFrame: CGRect,
        in screenVisibleFrame: CGRect,
        current: PetOverlayHorizontalPlacement
    ) -> PetOverlayHorizontalPlacement {
        if panelFrame.minX < screenVisibleFrame.minX {
            return .leading
        }

        if panelFrame.maxX > screenVisibleFrame.maxX {
            return .trailing
        }

        return current
    }

    public static func adjustedPanelFrame(
        _ panelFrame: CGRect,
        in screenVisibleFrame: CGRect
    ) -> CGRect {
        var adjustedFrame = panelFrame
        let maximumX = max(screenVisibleFrame.minX, screenVisibleFrame.maxX - panelFrame.width)
        adjustedFrame.origin.x = min(max(panelFrame.minX, screenVisibleFrame.minX), maximumX)
        return adjustedFrame
    }
}
