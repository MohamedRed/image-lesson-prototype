import React from "react";

export type ButtonVariant =
  | "primary"
  | "secondary"
  | "tinted"
  | "plain"
  | "destructive"
  | "destructive-plain";

/**
 * The iOS action button for Liive Ride.
 */
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** Visual style. Default "primary" (filled accent). */
  variant?: ButtonVariant;
  /** Control height. Default "md" (44px). */
  size?: "sm" | "md" | "lg";
  /** "rounded" (10px) or "capsule" (fully rounded CTA). Default "rounded". */
  shape?: "rounded" | "capsule";
  /** Stretch to container width — use for the bottom-pinned primary CTA. */
  fullWidth?: boolean;
  disabled?: boolean;
  /** Show a spinner and block interaction. */
  loading?: boolean;
  /** Leading element (e.g. a Lucide icon). */
  icon?: React.ReactNode;
  /** Trailing element. */
  iconRight?: React.ReactNode;
  children?: React.ReactNode;
}

export function Button(props: ButtonProps): JSX.Element;
