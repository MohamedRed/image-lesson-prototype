import React from "react";

/**
 * iOS −/+ stepper for small integer counts.
 */
export interface StepperProps
  extends Omit<React.HTMLAttributes<HTMLSpanElement>, "onChange"> {
  value?: number;
  min?: number;
  max?: number;
  onChange?: (value: number) => void;
}

export function Stepper(props: StepperProps): JSX.Element;
