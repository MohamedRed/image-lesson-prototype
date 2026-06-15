import React from "react";

/**
 * Liive Ride — ListRow
 * The iOS grouped-list row: leading icon, title + optional subtitle, trailing
 * value / control / chevron. Tap feedback dims the row.
 */
export function ListRow({
  leading = null,
  title,
  subtitle = null,
  value = null,
  trailing = null,
  chevron = false,
  divider = true,
  onClick,
  style,
  ...rest
}) {
  const [pressed, setPressed] = React.useState(false);
  const interactive = !!onClick;
  return (
    <div
      onClick={onClick}
      onPointerDown={() => interactive && setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 12,
        minHeight: 44,
        padding: "10px 16px",
        background: pressed ? "var(--fill-quaternary)" : "transparent",
        boxShadow: divider ? "inset 0 -0.5px 0 var(--separator)" : "none",
        cursor: interactive ? "pointer" : "default",
        transition: "background var(--dur-fast)",
        WebkitTapHighlightColor: "transparent",
        ...style,
      }}
      {...rest}
    >
      {leading && <span style={{ flex: "none", display: "inline-flex" }}>{leading}</span>}
      <span style={{ flex: 1, minWidth: 0 }}>
        <span
          style={{
            display: "block",
            fontFamily: "var(--font-sans)",
            fontSize: 17,
            letterSpacing: "-0.4px",
            color: "var(--text)",
            fontWeight: 400,
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
          }}
        >
          {title}
        </span>
        {subtitle && (
          <span
            style={{
              display: "block",
              fontFamily: "var(--font-sans)",
              fontSize: 13,
              color: "var(--text-secondary)",
              marginTop: 1,
            }}
          >
            {subtitle}
          </span>
        )}
      </span>
      {value && (
        <span style={{ fontFamily: "var(--font-sans)", fontSize: 17, color: "var(--text-secondary)" }}>
          {value}
        </span>
      )}
      {trailing}
      {chevron && (
        <svg width="8" height="14" viewBox="0 0 8 14" style={{ flex: "none" }}>
          <path d="M1 1l6 6-6 6" fill="none" stroke="var(--text-tertiary)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      )}
    </div>
  );
}
