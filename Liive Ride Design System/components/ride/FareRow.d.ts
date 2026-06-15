import React from "react";

/**
 * One line of a fare / payment breakdown.
 */
export interface FareRowProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Left-hand label. */
  label: React.ReactNode;
  /** Right-hand amount (pre-formatted string). */
  amount: React.ReactNode;
  /** Emphasise as the total row (with a top divider gap). */
  total?: boolean;
  /** Muted label (e.g. a discount note). */
  muted?: boolean;
}

export function FareRow(props: FareRowProps): JSX.Element;
