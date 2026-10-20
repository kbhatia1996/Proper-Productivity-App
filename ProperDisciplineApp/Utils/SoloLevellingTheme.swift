import SwiftUI
import UIKit

/// Solo Levelling aesthetic color palette (dark, dramatic, fantasy-like)
/// Inspired by Solo Levelling anime visual style
struct SoloLevellingTheme {
    // Primary colors
    static let darkPurple = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.08, blue: 0.25, alpha: 1)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    })
    static let brightGold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1)
            : UIColor(red: 0.62, green: 0.42, blue: 0.0, alpha: 1)
    })
    static let deepBlack = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
            : UIColor(red: 0.96, green: 0.95, blue: 0.98, alpha: 1)
    })
    static let silverWhite = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.92, green: 0.92, blue: 0.95, alpha: 1)
            : UIColor(red: 0.18, green: 0.17, blue: 0.21, alpha: 1)
    })
    
    // Progress tracking colors
    static let progressGold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.92, blue: 0.23, alpha: 1)
            : UIColor(red: 0.62, green: 0.42, blue: 0.0, alpha: 1)
    })
    static let progressAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.58, blue: 0.16, alpha: 1)
            : UIColor(red: 0.62, green: 0.29, blue: 0.0, alpha: 1)
    })
    static let calendarPersonalAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1)
            : UIColor(red: 0.0, green: 0.38, blue: 0.55, alpha: 1)
    })
    static let calendarSharedAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1)
            : UIColor(red: 0.62, green: 0.29, blue: 0.0, alpha: 1)
    })

    // Status colors
    static let successGreen = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1)
            : UIColor(red: 0.08, green: 0.42, blue: 0.2, alpha: 1)
    })
    static let warningOrange = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1)
            : UIColor(red: 0.62, green: 0.29, blue: 0.0, alpha: 1)
    })
    static let errorRed = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1)
            : UIColor(red: 0.65, green: 0.12, blue: 0.12, alpha: 1)
    })
    
    // Fonts
    static let displayFont = "System"  // Replace with custom font name if available
    static let bodyFont = "System"
    
    // Sizes
    static let cornerRadius: CGFloat = 12
    static let shadowRadius: CGFloat = 8
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
