import AppKit
import Foundation
import Testing
@testable import PetsCore

@Suite
struct PetTrackingProviderTests {
    @Test
    func providerIdentifiersMatchHarnessAndUsageIdentifiers() {
        #expect(PetTrackingProvider.claudeCode.rawValue == "claude")
        #expect(PetTrackingProvider.codex.rawValue == "codex")
        #expect(PetTrackingProvider.githubCopilot.rawValue == "copilot")
        #expect(PetTrackingProvider.cursor.rawValue == "cursor")
        #expect(PetTrackingProvider.ollama.rawValue == "ollama")
        #expect(PetTrackingProvider.gemini.rawValue == "gemini")
        #expect(PetTrackingProvider.antigravity.rawValue == "antigravity")
        #expect(PetTrackingProvider.hermes.rawValue == "hermes")
        #expect(PetTrackingProvider.t3Code.rawValue == "t3code")
        #expect(PetTrackingProvider.openDesign.rawValue == "open-design")
        #expect(PetTrackingProvider.kiro.rawValue == "kiro")
        #expect(PetTrackingProvider.zed.rawValue == "zed")
        #expect(PetTrackingProvider.windsurf.rawValue == "windsurf")
        #expect(PetTrackingProvider.openCode.rawValue == "opencode")
        #expect(PetTrackingProvider.pi.rawValue == "pi")
        #expect(PetTrackingProvider.notebookLM.rawValue == "notebooklm")
        #expect(PetTrackingProvider.lmStudio.rawValue == "lm-studio")
        #expect(PetTrackingProvider.stitch.rawValue == "stitch")
    }

    @Test
    func everyTrackerDeclaresHowItContributesToKeys() {
        let tokenProviders: Set<PetTrackingProvider> = [
            .claudeCode,
            .codex,
            .githubCopilot,
        ]

        for provider in PetTrackingProvider.allCases {
            #expect(provider.rewardTrackingMode == (
                tokenProviders.contains(provider) ? .tokenUsage : .trackedActivity
            ))
        }
    }

    @Test
    func bundledProviderIconsAreReadableForEveryTrackerAndAppearance() throws {
        for provider in PetTrackingProvider.allCases {
            for appearance in PetProviderIconAppearance.allCases {
                let iconURL = try #require(PetProviderIconResourceLocator.url(
                    for: provider,
                    appearance: appearance
                ))
                let image = try #require(NSImage(contentsOf: iconURL))
                #expect(image.isValid)
                #expect(image.size.width > 0)
                #expect(image.size.height > 0)
            }
        }
    }

    @Test
    func normalizationKeepsEachProviderOnOnlyTheFirstAssignedPet() {
        var first = PetInstance.defaultInstance(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        first.trackingProviders = [.claudeCode, .codex]

        var second = PetInstance.defaultInstance(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )
        second.trackingProviders = [.claudeCode, .codex, .githubCopilot]

        var third = PetInstance.defaultInstance(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        )
        third.trackingProviders = []

        let normalized = PetTrackerAssignments.normalized([first, second, third])

        #expect(normalized[0].trackingProviders == [.claudeCode, .codex])
        #expect(normalized[1].trackingProviders == [.githubCopilot])
        #expect(normalized[2].trackingProviders.isEmpty)
    }

    @Test
    func explicitlyUnassignedPetRoundTripsWithoutGainingAProvider() throws {
        var pet = PetInstance.defaultInstance()
        pet.trackingProviders = []

        let decoded = try JSONDecoder().decode(
            PetInstance.self,
            from: JSONEncoder().encode(pet)
        )

        #expect(decoded.trackingProviders.isEmpty)
    }

    @Test
    func assignmentCanAddSeveralProvidersToOnePet() {
        var pet = PetInstance.defaultInstance()
        pet.trackingProviders = []

        var instances = [pet]
        for provider in PetTrackingProvider.allCases {
            instances = PetTrackerAssignments.setting(
                provider,
                isEnabled: true,
                for: pet.id,
                in: instances
            )
        }

        #expect(instances[0].trackingProviders == Set(PetTrackingProvider.allCases))
    }

    @Test
    func assignmentRejectsAProviderOwnedByAnotherPetUntilItIsReleased() {
        var first = PetInstance.defaultInstance()
        first.trackingProviders = [.codex]
        var second = PetInstance.defaultInstance()
        second.trackingProviders = []

        var instances = PetTrackerAssignments.setting(
            .codex,
            isEnabled: true,
            for: second.id,
            in: [first, second]
        )
        #expect(instances[0].trackingProviders == [.codex])
        #expect(instances[1].trackingProviders.isEmpty)

        instances = PetTrackerAssignments.setting(
            .codex,
            isEnabled: false,
            for: first.id,
            in: instances
        )
        instances = PetTrackerAssignments.setting(
            .codex,
            isEnabled: true,
            for: second.id,
            in: instances
        )
        #expect(instances[0].trackingProviders.isEmpty)
        #expect(instances[1].trackingProviders == [.codex])
    }
}
