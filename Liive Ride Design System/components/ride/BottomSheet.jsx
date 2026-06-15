import React from "react";

/**
 * Liive Ride — BottomSheet
 * The iOS sheet that rises from the bottom over the map: rounded top, grabber
 * handle, opaque sheet surface. Static (non-draggable) presentation suitable
 * for mockups — render it inside a phone frame.
 */
export function BottomSheet({
  children,
  grabber = true,
  padding = 16,
  style,
  ...rest
}) {
  return (
    <div
      style={{
        background: "var(--surface-sheet)",
        borderTopLeftRadius: "var(--radius-3xl)",
        borderTopRightRadius: "var(--radius-3xl)",
        boxShadow: "var(--shadow-sheet)",
        padding: `${grabber ? 8 : padding}px ${padding}px calc(${padding}px + var(--safe-bottom))`,
        ...style,
      }}
      {...rest}
    >
      {grabber && (
        <div
          style={{
            width: 36,
            height: 5,
            borderRadius: "var(--radius-full)",
            background: "var(--fill)",
            margin: "0 auto 14px",
          }}
        />
      )}
      {children}
    </div>
  );
}
