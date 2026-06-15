import React from "react";

/**
 * Driver / rider avatar with image or initials fallback.
 */
export interface AvatarProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Full name — initials are derived from it. */
  name?: string;
  /** Optional image URL. */
  src?: string | null;
  /** Diameter in px. Default 48. */
  size?: number;
  /** Show an accent ring (active speaker). */
  ring?: boolean;
  /** Ring color. Default accent. */
  ringColor?: string;
}

export function Avatar(props: AvatarProps): JSX.Element;
