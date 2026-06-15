import React from "react";

/**
 * Liive Ride — Stepper
 * The iOS −/+ stepper for small integer counts (passengers, luggage, pets).
 */
export function Stepper({
  value = 0,
  min = 0,
  max = 99,
  onChange,
  style,
  ...rest
}) {
  const set = (next) => {
    const v = Math.max(min, Math.min(max, next));
    if (v !== value && onChange) onChange(v);
  };
  const btn = (label, onClick, disabled) => (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      style={{
        width: 44,
        height: 32,
        border: "none",
        background: "transparent",
        color: disabled ? "var(--text-quaternary)" : "var(--text)",
        fontSize: 20,
        fontWeight: 400,
        cursor: disabled ? "default" : "pointer",
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        WebkitTapHighlightColor: "transparent",
      }}
    >
      {label}
    </button>
  );
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        background: "var(--fill-tertiary)",
        borderRadius: "var(--radius-sm)",
        ...style,
      }}
      {...rest}
    >
      {btn("−", () => set(value - 1), value <= min)}
      <span
        style={{ width: 1, height: 18, background: "var(--separator)", flex: "none" }}
      />
      {btn("+", () => set(value + 1), value >= max)}
    </span>
  );
}
