import React from "react";

/**
 * Liive Ride — MapMarker
 * A map pin/marker. "car" is the driver glyph (accent), "origin" the red
 * start dot, "destination" the pin, "transfer" the orange swap point.
 * Renders a teardrop pin or a floating dot depending on `kind`.
 */
export function MapMarker({ kind = "car", label = null, style, ...rest }) {
  const cfg = {
    car: { color: "var(--accent)", icon: "car", shape: "disc" },
    origin: { color: "var(--success)", icon: "navigation", shape: "dot" },
    destination: { color: "var(--danger)", icon: "map-pin", shape: "pin" },
    transfer: { color: "var(--warning)", icon: "arrow-left-right", shape: "disc" },
  }[kind] || {};

  const glyph = (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      {cfg.icon === "car" && (<><path d="M5 17a2 2 0 1 0 4 0M15 17a2 2 0 1 0 4 0"/><path d="M3 13l2-5a2 2 0 0 1 2-1h10a2 2 0 0 1 2 1l2 5v4H3z"/></>)}
      {cfg.icon === "navigation" && (<polygon points="3 11 22 2 13 21 11 13 3 11"/>)}
      {cfg.icon === "map-pin" && (<><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0z"/><circle cx="12" cy="10" r="3"/></>)}
      {cfg.icon === "arrow-left-right" && (<><path d="M8 3 4 7l4 4"/><path d="M4 7h16"/><path d="m16 21 4-4-4-4"/><path d="M20 17H4"/></>)}
    </svg>
  );

  if (cfg.shape === "dot") {
    return (
      <span style={{ display: "inline-flex", flexDirection: "column", alignItems: "center", gap: 4, ...style }} {...rest}>
        <span style={{ width: 18, height: 18, borderRadius: "50%", background: cfg.color, border: "3px solid #fff", boxShadow: "var(--shadow-pin)" }} />
        {label && <Tag color={cfg.color}>{label}</Tag>}
      </span>
    );
  }

  // disc + pin both render a circular badge with a pointer tail
  return (
    <span style={{ display: "inline-flex", flexDirection: "column", alignItems: "center", gap: 4, ...style }} {...rest}>
      <span style={{ position: "relative", display: "inline-flex" }}>
        <span
          style={{
            width: 38, height: 38, borderRadius: "50%", background: cfg.color,
            display: "inline-flex", alignItems: "center", justifyContent: "center",
            border: "2.5px solid #fff", boxShadow: "var(--shadow-pin)",
          }}
        >
          {glyph}
        </span>
        <span
          style={{
            position: "absolute", bottom: -5, left: "50%", width: 12, height: 12,
            background: cfg.color, transform: "translateX(-50%) rotate(45deg)",
            borderRight: "2.5px solid #fff", borderBottom: "2.5px solid #fff",
          }}
        />
      </span>
      {label && <Tag color={cfg.color}>{label}</Tag>}
    </span>
  );
}

function Tag({ children, color }) {
  return (
    <span
      style={{
        background: "var(--surface)", color: "var(--text)",
        fontFamily: "var(--font-sans)", fontSize: 12, fontWeight: 600,
        padding: "2px 8px", borderRadius: "var(--radius-full)",
        boxShadow: "var(--shadow-sm)", borderBottom: `2px solid ${color}`,
        whiteSpace: "nowrap",
      }}
    >
      {children}
    </span>
  );
}
