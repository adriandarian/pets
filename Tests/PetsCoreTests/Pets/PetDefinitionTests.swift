import Testing
@testable import PetsCore

@Suite
struct PetDefinitionTests {
    @Test
    func definitionKeepsDeveloperConfigurationOutOfPetInstance() throws {
        let definition = try #require(PetCatalog.definition(for: .cuteCloud))
        let instance = PetInstance.defaultInstance()

        #expect(definition.id == .cuteCloud)
        #expect(definition is CumulusCloudPetDefinition)
        #expect(definition.defaults.pixelation == .off)
        #expect(instance.petID == definition.id)
    }

    @Test
    func cloudDefinitionsSelectTheirAmbientEffects() throws {
        #expect(try #require(PetCatalog.definition(for: .cuteCloud)).ambientEffect == .none)
        #expect(try #require(PetCatalog.definition(for: .nimbusCloud)).ambientEffect == .storm)
        #expect(try #require(PetCatalog.definition(for: .cirrusCloud)).ambientEffect == .wind)
        #expect(try #require(PetCatalog.definition(for: .lenticularCloud)).ambientEffect == .none)
        #expect(try #require(PetCatalog.definition(for: .snowCloud)).ambientEffect == .snow)
    }
}
