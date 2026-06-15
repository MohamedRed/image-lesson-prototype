import React from "react";

/**
 * iOS toggle switch.
 */
export interface SwitchProps
  extends Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, "onChange"> {
  /** On/off state. */
  checked?: boolean;
  /** Change callback with the next value. */
  onChange?: (checked: boolean) => void;
  disabled?: boolean;
}

export function Switch(props: SwitchProps): JSX.Element;
