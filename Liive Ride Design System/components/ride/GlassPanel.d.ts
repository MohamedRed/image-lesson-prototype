import React from "react";

/**
 * Frosted-glass material panel that floats over the map.
 */
export interface GlassPanelProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Material thickness (blur + opacity). Default "regular". */
  material?: "thin" | "regular" | "thick";
  /** Corner radius (CSS value). Default 12px. */
  radius?: string;
  /** Inner padding in px. Default 14. */
  padding?: number;
  children?: React.ReactNode;
}

export function GlassPanel(props: GlassPanelProps): JSX.Element;
