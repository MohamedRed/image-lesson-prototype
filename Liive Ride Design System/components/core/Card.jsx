import React from "react";

/**
 * Liive Ride — Card
 * The base filled surface: 12–16px radius, soft shadow, no border in dark
 * mode. An accent stroke marks an *active* card (e.g. selected ride option).
 */
export function Card({
  children,
  padding = 16,
  radius = "var(--radius-lg)",
  active = false,
  raised = false,
  onClick,
  style,
  ...rest
}) {
  const interactive = !!onClick;
  return (
    <div
      onClick={onClick}
      style={{
        background: raised ? "var(--surface-raised)" : "var(--surface)",
        borderRadius: radius,
        padding,
        boxShadow: active ? "none" : "var(--shadow-card)",
        border: active ? "1.5px solid var(--accent)" : "1.5px solid transparent",
        cursor: interactive ? "pointer" : "default",
        transition: "border-color var(--dur-fast), transform var(--dur-fast) var(--ease-out)",
        ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}
