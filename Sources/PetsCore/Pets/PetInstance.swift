import CoreGraphics
import Foundation

public struct PetInstance: Identifiable, Equatable, Codable, Sendable {
    public typealias ID = UUID

    public var id: ID
    public var name: String
    public var petID: PetID
    public var pixelation: PetSpritePixelation
    public var sessionContextLineCount: Int
    public var animationSettings: PetAnimationSettings
    public var isVisible: Bool
    public var overlayPosition: PetOverlayPosition

    public init(
        id: ID = UUID(),
        name: String,
        petID: PetID,
        pixelation: PetSpritePixelation,
        sessionContextLineCount: Int,
        animationSettings: PetAnimationSettings = .default,
        isVisible: Bool = true,
        overlayPosition: PetOverlayPosition = .default
    ) {
        let resolvedPetID = PetCatalog.resolvedPetID(petID)
        self.id = id
        self.name = name
        self.petID = resolvedPetID
        self.pixelation = PetCatalog.pixelation(pixelation, allowedFor: resolvedPetID)
        self.sessionContextLineCount = PetSessionContextLineCount.clamped(sessionContextLineCount)
        self.animationSettings = animationSettings
        self.isVisible = isVisible
        self.overlayPosition = overlayPosition
    }

    public static func defaultInstance(id: ID = UUID()) -> PetInstance {
        let defaults = PetCatalog.definition(for: PetCatalog.defaultPetID)?.defaults ?? .standard
        return PetInstance(
            id: id,
            name: PetCatalog.displayName(for: PetCatalog.defaultPetID),
            petID: PetCatalog.defaultPetID,
            pixelation: defaults.pixelation,
            sessionContextLineCount: defaults.sessionContextLineCount,
            animationSettings: defaults.animationSettings
        )
    }

    public static func migratedDefault(
        id: ID = UUID(),
        petID: PetID,
        pixelation: PetSpritePixelation,
        sessionContextLineCount: Int
    ) -> PetInstance {
        let resolvedPetID = PetCatalog.resolvedPetID(petID)
        return PetInstance(
            id: id,
            name: PetCatalog.displayName(for: resolvedPetID),
            petID: resolvedPetID,
            pixelation: pixelation,
            sessionContextLineCount: sessionContextLineCount
        )
    }

    public mutating func updatePetID(_ petID: PetID) {
        self.petID = PetCatalog.resolvedPetID(petID)
        pixelation = PetCatalog.pixelation(pixelation, allowedFor: self.petID)
    }

    public mutating func changePetID(_ petID: PetID) {
        let previousPetID = self.petID
        let previousDefaultName = PetCatalog.displayName(for: previousPetID)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let usesDefaultName = trimmedName.isEmpty
            || name == previousDefaultName
            || (previousPetID == .cuteCloud && name == "Cute Cloud")

        updatePetID(petID)
        if usesDefaultName {
            name = PetCatalog.displayName(for: self.petID)
        }
    }

    public mutating func updatePixelation(_ pixelation: PetSpritePixelation) {
        self.pixelation = PetCatalog.pixelation(pixelation, allowedFor: petID)
    }

    public mutating func updateSessionContextLineCount(_ lineCount: Int) {
        sessionContextLineCount = PetSessionContextLineCount.clamped(lineCount)
    }

    public func normalizedForCurrentCatalog() -> PetInstance {
        var normalized = self
        normalized.updatePetID(petID)
        return normalized
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case petID
        case pixelation
        case sessionContextLineCount
        case animationSettings
        case isVisible
        case overlayPosition
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedPetID = try container.decodeIfPresent(PetID.self, forKey: .petID)
            ?? PetCatalog.defaultPetID
        let resolvedPetID = PetCatalog.resolvedPetID(decodedPetID)
        let defaults = PetCatalog.definition(for: resolvedPetID)?.defaults ?? .standard

        self.init(
            id: try container.decodeIfPresent(ID.self, forKey: .id) ?? UUID(),
            name: try container.decodeIfPresent(String.self, forKey: .name)
                ?? PetCatalog.displayName(for: resolvedPetID),
            petID: resolvedPetID,
            pixelation: try container.decodeIfPresent(
                PetSpritePixelation.self,
                forKey: .pixelation
            ) ?? defaults.pixelation,
            sessionContextLineCount: try container.decodeIfPresent(
                Int.self,
                forKey: .sessionContextLineCount
            ) ?? defaults.sessionContextLineCount,
            animationSettings: try container.decodeIfPresent(
                PetAnimationSettings.self,
                forKey: .animationSettings
            ) ?? defaults.animationSettings,
            isVisible: try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true,
            overlayPosition: try container.decodeIfPresent(
                PetOverlayPosition.self,
                forKey: .overlayPosition
            ) ?? .default
        )
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

    private enum CodingKeys: String, CodingKey {
        case isHoverBounceEnabled
        case isIdleMotionEnabled
        case areStatusMoodsEnabled
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isHoverBounceEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .isHoverBounceEnabled
            ) ?? true,
            isIdleMotionEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .isIdleMotionEnabled
            ) ?? true,
            areStatusMoodsEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .areStatusMoodsEnabled
            ) ?? true
        )
    }
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

    private enum CodingKeys: String, CodingKey {
        case origin
        case horizontalPlacement
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            origin: try container.decodeIfPresent(CGPoint.self, forKey: .origin),
            horizontalPlacement: try container.decodeIfPresent(
                PetOverlayHorizontalPlacement.self,
                forKey: .horizontalPlacement
            ) ?? .trailing
        )
    }
}
