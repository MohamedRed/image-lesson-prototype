import React from "react";

/**
 * Liive Ride — Badge
 * Small capsule for status & metadata. Color variants map to the semantic
 * palette; an optional leading dot reads as a live status indicator.
 */
export function Badge({
  children,
  color = "neutral",
  solid = false,
  dot = false,
  icon = null,
  style,
  ...rest
}) {
  const map = {
    neutral: { fg: "var(--text-secondary)", tint: "var(--fill-tertiary)", solid: "var(--fill)" },
    accent: { fg: "var(--accent)", tint: "var(--accent-tint)", solid: "var(--accent)" },
    success: { fg: "var(--success)", tint: "var(--success-tint)", solid: "var(--success)" },
    warning: { fg: "var(--warning)", tint: "var(--warning-tint)", solid: "var(--warning)" },
    danger: { fg: "var(--danger)", tint: "var(--danger-tint)", solid: "var(--danger)" },
    info: { fg: "var(--info)", tint: "var(--info-tint)", solid: "var(--info)" },
  };
  const c = map[color] || map.neutral;

  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 5,
        padding: "3px 9px",
        borderRadius: "var(--radius-full)",
        background: solid ? c.solid : c.tint,
        color: solid ? (color === "warning" || color === "info" ? "#000" : "#fff") : c.fg,
        fontFamily: "var(--font-sans)",
        fontSize: 12,
        fontWeight: 600,
        letterSpacing: 0.1,
        lineHeight: 1.3,
        whiteSpace: "nowrap",
        ...style,
      }}
      {...rest}
    >
      {dot && (
        <span
          style={{
            width: 7, height: 7, borderRadius: "50%",
            background: solid ? "currentColor" : c.fg,
            flex: "none",
          }}
        />
      )}
      {icon}
      {children}
    </span>
  );
}
