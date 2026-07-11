public final class CodeBotPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .codeBot,
            displayName: "Code Bot",
            category: .workspacePets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .workspace
        )
    }
}

public final class TerminalCubePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .terminalCube,
            displayName: "Terminal Cube",
            category: .workspacePets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .workspace
        )
    }
}

public final class BookstackBuddyPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .bookstackBuddy,
            displayName: "Bookstack Buddy",
            category: .workspacePets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .workspace
        )
    }
}
