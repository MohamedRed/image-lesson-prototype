import React from "react";
import { Avatar } from "../core/Avatar.jsx";
import { RatingStars } from "../core/RatingStars.jsx";

/**
 * Liive Ride — DriverCard
 * The matched-driver summary: avatar, name, rating, vehicle + plate, and an
 * ETA pill. Trailing slot holds call/message actions.
 */
export function DriverCard({
  name,
  rating = null,
  vehicle = null,
  plate = null,
  eta = null,
  avatarSrc = null,
  speaking = false,
  trailing = null,
  style,
  ...rest
}) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 14,
        background: "var(--surface)",
        borderRadius: "var(--radius-lg)",
        padding: 14,
        boxShadow: "var(--shadow-card)",
        ...style,
      }}
      {...rest}
    >
      <Avatar name={name} src={avatarSrc} size={54} ring={speaking} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{ fontFamily: "var(--font-sans)", fontSize: 17, fontWeight: 600, color: "var(--text)" }}>
            {name}
          </span>
          {rating != null && <RatingStars value={rating} showValue size={13} />}
        </div>
        {(vehicle || plate) && (
          <div style={{ fontFamily: "var(--font-sans)", fontSize: 14, color: "var(--text-secondary)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
            {vehicle}
            {vehicle && plate ? " · " : ""}
            {plate && (
              <span style={{ fontWeight: 600, color: "var(--text)", letterSpacing: 0.5 }}>{plate}</span>
            )}
          </div>
        )}
      </div>
      {eta != null && (
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", flex: "none" }}>
          <span className="tnum" style={{ fontFamily: "var(--font-sans)", fontSize: 22, fontWeight: 700, color: "var(--accent)", lineHeight: 1 }}>
            {eta}
          </span>
          <span style={{ fontFamily: "var(--font-sans)", fontSize: 11, color: "var(--text-secondary)", marginTop: 2 }}>
            away
          </span>
        </div>
      )}
      {trailing}
    </div>
  );
}
