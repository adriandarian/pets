import CoreGraphics

public enum PetHoverExcitement {
    public static func usesContinuousSpriteMotion(status: HarnessSessionStatus, isHovered: Bool) -> Bool {
        status.usesContinuousSpriteMotion || isHovered
    }

    public static func scale(isHovered: Bool) -> CGFloat {
        1.0
    }

    public static func verticalOffset(isHovered: Bool) -> CGFloat {
        isHovered ? -7 : 0
    }
}
