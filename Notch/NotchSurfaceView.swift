import SwiftUI

/// Everything drawn behind the notch content, in the notch shape: shadow and background.
/// Solid themes: black fill + artwork/fallback colour (unchanged since v0.2).
/// Liquid Glass themes: real glass on macOS 26+, a blurred material on macOS 14/15.
/// Used by the notch itself and by the live preview in Settings › Appearance.
struct NotchSurfaceView: View {
    let shape: NotchShape
    let theme: Theme
    let isOpen: Bool
    /// The cover's dominant colour while music is active, nil otherwise.
    let artwork: RGBColor?

    var body: some View {
        if theme.isGlass {
            glassSurface
        } else {
            solidSurface
        }
    }

    // MARK: Solid

    private var solidSurface: some View {
        ZStack {
            shape
                .fill(Color.black)
                .shadow(color: theme.shadowColor.opacity(isOpen && theme.shadowEnabled ? theme.shadowOpacity : 0),
                        radius: theme.shadowRadius, y: theme.shadowYOffset)
            NotchBackgroundView(theme: theme, color: solidBackground)
                .clipShape(shape)
                .opacity(isOpen ? 1 : 0)   // closed is always pure black
        }
    }

    private var solidBackground: Color? {
        guard theme.useArtworkColor, let artwork else { return nil }
        return artwork.scaled(theme.artworkIntensity).darkened(toMaxLuminance: theme.maxBackgroundLuminance).color
    }

    // MARK: Glass

    /// Glass shows when open, and when closed only if the theme asks for it.
    private var glassShown: Bool { isOpen || theme.glassWhenClosed }

    private var glassSurface: some View {
        let tint = theme.glassTint(artwork: artwork)
        return ZStack {
            // The theme's shadow, cut out under the shape so it doesn't darken the glass.
            OuterShadow(shape: shape, theme: theme)
                .opacity(isOpen && theme.shadowEnabled ? 1 : 0)
            ZStack {
                if #available(macOS 26, *), GlassSupport.isFullGlassAvailable {
                    LiquidGlassSurface(shape: shape, glass: theme.glass())
                } else {
                    shape.fill(.ultraThinMaterial)   // macOS 14/15 fallback
                }
                // Legibility layer: keeps white text readable over bright windows and wallpapers.
                shape.fill(Color.black.opacity(theme.glassDimming))
                // Tint (custom colour or artwork colour) as our own layer, above the dimming so the
                // dark layer doesn't swallow it. The system's Glass.tint was barely visible in the
                // notch (dark look + dimming) and depends on the variant, so it isn't used.
                if let tint { shape.fill(tint) }
            }
            .opacity(glassShown ? theme.glassLayerOpacity : 0)
            // Closed without glass: black like the physical notch, fading into the glass as it opens.
            shape.fill(Color.black)
                .opacity(glassShown ? 0 : 1)
        }
    }
}

/// Liquid Glass in the notch shape (macOS 26). The glass sits in a GlassEffectContainer with a
/// stable glassEffectID, and its shape is animated frame by frame with the open/close springs,
/// so the glass stretches and flows into the new shape instead of cross-fading.
@available(macOS 26, *)
private struct LiquidGlassSurface: View {
    let shape: NotchShape
    let glass: Glass
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer {
            Color.clear
                .modifier(AnimatedGlassShape(shape: shape, glass: glass))
                .glassEffectID("notch", in: namespace)
        }
    }
}

/// Re-applies the glass on every animation frame with the in-between shape. (Passing the shape
/// straight to glassEffect isn't guaranteed to interpolate it; this keeps the glass exactly on
/// the shape the content is clipped to.)
@available(macOS 26, *)
private struct AnimatedGlassShape: ViewModifier, Animatable {
    var shape: NotchShape
    let glass: Glass

    nonisolated var animatableData: NotchShape.AnimatableData {
        get { shape.animatableData }
        set { shape.animatableData = newValue }
    }

    func body(content: Content) -> some View {
        content.glassEffect(glass, in: shape)
    }
}


/// The theme's shadow drawn only outside the shape (a see-through surface would show it inside).
private struct OuterShadow: View {
    let shape: NotchShape
    let theme: Theme

    var body: some View {
        shape
            .fill(Color.black)
            .shadow(color: theme.shadowColor.opacity(theme.shadowOpacity), radius: theme.shadowRadius, y: theme.shadowYOffset)
            .mask {
                Rectangle()
                    .overlay { shape.fill(Color.black).blendMode(.destinationOut) }
                    .compositingGroup()
            }
    }
}
