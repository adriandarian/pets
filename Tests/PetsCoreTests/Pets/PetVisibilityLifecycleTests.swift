import PetsCore
import Testing

@Suite
struct PetVisibilityLifecycleTests {
    @Test
    func allPetsAreHiddenRequiresAtLeastOnePet() {
        #expect(!PetVisibilityLifecycle.allPetsAreHidden([]))
    }

    @Test
    func allPetsAreHiddenIsFalseWhenAnyPetIsVisible() {
        var hiddenPet = PetInstance.defaultInstance()
        hiddenPet.isVisible = false

        #expect(
            !PetVisibilityLifecycle.allPetsAreHidden([
                hiddenPet,
                PetInstance.defaultInstance(),
            ])
        )
    }

    @Test
    func allPetsAreHiddenIsTrueWhenEveryPetIsHidden() {
        var firstPet = PetInstance.defaultInstance()
        var secondPet = PetInstance.defaultInstance()
        firstPet.isVisible = false
        secondPet.isVisible = false

        #expect(PetVisibilityLifecycle.allPetsAreHidden([firstPet, secondPet]))
    }
}
