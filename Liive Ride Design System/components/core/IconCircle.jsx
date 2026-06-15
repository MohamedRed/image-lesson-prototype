import React from "react";

/**
 * Liive Ride — IconCircle
 * A tinted circular icon badge — the recurring "feature glyph" used on
 * feature cards, list rows and map callouts.
 */
export function IconCircle({
  children,
  color = "accent",
  size = 44,
  filled = false,
  style,
  ...rest
}) {
  const map = {
    accent: { fg: "var(--accent)", tint: "var(--accent-tint)", solid: "var(--accent)" },
    success: { fg: "var(--success)", tint: "var(--success-tint)", solid: "var(--success)" },
    warning: { fg: "var(--warning)", tint: "var(--warning-tint)", solid: "var(--warning)" },
    danger: { fg: "var(--danger)", tint: "var(--danger-tint)", solid: "var(--danger)" },
    info: { fg: "var(--info)", tint: "var(--info-tint)", solid: "var(--info)" },
    neutral: { fg: "var(--text-secondary)", tint: "var(--fill-tertiary)", solid: "var(--fill)" },
  };
  const c = map[color] || map.accent;
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        width: size,
        height: size,
        flex: "none",
        borderRadius: "50%",
        background: filled ? c.solid : c.tint,
        color: filled ? "#fff" : c.fg,
        ...style,
      }}
      {...rest}
    >
      {children}
    </span>
  );
}
