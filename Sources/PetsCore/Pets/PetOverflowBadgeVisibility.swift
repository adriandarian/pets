import CoreGraphics

public enum PetOverflowBadgeVisibility {
    public static func remainingBelowViewport(
        rowMinYValues: [CGFloat],
        viewportHeight: CGFloat
    ) -> Int {
        guard viewportHeight > 0 else { return 0 }
        return rowMinYValues.filter { $0 > viewportHeight }.count
    }
}
