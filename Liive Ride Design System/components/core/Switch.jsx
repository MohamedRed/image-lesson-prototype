import React from "react";

/**
 * Liive Ride — Switch
 * The iOS toggle. Green when on (system green), grey track when off.
 */
export function Switch({ checked = false, onChange, disabled = false, style, ...rest }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => !disabled && onChange && onChange(!checked)}
      style={{
        width: 51,
        height: 31,
        flex: "none",
        borderRadius: "var(--radius-full)",
        border: "none",
        padding: 2,
        background: checked ? "var(--success)" : "var(--fill)",
        cursor: disabled ? "default" : "pointer",
        opacity: disabled ? 0.5 : 1,
        transition: "background var(--dur-base) var(--ease-out)",
        WebkitTapHighlightColor: "transparent",
        display: "inline-flex",
        ...style,
      }}
      {...rest}
    >
      <span
        style={{
          width: 27,
          height: 27,
          borderRadius: "50%",
          background: "#fff",
          boxShadow: "0 2px 4px rgba(0,0,0,0.25)",
          transform: checked ? "translateX(20px)" : "translateX(0)",
          transition: "transform var(--dur-base) var(--ease-out)",
        }}
      />
    </button>
  );
}
