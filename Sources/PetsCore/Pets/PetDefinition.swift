import Foundation

public struct PetCategoryDescriptor: Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let order: Int

    public init(id: String, displayName: String, order: Int) {
        self.id = id
        self.displayName = displayName
        self.order = order
    }

    public static let cloudPets = PetCategoryDescriptor(
        id: "cloud-pets",
        displayName: "Cloud Pets",
        order: 0
    )

    public static let tesslings = PetCategoryDescriptor(
        id: "tesslings",
        displayName: "Tesslings",
        order: 1
    )
}

public struct PetCapabilities: Equatable, Sendable {
    public let maximumPixelation: PetSpritePixelation
    public let supportsStatusMoods: Bool
    public let supportsHoverExcitement: Bool

    public init(
        maximumPixelation: PetSpritePixelation,
        supportsStatusMoods: Bool,
        supportsHoverExcitement: Bool
    ) {
        self.maximumPixelation = maximumPixelation
        self.supportsStatusMoods = supportsStatusMoods
        self.supportsHoverExcitement = supportsHoverExcitement
    }
}

public struct PetDefaultConfiguration: Equatable, Sendable {
    public let pixelation: PetSpritePixelation
    public let sessionContextLineCount: Int
    public let animationSettings: PetAnimationSettings

    public init(
        pixelation: PetSpritePixelation,
        sessionContextLineCount: Int,
        animationSettings: PetAnimationSettings
    ) {
        self.pixelation = pixelation
        self.sessionContextLineCount = sessionContextLineCount
        self.animationSettings = animationSettings
    }

    public static let standard = PetDefaultConfiguration(
        pixelation: .off,
        sessionContextLineCount: PetSessionContextLineCount.defaultValue,
        animationSettings: .default
    )
}

public struct PetPresentationConfiguration: Equatable, Sendable {
    public let contentScale: Double
    public let anchorX: Double
    public let anchorY: Double
    public let shadowWidth: Double
    public let shadowHeight: Double
    public let shadowOpacity: Double
    public let transitionDuration: TimeInterval

    public init(
        contentScale: Double,
        anchorX: Double,
        anchorY: Double,
        shadowWidth: Double,
        shadowHeight: Double,
        shadowOpacity: Double,
        transitionDuration: TimeInterval
    ) {
        self.contentScale = contentScale
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.shadowWidth = shadowWidth
        self.shadowHeight = shadowHeight
        self.shadowOpacity = shadowOpacity
        self.transitionDuration = transitionDuration
    }

    public static let standard = PetPresentationConfiguration(
        contentScale: 1,
        anchorX: 0,
        anchorY: 0,
        shadowWidth: 66,
        shadowHeight: 11,
        shadowOpacity: 0.22,
        transitionDuration: 0.18
    )
}

public enum PetRenderSource: Equatable, Sendable {
    case assetPack(PetArtPack)
}

open class PetDefinition: @unchecked Sendable {
    public let id: PetID
    public let displayName: String
    public let rarity: PetRarity
    public let category: PetCategoryDescriptor
    public let capabilities: PetCapabilities
    public let defaults: PetDefaultConfiguration
    public let presentation: PetPresentationConfiguration
    public let ambientEffect: PetAmbientEffectKind
    public let renderSource: PetRenderSource

    public init(
        id: PetID,
        displayName: String,
        rarity: PetRarity,
        category: PetCategoryDescriptor,
        capabilities: PetCapabilities,
        defaults: PetDefaultConfiguration,
        presentation: PetPresentationConfiguration,
        ambientEffect: PetAmbientEffectKind = .none,
        renderSource: PetRenderSource
    ) {
        self.id = id
        self.displayName = displayName
        self.rarity = rarity
        self.category = category
        self.capabilities = capabilities
        self.defaults = defaults
        self.presentation = presentation
        self.ambientEffect = ambientEffect
        self.renderSource = renderSource
    }

}
