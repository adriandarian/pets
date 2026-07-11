import Testing
@testable import PetsCore

@Suite
struct PetDefinitionTests {
    @Test
    func definitionKeepsDeveloperConfigurationOutOfPetInstance() {
        let definition = StubPetDefinition()
        let instance = PetInstance.defaultInstance()

        #expect(definition.id == .cuteCloud)
        #expect(definition.defaults.pixelation == .off)
        #expect(instance.petID == definition.id)
    }
}

private final class StubPetDefinition: PetDefinition, @unchecked Sendable {
    init() {
        super.init(
            id: .cuteCloud,
            displayName: "Cute Cloud",
            category: .cloudPets,
            capabilities: PetCapabilities(
                maximumPixelation: .medium,
                supportsStatusMoods: true,
                supportsHoverExcitement: true
            ),
            defaults: .standard,
            presentation: .standard,
            renderSource: .legacy(.cuteCloud)
        )
    }
}
