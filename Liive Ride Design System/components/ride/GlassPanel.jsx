import React from "react";

/**
 * Liive Ride — GlassPanel
 * A frosted-glass material panel that floats over the live map (mirrors
 * SwiftUI .ultraThinMaterial / .thinMaterial). Use for HUD chips, the voice
 * pill, and floating info.
 */
export function GlassPanel({
  children,
  material = "regular",
  radius = "var(--radius-lg)",
  padding = 14,
  style,
  ...rest
}) {
  const bg = {
    thin: "var(--material-thin)",
    regular: "var(--material-regular)",
    thick: "var(--material-thick)",
  }[material];
  const blur = {
    thin: "var(--blur-thin)",
    regular: "var(--blur-regular)",
    thick: "var(--blur-thick)",
  }[material];
  return (
    <div
      style={{
        background: bg,
        WebkitBackdropFilter: blur,
        backdropFilter: blur,
        borderRadius: radius,
        padding,
        border: "0.5px solid var(--border-strong)",
        boxShadow: "var(--shadow-hud)",
        ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}
