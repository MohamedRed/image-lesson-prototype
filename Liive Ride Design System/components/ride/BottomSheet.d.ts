import React from "react";

/**
 * iOS bottom sheet rising over the map.
 */
export interface BottomSheetProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Show the grabber handle. Default true. */
  grabber?: boolean;
  /** Inner padding in px. Default 16. */
  padding?: number;
  children?: React.ReactNode;
}

export function BottomSheet(props: BottomSheetProps): JSX.Element;
