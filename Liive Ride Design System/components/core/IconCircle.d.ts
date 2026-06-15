import React from "react";

/**
 * Tinted circular icon badge.
 */
export interface IconCircleProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Semantic color. Default "accent". */
  color?: "accent" | "success" | "warning" | "danger" | "info" | "neutral";
  /** Diameter in px. Default 44. */
  size?: number;
  /** Solid fill (white glyph) vs tinted (default). */
  filled?: boolean;
  /** The icon (e.g. a Lucide <i> or svg). */
  children?: React.ReactNode;
}

export function IconCircle(props: IconCircleProps): JSX.Element;
