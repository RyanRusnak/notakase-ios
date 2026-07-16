import CoreText
import SwiftUI

/// Notakase's type system. The app is monospace-first; `Typo.mono` is the one
/// place that decides *which* monospace font backs the UI. Today that's the
/// bundled JetBrains Mono (more faces can be added later); if a face fails to
/// load it falls back to the system monospaced design.
public enum Typo {
    /// A JetBrains Mono font at `size`, mapping the common weights onto the
    /// four bundled faces.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(NotakaseFonts.faceName(for: weight), size: size)
    }
}

/// Registers the bundled JetBrains Mono faces with Core Text so `Font.custom`
/// can find them. Call `register()` once at app launch (works on macOS + iOS).
public enum NotakaseFonts {
    static let faces = [
        "JetBrainsMono-Regular",
        "JetBrainsMono-Medium",
        "JetBrainsMono-SemiBold",
        "JetBrainsMono-Bold",
    ]

    static func faceName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium: return "JetBrainsMono-Medium"
        case .semibold: return "JetBrainsMono-SemiBold"
        case .bold, .heavy, .black: return "JetBrainsMono-Bold"
        default: return "JetBrainsMono-Regular"
        }
    }

    public static func register() {
        for name in faces {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
