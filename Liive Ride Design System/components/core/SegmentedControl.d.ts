import React from "react";

export interface SegmentOption {
  label: string;
  value: string;
}

/**
 * iOS segmented control.
 */
export interface SegmentedControlProps
  extends Omit<React.HTMLAttributes<HTMLDivElement>, "onChange"> {
  /** Options as strings or {label, value}. */
  options: (string | SegmentOption)[];
  /** Currently selected value. */
  value: string;
  /** Selection callback. */
  onChange?: (value: string) => void;
}

export function SegmentedControl(props: SegmentedControlProps): JSX.Element;
