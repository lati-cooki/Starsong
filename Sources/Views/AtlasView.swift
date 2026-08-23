import SwiftUI

/// Real constellations, ready to be laid over a sky of invented ones.
struct AtlasView: View {
    let onPlace: (Figure) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Atlas.figures) { figure in
                Button {
                    onPlace(figure)
                    dismiss()
                } label: {
                    row(figure)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.white.opacity(0.04))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Palette.nightTop, Palette.nightBottom],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Real constellations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ figure: Figure) -> some View {
        let placed = figure.placedStars()
        return HStack(spacing: 14) {
            ConstellationThumbnail(constellations: [placed])
                .frame(width: 62, height: 62)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(figure.name)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.gold)
                Text(figure.note)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .lineLimit(2)
                Text(figure.stars.count == figure.walk.count
                     ? "\(figure.stars.count) stars"
                     : "\(figure.stars.count) stars · \(figure.walk.count) notes")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.ink.opacity(0.4))
            }
            Spacer(minLength: 0)
            HearButton { SkyModel.preview([figure.walk.map { placed[$0] }]) }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Draws \(figure.name) in the sky")
    }
}

/// Plays a melody in place, without leaving the list.
struct HearButton: View {
    let play: () -> Void

    var body: some View {
        Button(action: play) {
            Image(systemName: "play.circle")
                .font(.system(size: 24))
                .foregroundStyle(Palette.gold.opacity(0.8))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hear it")
    }
}
