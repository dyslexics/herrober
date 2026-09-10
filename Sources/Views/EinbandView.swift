import SwiftUI

/// Der Einband füllt die verfügbare Bildschirmfläche; Doppeltipp und Pinch vergrößern Details.
struct EinbandView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: Settings

    var body: some View {
        NavigationStack {
            ZoomBild(image: image)
                .accessibilityLabel(T("about.cover"))
                .accessibilityHint(T("cover.zoom.hint"))
                .accessibilityIdentifier("cover.zoom")
                .background(Theme.bg)
                .navigationTitle(T("about.cover"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(T("common.close"), systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly)
                            .frame(minWidth: Theme.mindestTouch, minHeight: Theme.mindestTouch)
                            .accessibilityIdentifier("cover.close")
                    }
                }
        }
        .tint(Theme.akzent)
        .preferredColorScheme(settings.darstellung.scheme)
    }
}
