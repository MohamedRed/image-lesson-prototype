import React from "react";

/**
 * Capsule status/metadata badge.
 */
export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Semantic color. Default "neutral". */
  color?: "neutral" | "accent" | "success" | "warning" | "danger" | "info";
  /** Filled (solid) vs tinted (default). */
  solid?: boolean;
  /** Show a leading status dot. */
  dot?: boolean;
  /** Optional leading icon. */
  icon?: React.ReactNode;
  children?: React.ReactNode;
}

export function Badge(props: BadgeProps): JSX.Element;
