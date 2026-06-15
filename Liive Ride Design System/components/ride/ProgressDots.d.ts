import React from "react";

/**
 * Multi-leg journey progress with numbered legs and transfer links.
 */
export interface ProgressDotsProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Total legs in the journey (1–3). */
  legs?: number;
  /** Current (1-indexed) leg; legs before it render completed. */
  current?: number;
}

export function ProgressDots(props: ProgressDotsProps): JSX.Element;
