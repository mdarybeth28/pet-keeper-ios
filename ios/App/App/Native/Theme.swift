import SwiftUI

/// Pet Keeper's brand colors, taken from the web app's own palette
/// (yourpetkeeper.com's CSS variables) so the app and the website
/// wear the same dress: cream page, white cards, leaf green buttons,
/// soft amber warnings. The icon's sage and peach ride along.
enum Theme {
    static let page = Color(red: 0.980, green: 0.965, blue: 0.937)      // #FAF6EF
    static let ink = Color(red: 0.169, green: 0.169, blue: 0.149)       // #2B2B26
    static let muted = Color(red: 0.435, green: 0.416, blue: 0.369)     // #6F6A5E
    static let line = Color(red: 0.890, green: 0.867, blue: 0.816)      // #E3DDD0
    static let green = Color(red: 0.184, green: 0.490, blue: 0.310)     // #2F7D4F
    static let greenDark = Color(red: 0.145, green: 0.420, blue: 0.259) // #256B42
    static let greenSoft = Color(red: 0.906, green: 0.949, blue: 0.918) // #E7F2EA
    static let amberSoft = Color(red: 0.984, green: 0.953, blue: 0.851) // #FBF3D9
    static let warnSoft = Color(red: 0.984, green: 0.918, blue: 0.910)  // #FBEAE8
    static let sage = Color(red: 0.678, green: 0.761, blue: 0.635)      // #ADC2A2
    static let peach = Color(red: 0.953, green: 0.620, blue: 0.482)     // #F39E7B
}

/// The web app's green button, natively: leaf green, white words,
/// rounded corners.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.green, in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

/// The web app's quiet second button: white with a green outline.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.greenDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.green, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
