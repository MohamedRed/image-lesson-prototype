import React from "react";

/**
 * Liive Ride — SOSButton
 * The always-reachable emergency control. A red disc with a continuous
 * pulse halo; press shrinks it. Tap fires onActivate (host confirms before
 * contacting emergency services).
 */
export function SOSButton({ size = 64, onActivate, label = true, style, ...rest }) {
  const [pressed, setPressed] = React.useState(false);
  return (
    <button
      type="button"
      onClick={onActivate}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
      aria-label="Emergency SOS"
      style={{
        position: "relative",
        width: size,
        height: size,
        border: "none",
        borderRadius: "50%",
        background: "var(--danger)",
        boxShadow: "var(--shadow-sos)",
        cursor: "pointer",
        display: "inline-flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 1,
        transform: pressed ? "scale(0.94)" : "scale(1)",
        transition: "transform var(--dur-fast) var(--ease-out)",
        WebkitTapHighlightColor: "transparent",
        ...style,
      }}
      {...rest}
    >
      <span
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: "50%",
          background: "var(--danger)",
          opacity: 0.35,
          animation: "liive-sos-pulse 1.5s ease-out infinite",
          zIndex: -1,
        }}
      />
      <span
        style={{
          fontFamily: "var(--font-rounded)",
          fontWeight: 700,
          fontSize: size * 0.28,
          color: "#fff",
          lineHeight: 1,
        }}
      >
        SOS
      </span>
      {label && (
        <span
          style={{
            fontFamily: "var(--font-rounded)",
            fontWeight: 600,
            fontSize: size * 0.15,
            color: "rgba(255,255,255,0.9)",
            letterSpacing: 0.5,
            lineHeight: 1,
          }}
        >
          HELP
        </span>
      )}
      <style>{
        "@keyframes liive-sos-pulse{0%{transform:scale(1);opacity:.35}100%{transform:scale(1.5);opacity:0}}" +
        "@media (prefers-reduced-motion: reduce){[aria-label='Emergency SOS'] span{animation:none!important}}"
      }</style>
    </button>
  );
}
