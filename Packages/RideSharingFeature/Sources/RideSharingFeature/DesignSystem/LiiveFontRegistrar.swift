import CoreText
import Foundation

public enum LiiveFontRegistrar {
    private static var didRegister = false

    public static func registerBundledFonts() {
        guard !didRegister else { return }
        didRegister = true

        guard let fontURL = Bundle.module.url(
            forResource: "schibsted_grotesk_variable",
            withExtension: "ttf",
            subdirectory: "Fonts"
        ) else {
            assertionFailure("Missing bundled Schibsted Grotesk font resource.")
            return
        }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
    }
}
