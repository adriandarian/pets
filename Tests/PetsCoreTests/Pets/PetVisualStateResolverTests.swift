import Testing
@testable import PetsCore

@Suite
struct PetVisualStateResolverTests {
    @Test
    func hoverExcitementHasHighestPriority() {
        let context = PetVisualContext(
            status: .waiting,
            hasActiveSessions: true,
            isHovered: true,
            animationSettings: .default
        )

        #expect(PetVisualStateResolver.requestedState(for: context) == .excited)
    }

    @Test
    func sessionStatusSelectsWaitingBusyAndIdleStates() {
        #expect(PetVisualStateResolver.requestedState(for: context(status: .waiting)) == .waiting)
        #expect(PetVisualStateResolver.requestedState(for: context(status: .busy)) == .busy)
        #expect(PetVisualStateResolver.requestedState(for: context(status: .idle)) == .idle)
    }

    @Test
    func noActiveSessionsRequestsSleeping() {
        let context = PetVisualContext(
            status: .unknown,
            hasActiveSessions: false,
            isHovered: false,
            animationSettings: .default
        )

        #expect(PetVisualStateResolver.requestedState(for: context) == .sleeping)
    }

    @Test
    func disabledStatusMoodsRequestIdle() {
        let settings = PetAnimationSettings(
            isHoverBounceEnabled: false,
            isIdleMotionEnabled: true,
            areStatusMoodsEnabled: false
        )
        let context = PetVisualContext(
            status: .busy,
            hasActiveSessions: true,
            isHovered: false,
            animationSettings: settings
        )

        #expect(PetVisualStateResolver.requestedState(for: context) == .idle)
    }

    @Test
    func disabledHoverExcitementDoesNotOverrideStatus() {
        let settings = PetAnimationSettings(
            isHoverBounceEnabled: false,
            isIdleMotionEnabled: true,
            areStatusMoodsEnabled: true
        )
        let context = PetVisualContext(
            status: .busy,
            hasActiveSessions: true,
            isHovered: true,
            animationSettings: settings
        )

        #expect(PetVisualStateResolver.requestedState(for: context) == .busy)
    }

    private func context(status: HarnessSessionStatus) -> PetVisualContext {
        PetVisualContext(
            status: status,
            hasActiveSessions: true,
            isHovered: false,
            animationSettings: .default
        )
    }
}
