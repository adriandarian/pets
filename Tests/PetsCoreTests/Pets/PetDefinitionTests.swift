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
}
