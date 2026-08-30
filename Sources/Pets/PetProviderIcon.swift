import AppKit
import PetsCore
import SwiftUI

struct PetProviderIcon: View {
    @Environment(\.colorScheme) private var colorScheme

    let provider: PetTrackingProvider
    let isDisabled: Bool
    let size: CGFloat

    init(
        provider: PetTrackingProvider,
        isDisabled: Bool = false,
        size: CGFloat = 24
    ) {
        self.provider = provider
        self.isDisabled = isDisabled
        self.size = size
    }

    var body: some View {
        Group {
            if let image = resourceImage {
                if provider == .claudeCode {
                    Image(nsImage: image)
                        .resizable()
                        .renderingMode(.template)
                        .interpolation(.high)
                        .foregroundStyle(isDisabled ? Color.secondary : claudeOrange)
                } else {
                    Image(nsImage: image)
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.high)
                        .saturation(isDisabled ? 0 : 1)
                        .opacity(isDisabled ? 0.45 : 1)
                }
            } else {
                Image(systemName: provider.systemImageName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(isDisabled ? .secondary : .primary)
            }
        }
        .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var resourceImage: NSImage? {
        guard let url = PetProviderIconResourceLocator.url(
            for: provider,
            appearance: colorScheme == .dark ? .dark : .light
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private var claudeOrange: Color {
        Color(red: 0.86, green: 0.47, blue: 0.34)
    }
}
