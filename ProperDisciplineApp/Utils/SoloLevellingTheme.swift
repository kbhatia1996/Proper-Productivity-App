import SwiftUI

/// Solo Levelling color palette inspired by hunter aesthetic
struct SoloLevellingTheme {
    // Primary colors
    static let darkPurple = Color(red: 0.15, green: 0.08, blue: 0.25)
    static let brightGold = Color(red: 0.95, green: 0.78, blue: 0.2)
    static let deepBlack = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let silverWhite = Color(red: 0.92, green: 0.92, blue: 0.95)
    
    // Accent colors
    static let rankE = Color(red: 0.7, green: 0.7, blue: 0.7)   // Gray
    static let rankD = Color(red: 0.2, green: 0.6, blue: 1.0)   // Blue
    static let rankC = Color(red: 0.2, green: 1.0, blue: 0.6)   // Green
    static let rankB = Color(red: 1.0, green: 0.8, blue: 0.2)   // Gold
    static let rankA = Color(red: 1.0, green: 0.4, blue: 0.2)   // Red
    static let rankS = Color(red: 0.8, green: 0.2, blue: 1.0)   // Purple
    
    // Success/Failure
    static let successGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let warningOrange = Color(red: 1.0, green: 0.6, blue: 0.1)
    static let errorRed = Color(red: 1.0, green: 0.3, blue: 0.3)
    
    // Fonts
    static let displayFont = "System"  // Replace with custom font name if available
    static let bodyFont = "System"
    
    // Sizes
    static let cornerRadius: CGFloat = 12
    static let shadowRadius: CGFloat = 8
}

// MARK: - Color Extensions
extension Color {
    static func rankColor(for rank: String) -> Color {
        switch rank.uppercased() {
        case "E": return SoloLevellingTheme.rankE
        case "D": return SoloLevellingTheme.rankD
        case "C": return SoloLevellingTheme.rankC
        case "B": return SoloLevellingTheme.rankB
        case "A": return SoloLevellingTheme.rankA
        case "S": return SoloLevellingTheme.rankS
        default: return SoloLevellingTheme.rankE
        }
    }
}

// MARK: - Style Modifiers
struct ThemeButton: ViewModifier {
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary      // Gold on dark purple
        case secondary    // Silver outline
        case danger       // Red
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(SoloLevellingTheme.cornerRadius)
            .shadow(color: shadowColor, radius: SoloLevellingTheme.shadowRadius)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return SoloLevellingTheme.brightGold
        case .secondary: return .clear
        case .danger: return SoloLevellingTheme.errorRed
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return SoloLevellingTheme.deepBlack
        case .secondary: return SoloLevellingTheme.silverWhite
        case .danger: return .white
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary: return SoloLevellingTheme.brightGold.opacity(0.5)
        case .secondary: return .clear
        case .danger: return SoloLevellingTheme.errorRed.opacity(0.5)
        }
    }
}

extension View {
    func themeButton(_ style: ThemeButton.ButtonStyle) -> some View {
        modifier(ThemeButton(style: style))
    }
}

// MARK: - Card Style
struct ThemeCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(SoloLevellingTheme.darkPurple)
            .cornerRadius(SoloLevellingTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: SoloLevellingTheme.cornerRadius)
                    .stroke(SoloLevellingTheme.brightGold.opacity(0.3), lineWidth: 1)
            )
    }
}

extension View {
    func themeCard() -> some View {
        modifier(ThemeCard())
    }
}
