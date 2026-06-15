import React from "react";

/**
 * Matched-driver summary card.
 */
export interface DriverCardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Driver name. */
  name: string;
  /** Star rating (0–5). */
  rating?: number | null;
  /** Vehicle description, e.g. "Toyota Camry · Blue". */
  vehicle?: string | null;
  /** License plate. */
  plate?: string | null;
  /** ETA string, e.g. "4 min". */
  eta?: string | null;
  /** Avatar image URL. */
  avatarSrc?: string | null;
  /** Highlight as the active voice speaker (avatar ring). */
  speaking?: boolean;
  /** Trailing actions (call / message buttons). */
  trailing?: React.ReactNode;
}

export function DriverCard(props: DriverCardProps): JSX.Element;
