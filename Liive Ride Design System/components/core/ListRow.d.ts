import React from "react";

/**
 * iOS grouped-list row.
 */
export interface ListRowProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Leading element (icon / IconCircle / avatar). */
  leading?: React.ReactNode;
  /** Primary text. */
  title: React.ReactNode;
  /** Secondary text below the title. */
  subtitle?: React.ReactNode;
  /** Right-aligned secondary value text. */
  value?: React.ReactNode;
  /** Custom trailing element (switch, stepper, badge). */
  trailing?: React.ReactNode;
  /** Show a disclosure chevron. */
  chevron?: boolean;
  /** Draw the bottom hairline. Default true. */
  divider?: boolean;
}

export function ListRow(props: ListRowProps): JSX.Element;
