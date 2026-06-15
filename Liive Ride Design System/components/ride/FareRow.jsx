import React from "react";

/**
 * Liive Ride — FareRow
 * One line of the Stripe fare breakdown. The total row is emphasised.
 */
export function FareRow({ label, amount, total = false, muted = false, style, ...rest }) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "baseline",
        justifyContent: "space-between",
        gap: 12,
        padding: total ? "12px 0 0" : "6px 0",
        ...style,
      }}
      {...rest}
    >
      <span
        style={{
          fontFamily: "var(--font-sans)",
          fontSize: total ? 17 : 15,
          fontWeight: total ? 600 : 400,
          color: total ? "var(--text)" : muted ? "var(--text-tertiary)" : "var(--text-secondary)",
        }}
      >
        {label}
      </span>
      <span
        className="tnum"
        style={{
          fontFamily: "var(--font-sans)",
          fontSize: total ? 17 : 15,
          fontWeight: total ? 700 : 500,
          color: total ? "var(--text)" : "var(--text)",
        }}
      >
        {amount}
      </span>
    </div>
  );
}
