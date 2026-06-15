import React from "react";

/**
 * A map pin / marker for the live ride map.
 */
export interface MapMarkerProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Marker type. Default "car". */
  kind?: "car" | "origin" | "destination" | "transfer";
  /** Optional callout label below the marker. */
  label?: React.ReactNode;
}

export function MapMarker(props: MapMarkerProps): JSX.Element;
