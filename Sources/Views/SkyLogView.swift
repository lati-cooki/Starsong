import SwiftUI

/// The constellations you've kept. Tap one to hang it back in the sky.
struct SkyLogView: View {
    let log: SkyLog
    let onRestore: (SavedSky) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if log.isEmpty { empty } else { list }
            }
            .navigationTitle("Kept skies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var list: some View {
        List {
            ForEach(log.entries) { sky in
                Button {
                    onRestore(sky)
                    dismiss()
                } label: {
                    row(sky)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.white.opacity(0.04))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { log.remove(sky) } label: {
                        Label("Forget", systemImage: "trash")
                    }
                }
                .contextMenu {
                    ShareLink(item: sky, preview: SharePreview(sky.name)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { log.remove(sky) } label: {
                        Label("Forget", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(skyBackground)
    }

    private func row(_ sky: SavedSky) -> some View {
        HStack(spacing: 14) {
            ConstellationThumbnail(sky: sky)
                .frame(width: 62, height: 62)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(sky.name)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.gold)
                Text(sky.myth)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .lineLimit(2)
                Text(sky.lines.count > 1
                     ? "\(sky.lines.count) lines · \(sky.noteCount) notes · \(sky.keptAt.formatted(date: .abbreviated, time: .omitted))"
                     : "\(sky.noteCount) stars · \(sky.keptAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.ink.opacity(0.4))
            }
            Spacer(minLength: 0)
            HearButton { SkyModel.preview(sky.constellations, tuning: sky.tuning) }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Hangs this constellation back in the sky")
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundStyle(Palette.gold.opacity(0.7))
            Text("Nothing kept yet")
                .font(.system(size: 19, weight: .semibold, design: .serif))
            Text("Draw a constellation, then keep it.\nThe sky it was drawn on comes back with it.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink.opacity(0.6))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(skyBackground)
    }

    private var skyBackground: some View {
        LinearGradient(colors: [Palette.nightTop, Palette.nightBottom],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}
