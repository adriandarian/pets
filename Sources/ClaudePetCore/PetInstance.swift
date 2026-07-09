import CoreGraphics
import Foundation

public struct PetInstance: Identifiable, Equatable, Codable, Sendable {
    public typealias ID = UUID

    public var id: ID
    public var name: String
    public var petID: ClaudePetID
    public var pixelation: PetSpritePixelation
    public var sessionContextLineCount: Int
    public var animationSettings: PetAnimationSettings
    public var isVisible: Bool
    public var overlayPosition: PetOverlayPosition

    public init(
        id: ID = UUID(),
        name: String,
        petID: ClaudePetID,
        pixelation: PetSpritePixelation,
        sessionContextLineCount: Int,
        animationSettings: PetAnimationSettings = .default,
        isVisible: Bool = true,
        overlayPosition: PetOverlayPosition = .default
    ) {
        self.id = id
        self.name = name
        self.petID = petID
        self.pixelation = ClaudePetCatalog.pixelation(pixelation, allowedFor: petID)
        self.sessionContextLineCount = PetSessionContextLineCount.clamped(sessionContextLineCount)
        self.animationSettings = animationSettings
        self.isVisible = isVisible
        self.overlayPosition = overlayPosition
    }

    public static func defaultInstance(id: ID = UUID()) -> PetInstance {
        migratedDefault(
            id: id,
            petID: ClaudePetCatalog.defaultPetID,
            pixelation: .off,
            sessionContextLineCount: PetSessionContextLineCount.defaultValue
        )
    }

    public static func migratedDefault(
        id: ID = UUID(),
        petID: ClaudePetID,
        pixelation: PetSpritePixelation,
        sessionContextLineCount: Int
    ) -> PetInstance {
        PetInstance(
            id: id,
            name: petID == .classicClaude ? "Classic Claude" : ClaudePetCatalog.displayName(for: petID),
            petID: petID,
            pixelation: pixelation,
            sessionContextLineCount: sessionContextLineCount
        )
    }

    public mutating func updatePetID(_ petID: ClaudePetID) {
        self.petID = petID
        pixelation = ClaudePetCatalog.pixelation(pixelation, allowedFor: petID)
    }

    public mutating func updatePixelation(_ pixelation: PetSpritePixelation) {
        self.pixelation = ClaudePetCatalog.pixelation(pixelation, allowedFor: petID)
    }

    public mutating func updateSessionContextLineCount(_ lineCount: Int) {
        sessionContextLineCount = PetSessionContextLineCount.clamped(lineCount)
    }
}

public struct PetAnimationSettings: Equatable, Codable, Sendable {
    public var isHoverBounceEnabled: Bool
    public var isIdleMotionEnabled: Bool
    public var areStatusMoodsEnabled: Bool

    public init(
        isHoverBounceEnabled: Bool,
        isIdleMotionEnabled: Bool,
        areStatusMoodsEnabled: Bool
    ) {
        self.isHoverBounceEnabled = isHoverBounceEnabled
        self.isIdleMotionEnabled = isIdleMotionEnabled
        self.areStatusMoodsEnabled = areStatusMoodsEnabled
    }

    public static let `default` = PetAnimationSettings(
        isHoverBounceEnabled: true,
        isIdleMotionEnabled: true,
        areStatusMoodsEnabled: true
    )
}

public struct PetOverlayPosition: Equatable, Codable, Sendable {
    public var origin: CGPoint?
    public var horizontalPlacement: PetOverlayHorizontalPlacement

    public init(
        origin: CGPoint?,
        horizontalPlacement: PetOverlayHorizontalPlacement
    ) {
        self.origin = origin
        self.horizontalPlacement = horizontalPlacement
    }

    public static let `default` = PetOverlayPosition(
        origin: nil,
        horizontalPlacement: .trailing
    )
}
