import React from "react";

/**
 * Liive Ride — RatingStars
 * Compact driver rating. Shows fractional fill; optionally the numeric value.
 */
export function RatingStars({
  value = 0,
  max = 5,
  size = 14,
  showValue = true,
  style,
  ...rest
}) {
  const pct = Math.max(0, Math.min(1, value / max)) * 100;
  const starPath =
    "M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.8 5.9 21.4l1.4-6.8L2.2 9.9l6.9-.8z";

  const Row = ({ fill }) => (
    <span style={{ display: "inline-flex", gap: 1 }}>
      {Array.from({ length: max }).map((_, i) => (
        <svg key={i} width={size} height={size} viewBox="0 0 24 24" style={{ display: "block" }}>
          <path d={starPath} fill={fill} />
        </svg>
      ))}
    </span>
  );

  return (
    <span
      style={{ display: "inline-flex", alignItems: "center", gap: 5, ...style }}
      {...rest}
    >
      <span style={{ position: "relative", display: "inline-flex" }}>
        <Row fill="var(--fill)" />
        <span
          style={{
            position: "absolute", top: 0, left: 0, width: `${pct}%`,
            overflow: "hidden", whiteSpace: "nowrap",
          }}
        >
          <Row fill="var(--star)" />
        </span>
      </span>
      {showValue && (
        <span
          className="tnum"
          style={{
            fontFamily: "var(--font-sans)", fontSize: size - 1,
            fontWeight: 600, color: "var(--text)",
          }}
        >
          {value.toFixed(1)}
        </span>
      )}
    </span>
  );
}
