import React from "react";

/**
 * Liive Ride — SegmentedControl
 * The iOS segmented control. Used for rider/driver mode, ride tiers, etc.
 * The selected segment is a raised pill that slides between options.
 */
export function SegmentedControl({
  options = [],
  value,
  onChange,
  style,
  ...rest
}) {
  const items = options.map((o) => (typeof o === "string" ? { label: o, value: o } : o));
  const idx = Math.max(0, items.findIndex((i) => i.value === value));

  return (
    <div
      style={{
        position: "relative",
        display: "grid",
        gridTemplateColumns: `repeat(${items.length}, 1fr)`,
        padding: 2,
        background: "var(--fill-tertiary)",
        borderRadius: "var(--radius-sm)",
        ...style,
      }}
      {...rest}
    >
      <span
        style={{
          position: "absolute",
          top: 2,
          bottom: 2,
          left: `calc(${(100 / items.length) * idx}% + 2px)`,
          width: `calc(${100 / items.length}% - 4px)`,
          background: "var(--surface-raised)",
          borderRadius: 7,
          boxShadow: "var(--shadow-sm)",
          transition: "left var(--dur-base) var(--ease-out)",
        }}
      />
      {items.map((it) => {
        const selected = it.value === value;
        return (
          <button
            key={it.value}
            type="button"
            onClick={() => onChange && onChange(it.value)}
            style={{
              position: "relative",
              zIndex: 1,
              background: "transparent",
              border: "none",
              padding: "7px 12px",
              fontFamily: "var(--font-sans)",
              fontSize: 14,
              fontWeight: selected ? 600 : 500,
              color: selected ? "var(--text)" : "var(--text-secondary)",
              cursor: "pointer",
              WebkitTapHighlightColor: "transparent",
              transition: "color var(--dur-fast)",
            }}
          >
            {it.label}
          </button>
        );
      })}
    </div>
  );
}
