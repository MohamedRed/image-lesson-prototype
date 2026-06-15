import React from "react";

/**
 * Base filled surface container.
 */
export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Inner padding in px. Default 16. */
  padding?: number;
  /** Corner radius (CSS value). Default 12px. */
  radius?: string;
  /** Show the accent selection stroke. */
  active?: boolean;
  /** Use the raised surface color (for nested rows). */
  raised?: boolean;
  children?: React.ReactNode;
}

export function Card(props: CardProps): JSX.Element;
