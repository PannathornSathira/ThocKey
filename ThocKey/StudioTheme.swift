import SwiftUI

public enum StudioTheme {
    public static let canvas = adaptive(light: 0xF7F2EA, dark: 0x211A17)
    public static let sidebar = adaptive(light: 0xEFE6DA, dark: 0x2A211D)
    public static let surface = adaptive(light: 0xFCF9F4, dark: 0x332823)
    public static let surfaceMuted = adaptive(light: 0xEEE3D5, dark: 0x3B2E28)
    public static let espresso = adaptive(light: 0x30251F, dark: 0xF4ECE3)
    public static let secondaryText = adaptive(light: 0x77685E, dark: 0xBFAFA4)
    public static let walnut = adaptive(light: 0x8A5638, dark: 0xC4865F)
    public static let walnutPressed = adaptive(light: 0x6E422C, dark: 0xA96E4B)
    public static let caramel = adaptive(light: 0xB9784B, dark: 0xD89B72)
    public static let moss = adaptive(light: 0x667342, dark: 0x96A96A)
    public static let separator = adaptive(light: 0xDCCDBE, dark: 0x56443B)
    public static let danger = adaptive(light: 0xA94A3F, dark: 0xE07A6D)

    public enum Spacing {
        public static let xSmall: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let regular: CGFloat = 16
        public static let large: CGFloat = 24
        public static let xLarge: CGFloat = 32
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

public enum StudioTab: String, CaseIterable, Identifiable {
    case packs = "Sounds & Packs"
    case keyMapping = "Key Mappings"
    case library = "Sound Library"
    case settings = "Settings"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .packs: "waveform"
        case .keyMapping: "keyboard"
        case .library: "waveform.badge.magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

public struct StudioSectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    public init(title: String, subtitle: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .top, spacing: StudioTheme.Spacing.large) {
            VStack(alignment: .leading, spacing: StudioTheme.Spacing.xSmall) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioTheme.espresso)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(StudioTheme.secondaryText)
            }
            Spacer(minLength: StudioTheme.Spacing.large)
            trailing()
        }
    }
}

public extension StudioSectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

public struct StudioSurface<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        content
            .padding(StudioTheme.Spacing.regular)
            .background(StudioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(StudioTheme.separator.opacity(0.8), lineWidth: 1)
            }
    }
}

public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, StudioTheme.Spacing.regular)
            .padding(.vertical, 9)
            .background(configuration.isPressed ? StudioTheme.walnutPressed : StudioTheme.walnut)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(StudioTheme.espresso)
            .padding(.horizontal, StudioTheme.Spacing.medium)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? StudioTheme.surfaceMuted : StudioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(StudioTheme.separator, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

public struct StudioSidebar: View {
    @Binding var selection: StudioTab
    let isAccessibilityEnabled: Bool

    public init(selection: Binding<StudioTab>, isAccessibilityEnabled: Bool) {
        _selection = selection
        self.isAccessibilityEnabled = isAccessibilityEnabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .center, spacing: StudioTheme.Spacing.small) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text("ThocKey Studio")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioTheme.espresso)
                Text("Mechanical sounds,\nmade yours.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundStyle(StudioTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, StudioTheme.Spacing.large)
            .padding(.bottom, StudioTheme.Spacing.xLarge)

            VStack(spacing: StudioTheme.Spacing.small) {
                ForEach(StudioTab.allCases) { tab in
                    Button {
                        selection = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.system(size: 14, weight: selection == tab ? .semibold : .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, StudioTheme.Spacing.medium)
                            .padding(.vertical, 11)
                            .foregroundStyle(selection == tab ? Color.white : StudioTheme.espresso)
                            .background(selection == tab ? StudioTheme.walnut : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.rawValue)
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal, StudioTheme.Spacing.medium)

            Spacer()

            Divider().overlay(StudioTheme.separator)
                .padding(.horizontal, StudioTheme.Spacing.regular)
            HStack(spacing: StudioTheme.Spacing.small) {
                Image(systemName: isAccessibilityEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isAccessibilityEnabled ? StudioTheme.moss : StudioTheme.caramel)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Permissions")
                        .font(.system(size: 12, weight: .semibold))
                    Text(isAccessibilityEnabled ? "Accessibility active" : "Action required")
                        .font(.system(size: 10))
                        .foregroundStyle(StudioTheme.secondaryText)
                }
            }
            .accessibilityElement(children: .contain)
            .foregroundStyle(StudioTheme.espresso)
            .padding(StudioTheme.Spacing.regular)
        }
        .frame(width: 220)
        .background(StudioTheme.sidebar)
    }
}
