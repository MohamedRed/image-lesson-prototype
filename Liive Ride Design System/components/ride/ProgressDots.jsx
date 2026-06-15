import React from "react";

/**
 * Liive Ride — ProgressDots
 * Multi-leg journey progress. Numbered leg circles connected by transfer
 * links (a swap glyph). Completed legs go green, the current leg is accent,
 * upcoming legs are muted.
 */
export function ProgressDots({ legs = 2, current = 1, style, ...rest }) {
  const items = [];
  for (let n = 1; n <= legs; n++) {
    const completed = n < current;
    const active = n === current;
    const bg = completed ? "var(--success)" : active ? "var(--accent)" : "var(--fill)";
    const fg = completed || active ? "#fff" : "var(--text-tertiary)";
    items.push(
      <span key={`leg-${n}`} style={{ display: "inline-flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
        <span
          style={{
            width: 24, height: 24, borderRadius: "50%", background: bg,
            display: "inline-flex", alignItems: "center", justifyContent: "center",
            fontFamily: "var(--font-sans)", fontSize: 12, fontWeight: 700, color: fg,
          }}
        >
          {n}
        </span>
        <span style={{ fontFamily: "var(--font-sans)", fontSize: 11, color: "var(--text-secondary)" }}>
          Leg {n}
        </span>
      </span>
    );
    if (n < legs) {
      const passed = n < current;
      items.push(
        <span key={`tr-${n}`} style={{ flex: 1, display: "inline-flex", flexDirection: "column", alignItems: "center", gap: 3, marginBottom: 15, minWidth: 28 }}>
          <span style={{ height: 2, alignSelf: "stretch", background: passed ? "var(--success)" : "var(--fill)", borderRadius: 2 }} />
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={passed ? "var(--success)" : "var(--warning)"} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
            <path d="M8 3 4 7l4 4" /><path d="M4 7h16" /><path d="m16 21 4-4-4-4" /><path d="M20 17H4" />
          </svg>
        </span>
      );
    }
  }
  return (
    <div style={{ display: "flex", alignItems: "center", ...style }} {...rest}>
      {items}
    </div>
  );
}
