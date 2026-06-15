import React from "react";

/**
 * Liive Ride — Button
 * The iOS action button. Filled accent for primary actions, tinted/gray for
 * secondary, plain for inline links, destructive for cancel/emergency.
 * Presses dim + shrink slightly (the native iOS feel).
 */
export function Button({
  children,
  variant = "primary",
  size = "md",
  shape = "rounded",
  fullWidth = false,
  disabled = false,
  loading = false,
  icon = null,
  iconRight = null,
  onClick,
  style,
  ...rest
}) {
  const [pressed, setPressed] = React.useState(false);

  const heights = { sm: 32, md: 44, lg: 50 };
  const fonts = { sm: 15, md: 17, lg: 17 };
  const pads = { sm: "0 14px", md: "0 18px", lg: "0 22px" };

  const palettes = {
    primary: { bg: "var(--accent)", color: "var(--on-accent)", bgPressed: "var(--accent-pressed)" },
    secondary: { bg: "var(--fill)", color: "var(--text)", bgPressed: "var(--fill-secondary)" },
    tinted: { bg: "var(--accent-tint)", color: "var(--accent)", bgPressed: "var(--accent-tint)" },
    plain: { bg: "transparent", color: "var(--accent)", bgPressed: "transparent" },
    destructive: { bg: "var(--danger)", color: "#fff", bgPressed: "var(--danger)" },
    "destructive-plain": { bg: "transparent", color: "var(--danger)", bgPressed: "transparent" },
  };
  const p = palettes[variant] || palettes.primary;

  return (
    <button
      type="button"
      disabled={disabled || loading}
      onClick={onClick}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
      style={{
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 8,
        width: fullWidth ? "100%" : "auto",
        height: heights[size],
        padding: pads[size],
        border: "none",
        borderRadius: shape === "capsule" ? "var(--radius-full)" : "var(--radius-md)",
        background: pressed ? p.bgPressed : p.bg,
        color: p.color,
        fontFamily: "var(--font-sans)",
        fontSize: fonts[size],
        fontWeight: variant === "plain" || variant === "destructive-plain" ? 400 : 600,
        letterSpacing: "-0.4px",
        cursor: disabled || loading ? "default" : "pointer",
        opacity: disabled ? 0.4 : pressed ? (variant === "plain" || variant === "tinted" || variant === "destructive-plain" ? 0.5 : 0.85) : 1,
        transform: pressed && !disabled ? "scale(0.97)" : "scale(1)",
        transition: "transform var(--dur-fast) var(--ease-out), opacity var(--dur-fast), background var(--dur-fast)",
        WebkitTapHighlightColor: "transparent",
        userSelect: "none",
        ...style,
      }}
      {...rest}
    >
      {loading ? (
        <span
          style={{
            width: 18, height: 18, borderRadius: "50%",
            border: "2px solid currentColor", borderTopColor: "transparent",
            display: "inline-block", animation: "liive-spin 0.7s linear infinite",
          }}
        />
      ) : (
        <>
          {icon}
          {children}
          {iconRight}
        </>
      )}
      <style>{"@keyframes liive-spin{to{transform:rotate(360deg)}}"}</style>
    </button>
  );
}
