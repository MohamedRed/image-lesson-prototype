import React from "react";

/**
 * Liive Ride — Avatar
 * Driver / rider avatar. Image when available, else initials on a tinted
 * disc. Optional accent ring marks the active speaker on the voice channel.
 */
export function Avatar({
  name = "",
  src = null,
  size = 48,
  ring = false,
  ringColor = "var(--accent)",
  style,
  ...rest
}) {
  const initials = name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join("");

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
        background: "var(--fill)",
        color: "var(--text)",
        fontFamily: "var(--font-sans)",
        fontWeight: 600,
        fontSize: size * 0.4,
        overflow: "hidden",
        boxShadow: ring ? `0 0 0 2.5px var(--surface), 0 0 0 5px ${ringColor}` : "none",
        ...style,
      }}
      {...rest}
    >
      {src ? (
        <img src={src} alt={name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      ) : (
        initials || "?"
      )}
    </span>
  );
}
