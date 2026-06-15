import React from "react";

/**
 * The always-reachable emergency SOS control with a pulsing halo.
 */
export interface SOSButtonProps
  extends Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, "onClick"> {
  /** Diameter in px. Default 64. */
  size?: number;
  /** Show the "HELP" sub-label. Default true. */
  label?: boolean;
  /** Fired on tap — host should confirm before contacting services. */
  onActivate?: () => void;
}

export function SOSButton(props: SOSButtonProps): JSX.Element;
