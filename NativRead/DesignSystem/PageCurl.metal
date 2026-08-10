#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

/// The reader's page curl, ported from its WebGL fragment shader
/// (`ReaderScripts.swift`) so the onboarding preview bends paper the same way
/// the book does.
///
/// The rule that matters is the underside. UIKit's own `.pageCurl` renders it
/// as a mirror of the front under a strong specular, which flares to white and
/// is unreadable over a dark page. The reader instead mixes the page's own ink
/// almost entirely into the theme's paper colour, so the back of a turning
/// sheet is paper with the text faintly bleeding through, at any brightness.
[[ stitchable ]] half4 pageCurl(
    float2 position,
    SwiftUI::Layer layer,
    float width,
    float progress,
    half4 paper
) {
    // The sheet is anchored at the spine (x = 0) and cannot stretch. Pulling
    // its free edge left from `width` to `edge` puts the crease halfway
    // between the two, and the flap folded back over the page spans
    // `edge`…`crease`. At progress 1 the whole sheet has passed the spine.
    float travel = 2.0 * width * progress;
    float edge = width - travel;
    float crease = width - travel * 0.5;
    // At rest the crease sits on the right edge of the page, so every shading
    // term below would darken that edge permanently. Nothing is shaded until
    // the fold has actually lifted.
    float lifted = saturate(progress * 12.0);

    // Past the crease the sheet is gone; the next page shows through.
    if (position.x > crease) {
        return half4(0.0h);
    }

    if (position.x >= edge) {
        // Underside of the flap: the same paper seen from behind, so the
        // source pixel is mirrored across the crease. The geometry supplies
        // the mirroring — do not also flip the sample, which would cancel it
        // and render the text readable and merely shifted.
        float2 source = float2(2.0 * crease - position.x, position.y);
        if (source.x > width) {
            return half4(0.0h);
        }
        half4 ink = layer.sample(source);
        float lift = saturate((crease - position.x) / max(crease - edge, 1.0));
        ink.rgb = mix(ink.rgb, paper.rgb, 0.9h);
        ink.rgb *= 1.0h - 0.06h * half(lift);
        // The inside of the bend, deepest at the crease and fading across the
        // fold's radius. Without this the flap is a flat rectangle with a hard
        // edge, which reads as a straight cut rather than bent paper.
        float t = (crease - position.x) / 20.0;
        float bend = exp(-t * t) * lifted;
        ink.rgb *= 1.0h - 0.26h * half(bend);
        return ink;
    }

    // The flat page still lying down. Only a contact shadow where the lifted
    // flap meets it — spreading this across a third of the card washed warm
    // paper grey in the light theme.
    half4 ink = layer.sample(position);
    float shadow = saturate(1.0 - (edge - position.x) / 22.0) * lifted;
    ink.rgb *= 1.0h - 0.20h * half(shadow * shadow);
    return ink;
}
