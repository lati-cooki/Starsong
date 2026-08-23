import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// The little star card you get when you share a constellation.
struct ShareCard: View {
    let sky: SavedSky

    var body: some View {
        VStack(spacing: 16) {
            ConstellationThumbnail(sky: sky, showsField: true, lineWidth: 2, nodeRadius: 5)
                .frame(width: 320, height: 320)

            Text(sky.name)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.gold)
                .multilineTextAlignment(.center)

            Text(sky.myth)
                .font(.system(size: 15))
                .foregroundStyle(Palette.ink.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Starsong")
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .tracking(1.6)
                .foregroundStyle(Palette.ink.opacity(0.4))
                .padding(.top, 4)
        }
        .padding(30)
        .frame(width: 380)
        .background(
            LinearGradient(colors: [Palette.nightTop, Palette.nightBottom],
                           startPoint: .top, endPoint: .bottom)
        )
        .environment(\.colorScheme, .dark)
    }
}

enum ShareCardRenderer {
    @MainActor
    static func png(for sky: SavedSky) -> Data? {
        let renderer = ImageRenderer(content: ShareCard(sky: sky))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage?.pngData()
    }
}

extension SavedSky: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { sky in
            await MainActor.run { ShareCardRenderer.png(for: sky) } ?? Data()
        }
        .suggestedFileName { sky in "\(sky.name).png" }
    }
}
