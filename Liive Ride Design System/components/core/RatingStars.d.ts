import React from "react";

/**
 * Compact star rating with fractional fill.
 */
export interface RatingStarsProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Rating value (0–max). */
  value?: number;
  /** Maximum stars. Default 5. */
  max?: number;
  /** Star size in px. Default 14. */
  size?: number;
  /** Show the numeric value after the stars. Default true. */
  showValue?: boolean;
}

export function RatingStars(props: RatingStarsProps): JSX.Element;
