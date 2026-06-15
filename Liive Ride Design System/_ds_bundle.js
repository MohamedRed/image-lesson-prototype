/* @ds-bundle: {"format":3,"namespace":"LiiveRideDesignSystem_b6f128","components":[{"name":"Avatar","sourcePath":"components/core/Avatar.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"IconCircle","sourcePath":"components/core/IconCircle.jsx"},{"name":"ListRow","sourcePath":"components/core/ListRow.jsx"},{"name":"RatingStars","sourcePath":"components/core/RatingStars.jsx"},{"name":"SegmentedControl","sourcePath":"components/core/SegmentedControl.jsx"},{"name":"Stepper","sourcePath":"components/core/Stepper.jsx"},{"name":"Switch","sourcePath":"components/core/Switch.jsx"},{"name":"BottomSheet","sourcePath":"components/ride/BottomSheet.jsx"},{"name":"DriverCard","sourcePath":"components/ride/DriverCard.jsx"},{"name":"FareRow","sourcePath":"components/ride/FareRow.jsx"},{"name":"GlassPanel","sourcePath":"components/ride/GlassPanel.jsx"},{"name":"MapMarker","sourcePath":"components/ride/MapMarker.jsx"},{"name":"ProgressDots","sourcePath":"components/ride/ProgressDots.jsx"},{"name":"SOSButton","sourcePath":"components/ride/SOSButton.jsx"}],"sourceHashes":{"components/core/Avatar.jsx":"761e507b7448","components/core/Badge.jsx":"a9c9987d009c","components/core/Button.jsx":"e60e2aafca2f","components/core/Card.jsx":"202627e780e8","components/core/IconCircle.jsx":"6a2fcf1561eb","components/core/ListRow.jsx":"e87c2550ef6b","components/core/RatingStars.jsx":"511d55f6ec86","components/core/SegmentedControl.jsx":"704c594aba37","components/core/Stepper.jsx":"f6dd1fd9116e","components/core/Switch.jsx":"d3b8151c3842","components/ride/BottomSheet.jsx":"d49b056ff714","components/ride/DriverCard.jsx":"6ca1f19ccf1c","components/ride/FareRow.jsx":"74e5b0d59f54","components/ride/GlassPanel.jsx":"6e3c8b12f1e5","components/ride/MapMarker.jsx":"889cbfcc4b19","components/ride/ProgressDots.jsx":"e192d4951832","components/ride/SOSButton.jsx":"94816ee20e9e","explorations/design-canvas.jsx":"cb659cf1acf8","ui_kits/liive-ride/MapCanvas.jsx":"5cd50f43a3d4","ui_kits/liive-ride/RideApp.jsx":"d7e866a034c7","ui_kits/liive-ride/ios-frame.jsx":"be3343be4b51","ui_kits/liive-ride/screens1.jsx":"0b3f715e6b2a","ui_kits/liive-ride/screens2.jsx":"b7d6a5527507"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.LiiveRideDesignSystem_b6f128 = window.LiiveRideDesignSystem_b6f128 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Avatar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — Avatar
 * Driver / rider avatar. Image when available, else initials on a tinted
 * disc. Optional accent ring marks the active speaker on the voice channel.
 */
function Avatar({
  name = "",
  src = null,
  size = 48,
  ring = false,
  ringColor = "var(--accent)",
  style,
  ...rest
}) {
  const initials = name.split(" ").filter(Boolean).slice(0, 2).map(w => w[0]?.toUpperCase()).join("");
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      width: size,
      height: size,
      flex: "none",
      borderRadius: "50%",
      background: "var(--fill)",
      color: "var(--text)",
      fontFamily: "var(--font-sans)",
      fontWeight: 600,
      fontSize: size * 0.4,
      overflow: "hidden",
      boxShadow: ring ? `0 0 0 2.5px var(--surface), 0 0 0 5px ${ringColor}` : "none",
      ...style
    }
  }, rest), src ? /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: name,
    style: {
      width: "100%",
      height: "100%",
      objectFit: "cover"
    }
  }) : initials || "?");
}
Object.assign(__ds_scope, { Avatar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Avatar.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — Badge
 * Small capsule for status & metadata. Color variants map to the semantic
 * palette; an optional leading dot reads as a live status indicator.
 */
function Badge({
  children,
  color = "neutral",
  solid = false,
  dot = false,
  icon = null,
  style,
  ...rest
}) {
  const map = {
    neutral: {
      fg: "var(--text-secondary)",
      tint: "var(--fill-tertiary)",
      solid: "var(--fill)"
    },
    accent: {
      fg: "var(--accent)",
      tint: "var(--accent-tint)",
      solid: "var(--accent)"
    },
    success: {
      fg: "var(--success)",
      tint: "var(--success-tint)",
      solid: "var(--success)"
    },
    warning: {
      fg: "var(--warning)",
      tint: "var(--warning-tint)",
      solid: "var(--warning)"
    },
    danger: {
      fg: "var(--danger)",
      tint: "var(--danger-tint)",
      solid: "var(--danger)"
    },
    info: {
      fg: "var(--info)",
      tint: "var(--info-tint)",
      solid: "var(--info)"
    }
  };
  const c = map[color] || map.neutral;
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 5,
      padding: "3px 9px",
      borderRadius: "var(--radius-full)",
      background: solid ? c.solid : c.tint,
      color: solid ? color === "warning" || color === "info" ? "#000" : "#fff" : c.fg,
      fontFamily: "var(--font-sans)",
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: 0.1,
      lineHeight: 1.3,
      whiteSpace: "nowrap",
      ...style
    }
  }, rest), dot && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 7,
      height: 7,
      borderRadius: "50%",
      background: solid ? "currentColor" : c.fg,
      flex: "none"
    }
  }), icon, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — Button
 * The iOS action button. Filled accent for primary actions, tinted/gray for
 * secondary, plain for inline links, destructive for cancel/emergency.
 * Presses dim + shrink slightly (the native iOS feel).
 */
function Button({
  children,
  variant = "primary",
  size = "md",
  shape = "rounded",
  fullWidth = false,
  disabled = false,
  loading = false,
  icon = null,
  iconRight = null,
  onClick,
  style,
  ...rest
}) {
  const [pressed, setPressed] = React.useState(false);
  const heights = {
    sm: 32,
    md: 44,
    lg: 50
  };
  const fonts = {
    sm: 15,
    md: 17,
    lg: 17
  };
  const pads = {
    sm: "0 14px",
    md: "0 18px",
    lg: "0 22px"
  };
  const palettes = {
    primary: {
      bg: "var(--accent)",
      color: "var(--on-accent)",
      bgPressed: "var(--accent-pressed)"
    },
    secondary: {
      bg: "var(--fill)",
      color: "var(--text)",
      bgPressed: "var(--fill-secondary)"
    },
    tinted: {
      bg: "var(--accent-tint)",
      color: "var(--accent)",
      bgPressed: "var(--accent-tint)"
    },
    plain: {
      bg: "transparent",
      color: "var(--accent)",
      bgPressed: "transparent"
    },
    destructive: {
      bg: "var(--danger)",
      color: "#fff",
      bgPressed: "var(--danger)"
    },
    "destructive-plain": {
      bg: "transparent",
      color: "var(--danger)",
      bgPressed: "transparent"
    }
  };
  const p = palettes[variant] || palettes.primary;
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    disabled: disabled || loading,
    onClick: onClick,
    onPointerDown: () => setPressed(true),
    onPointerUp: () => setPressed(false),
    onPointerLeave: () => setPressed(false),
    style: {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 8,
      width: fullWidth ? "100%" : "auto",
      height: heights[size],
      padding: pads[size],
      border: "none",
      borderRadius: shape === "capsule" ? "var(--radius-full)" : "var(--radius-md)",
      background: pressed ? p.bgPressed : p.bg,
      color: p.color,
      fontFamily: "var(--font-sans)",
      fontSize: fonts[size],
      fontWeight: variant === "plain" || variant === "destructive-plain" ? 400 : 600,
      letterSpacing: "-0.4px",
      cursor: disabled || loading ? "default" : "pointer",
      opacity: disabled ? 0.4 : pressed ? variant === "plain" || variant === "tinted" || variant === "destructive-plain" ? 0.5 : 0.85 : 1,
      transform: pressed && !disabled ? "scale(0.97)" : "scale(1)",
      transition: "transform var(--dur-fast) var(--ease-out), opacity var(--dur-fast), background var(--dur-fast)",
      WebkitTapHighlightColor: "transparent",
      userSelect: "none",
      ...style
    }
  }, rest), loading ? /*#__PURE__*/React.createElement("span", {
    style: {
      width: 18,
      height: 18,
      borderRadius: "50%",
      border: "2px solid currentColor",
      borderTopColor: "transparent",
      display: "inline-block",
      animation: "liive-spin 0.7s linear infinite"
    }
  }) : /*#__PURE__*/React.createElement(React.Fragment, null, icon, children, iconRight), /*#__PURE__*/React.createElement("style", null, "@keyframes liive-spin{to{transform:rotate(360deg)}}"));
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — Card
 * The base filled surface: 12–16px radius, soft shadow, no border in dark
 * mode. An accent stroke marks an *active* card (e.g. selected ride option).
 */
function Card({
  children,
  padding = 16,
  radius = "var(--radius-lg)",
  active = false,
  raised = false,
  onClick,
  style,
  ...rest
}) {
  const interactive = !!onClick;
  return /*#__PURE__*/React.createElement("div", _extends({
    onClick: onClick,
    style: {
      background: raised ? "var(--surface-raised)" : "var(--surface)",
      borderRadius: radius,
      padding,
      boxShadow: active ? "none" : "var(--shadow-card)",
      border: active ? "1.5px solid var(--accent)" : "1.5px solid transparent",
      cursor: interactive ? "pointer" : "default",
      transition: "border-color var(--dur-fast), transform var(--dur-fast) var(--ease-out)",
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/IconCircle.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — IconCircle
 * A tinted circular icon badge — the recurring "feature glyph" used on
 * feature cards, list rows and map callouts.
 */
function IconCircle({
  children,
  color = "accent",
  size = 44,
  filled = false,
  style,
  ...rest
}) {
  const map = {
    accent: {
      fg: "var(--accent)",
      tint: "var(--accent-tint)",
      solid: "var(--accent)"
    },
    success: {
      fg: "var(--success)",
      tint: "var(--success-tint)",
      solid: "var(--success)"
    },
    warning: {
      fg: "var(--warning)",
      tint: "var(--warning-tint)",
      solid: "var(--warning)"
    },
    danger: {
      fg: "var(--danger)",
      tint: "var(--danger-tint)",
      solid: "var(--danger)"
    },
    info: {
      fg: "var(--info)",
      tint: "var(--info-tint)",
      solid: "var(--info)"
    },
    neutral: {
      fg: "var(--text-secondary)",
      tint: "var(--fill-tertiary)",
      solid: "var(--fill)"
    }
  };
  const c = map[color] || map.accent;
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      width: size,
      height: size,
      flex: "none",
      borderRadius: "50%",
      background: filled ? c.solid : c.tint,
      color: filled ? "#fff" : c.fg,
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { IconCircle });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconCircle.jsx", error: String((e && e.message) || e) }); }

// components/core/ListRow.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — ListRow
 * The iOS grouped-list row: leading icon, title + optional subtitle, trailing
 * value / control / chevron. Tap feedback dims the row.
 */
function ListRow({
  leading = null,
  title,
  subtitle = null,
  value = null,
  trailing = null,
  chevron = false,
  divider = true,
  onClick,
  style,
  ...rest
}) {
  const [pressed, setPressed] = React.useState(false);
  const interactive = !!onClick;
  return /*#__PURE__*/React.createElement("div", _extends({
    onClick: onClick,
    onPointerDown: () => interactive && setPressed(true),
    onPointerUp: () => setPressed(false),
    onPointerLeave: () => setPressed(false),
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      minHeight: 44,
      padding: "10px 16px",
      background: pressed ? "var(--fill-quaternary)" : "transparent",
      boxShadow: divider ? "inset 0 -0.5px 0 var(--separator)" : "none",
      cursor: interactive ? "pointer" : "default",
      transition: "background var(--dur-fast)",
      WebkitTapHighlightColor: "transparent",
      ...style
    }
  }, rest), leading && /*#__PURE__*/React.createElement("span", {
    style: {
      flex: "none",
      display: "inline-flex"
    }
  }, leading), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: "block",
      fontFamily: "var(--font-sans)",
      fontSize: 17,
      letterSpacing: "-0.4px",
      color: "var(--text)",
      fontWeight: 400,
      overflow: "hidden",
      textOverflow: "ellipsis",
      whiteSpace: "nowrap"
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("span", {
    style: {
      display: "block",
      fontFamily: "var(--font-sans)",
      fontSize: 13,
      color: "var(--text-secondary)",
      marginTop: 1
    }
  }, subtitle)), value && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 17,
      color: "var(--text-secondary)"
    }
  }, value), trailing, chevron && /*#__PURE__*/React.createElement("svg", {
    width: "8",
    height: "14",
    viewBox: "0 0 8 14",
    style: {
      flex: "none"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1 1l6 6-6 6",
    fill: "none",
    stroke: "var(--text-tertiary)",
    strokeWidth: "2",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  })));
}
Object.assign(__ds_scope, { ListRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/ListRow.jsx", error: String((e && e.message) || e) }); }

// components/core/RatingStars.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — RatingStars
 * Compact driver rating. Shows fractional fill; optionally the numeric value.
 */
function RatingStars({
  value = 0,
  max = 5,
  size = 14,
  showValue = true,
  style,
  ...rest
}) {
  const pct = Math.max(0, Math.min(1, value / max)) * 100;
  const starPath = "M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.8 5.9 21.4l1.4-6.8L2.2 9.9l6.9-.8z";
  const Row = ({
    fill
  }) => /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      gap: 1
    }
  }, Array.from({
    length: max
  }).map((_, i) => /*#__PURE__*/React.createElement("svg", {
    key: i,
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    style: {
      display: "block"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: starPath,
    fill: fill
  }))));
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 5,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      display: "inline-flex"
    }
  }, /*#__PURE__*/React.createElement(Row, {
    fill: "var(--fill)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      top: 0,
      left: 0,
      width: `${pct}%`,
      overflow: "hidden",
      whiteSpace: "nowrap"
    }
  }, /*#__PURE__*/React.createElement(Row, {
    fill: "var(--star)"
  }))), showValue && /*#__PURE__*/React.createElement("span", {
    className: "tnum",
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: size - 1,
      fontWeight: 600,
      color: "var(--text)"
    }
  }, value.toFixed(1)));
}
Object.assign(__ds_scope, { RatingStars });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/RatingStars.jsx", error: String((e && e.message) || e) }); }

// components/core/SegmentedControl.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — SegmentedControl
 * The iOS segmented control. Used for rider/driver mode, ride tiers, etc.
 * The selected segment is a raised pill that slides between options.
 */
function SegmentedControl({
  options = [],
  value,
  onChange,
  style,
  ...rest
}) {
  const items = options.map(o => typeof o === "string" ? {
    label: o,
    value: o
  } : o);
  const idx = Math.max(0, items.findIndex(i => i.value === value));
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      position: "relative",
      display: "grid",
      gridTemplateColumns: `repeat(${items.length}, 1fr)`,
      padding: 2,
      background: "var(--fill-tertiary)",
      borderRadius: "var(--radius-sm)",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      top: 2,
      bottom: 2,
      left: `calc(${100 / items.length * idx}% + 2px)`,
      width: `calc(${100 / items.length}% - 4px)`,
      background: "var(--surface-raised)",
      borderRadius: 7,
      boxShadow: "var(--shadow-sm)",
      transition: "left var(--dur-base) var(--ease-out)"
    }
  }), items.map(it => {
    const selected = it.value === value;
    return /*#__PURE__*/React.createElement("button", {
      key: it.value,
      type: "button",
      onClick: () => onChange && onChange(it.value),
      style: {
        position: "relative",
        zIndex: 1,
        background: "transparent",
        border: "none",
        padding: "7px 12px",
        fontFamily: "var(--font-sans)",
        fontSize: 14,
        fontWeight: selected ? 600 : 500,
        color: selected ? "var(--text)" : "var(--text-secondary)",
        cursor: "pointer",
        WebkitTapHighlightColor: "transparent",
        transition: "color var(--dur-fast)"
      }
    }, it.label);
  }));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/core/Stepper.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — Stepper
 * The iOS −/+ stepper for small integer counts (passengers, luggage, pets).
 */
function Stepper({
  value = 0,
  min = 0,
  max = 99,
  onChange,
  style,
  ...rest
}) {
  const set = next => {
    const v = Math.max(min, Math.min(max, next));
    if (v !== value && onChange) onChange(v);
  };
  const btn = (label, onClick, disabled) => /*#__PURE__*/React.createElement("button", {
    type: "button",
    onClick: onClick,
    disabled: disabled,
    style: {
      width: 44,
      height: 32,
      border: "none",
      background: "transparent",
      color: disabled ? "var(--text-quaternary)" : "var(--text)",
      fontSize: 20,
      fontWeight: 400,
      cursor: disabled ? "default" : "pointer",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      WebkitTapHighlightColor: "transparent"
    }
  }, label);
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      background: "var(--fill-tertiary)",
      borderRadius: "var(--radius-sm)",
      ...style
    }
  }, rest), btn("−", () => set(value - 1), value <= min), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 1,
      height: 18,
      background: "var(--separator)",
      flex: "none"
    }
  }), btn("+", () => set(value + 1), value >= max));
}
Object.assign(__ds_scope, { Stepper });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Stepper.jsx", error: String((e && e.message) || e) }); }

// components/core/Switch.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — Switch
 * The iOS toggle. Green when on (system green), grey track when off.
 */
function Switch({
  checked = false,
  onChange,
  disabled = false,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    role: "switch",
    "aria-checked": checked,
    disabled: disabled,
    onClick: () => !disabled && onChange && onChange(!checked),
    style: {
      width: 51,
      height: 31,
      flex: "none",
      borderRadius: "var(--radius-full)",
      border: "none",
      padding: 2,
      background: checked ? "var(--success)" : "var(--fill)",
      cursor: disabled ? "default" : "pointer",
      opacity: disabled ? 0.5 : 1,
      transition: "background var(--dur-base) var(--ease-out)",
      WebkitTapHighlightColor: "transparent",
      display: "inline-flex",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 27,
      height: 27,
      borderRadius: "50%",
      background: "#fff",
      boxShadow: "0 2px 4px rgba(0,0,0,0.25)",
      transform: checked ? "translateX(20px)" : "translateX(0)",
      transition: "transform var(--dur-base) var(--ease-out)"
    }
  }));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Switch.jsx", error: String((e && e.message) || e) }); }

// components/ride/BottomSheet.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — BottomSheet
 * The iOS sheet that rises from the bottom over the map: rounded top, grabber
 * handle, opaque sheet surface. Static (non-draggable) presentation suitable
 * for mockups — render it inside a phone frame.
 */
function BottomSheet({
  children,
  grabber = true,
  padding = 16,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      background: "var(--surface-sheet)",
      borderTopLeftRadius: "var(--radius-3xl)",
      borderTopRightRadius: "var(--radius-3xl)",
      boxShadow: "var(--shadow-sheet)",
      padding: `${grabber ? 8 : padding}px ${padding}px calc(${padding}px + var(--safe-bottom))`,
      ...style
    }
  }, rest), grabber && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 36,
      height: 5,
      borderRadius: "var(--radius-full)",
      background: "var(--fill)",
      margin: "0 auto 14px"
    }
  }), children);
}
Object.assign(__ds_scope, { BottomSheet });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/ride/BottomSheet.jsx", error: String((e && e.message) || e) }); }

// components/ride/DriverCard.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — DriverCard
 * The matched-driver summary: avatar, name, rating, vehicle + plate, and an
 * ETA pill. Trailing slot holds call/message actions.
 */
function DriverCard({
  name,
  rating = null,
  vehicle = null,
  plate = null,
  eta = null,
  avatarSrc = null,
  speaking = false,
  trailing = null,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      alignItems: "center",
      gap: 14,
      background: "var(--surface)",
      borderRadius: "var(--radius-lg)",
      padding: 14,
      boxShadow: "var(--shadow-card)",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Avatar, {
    name: name,
    src: avatarSrc,
    size: 54,
    ring: speaking
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 17,
      fontWeight: 600,
      color: "var(--text)"
    }
  }, name), rating != null && /*#__PURE__*/React.createElement(__ds_scope.RatingStars, {
    value: rating,
    showValue: true,
    size: 13
  })), (vehicle || plate) && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 14,
      color: "var(--text-secondary)",
      marginTop: 2,
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, vehicle, vehicle && plate ? " · " : "", plate && /*#__PURE__*/React.createElement("span", {
    style: {
      fontWeight: 600,
      color: "var(--text)",
      letterSpacing: 0.5
    }
  }, plate))), eta != null && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "flex-end",
      flex: "none"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "tnum",
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 22,
      fontWeight: 700,
      color: "var(--accent)",
      lineHeight: 1
    }
  }, eta), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 11,
      color: "var(--text-secondary)",
      marginTop: 2
    }
  }, "away")), trailing);
}
Object.assign(__ds_scope, { DriverCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/ride/DriverCard.jsx", error: String((e && e.message) || e) }); }

// components/ride/FareRow.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — FareRow
 * One line of the Stripe fare breakdown. The total row is emphasised.
 */
function FareRow({
  label,
  amount,
  total = false,
  muted = false,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      alignItems: "baseline",
      justifyContent: "space-between",
      gap: 12,
      padding: total ? "12px 0 0" : "6px 0",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: total ? 17 : 15,
      fontWeight: total ? 600 : 400,
      color: total ? "var(--text)" : muted ? "var(--text-tertiary)" : "var(--text-secondary)"
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    className: "tnum",
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: total ? 17 : 15,
      fontWeight: total ? 700 : 500,
      color: total ? "var(--text)" : "var(--text)"
    }
  }, amount));
}
Object.assign(__ds_scope, { FareRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/ride/FareRow.jsx", error: String((e && e.message) || e) }); }

// components/ride/GlassPanel.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — GlassPanel
 * A frosted-glass material panel that floats over the live map (mirrors
 * SwiftUI .ultraThinMaterial / .thinMaterial). Use for HUD chips, the voice
 * pill, and floating info.
 */
function GlassPanel({
  children,
  material = "regular",
  radius = "var(--radius-lg)",
  padding = 14,
  style,
  ...rest
}) {
  const bg = {
    thin: "var(--material-thin)",
    regular: "var(--material-regular)",
    thick: "var(--material-thick)"
  }[material];
  const blur = {
    thin: "var(--blur-thin)",
    regular: "var(--blur-regular)",
    thick: "var(--blur-thick)"
  }[material];
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      background: bg,
      WebkitBackdropFilter: blur,
      backdropFilter: blur,
      borderRadius: radius,
      padding,
      border: "0.5px solid var(--border-strong)",
      boxShadow: "var(--shadow-hud)",
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { GlassPanel });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/ride/GlassPanel.jsx", error: String((e && e.message) || e) }); }

// components/ride/MapMarker.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — MapMarker
 * A map pin/marker. "car" is the driver glyph (accent), "origin" the red
 * start dot, "destination" the pin, "transfer" the orange swap point.
 * Renders a teardrop pin or a floating dot depending on `kind`.
 */
function MapMarker({
  kind = "car",
  label = null,
  style,
  ...rest
}) {
  const cfg = {
    car: {
      color: "var(--accent)",
      icon: "car",
      shape: "disc"
    },
    origin: {
      color: "var(--success)",
      icon: "navigation",
      shape: "dot"
    },
    destination: {
      color: "var(--danger)",
      icon: "map-pin",
      shape: "pin"
    },
    transfer: {
      color: "var(--warning)",
      icon: "arrow-left-right",
      shape: "disc"
    }
  }[kind] || {};
  const glyph = /*#__PURE__*/React.createElement("svg", {
    width: "18",
    height: "18",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "#fff",
    strokeWidth: "2.2",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }, cfg.icon === "car" && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("path", {
    d: "M5 17a2 2 0 1 0 4 0M15 17a2 2 0 1 0 4 0"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M3 13l2-5a2 2 0 0 1 2-1h10a2 2 0 0 1 2 1l2 5v4H3z"
  })), cfg.icon === "navigation" && /*#__PURE__*/React.createElement("polygon", {
    points: "3 11 22 2 13 21 11 13 3 11"
  }), cfg.icon === "map-pin" && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("path", {
    d: "M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0z"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "10",
    r: "3"
  })), cfg.icon === "arrow-left-right" && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("path", {
    d: "M8 3 4 7l4 4"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M4 7h16"
  }), /*#__PURE__*/React.createElement("path", {
    d: "m16 21 4-4-4-4"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M20 17H4"
  })));
  if (cfg.shape === "dot") {
    return /*#__PURE__*/React.createElement("span", _extends({
      style: {
        display: "inline-flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 4,
        ...style
      }
    }, rest), /*#__PURE__*/React.createElement("span", {
      style: {
        width: 18,
        height: 18,
        borderRadius: "50%",
        background: cfg.color,
        border: "3px solid #fff",
        boxShadow: "var(--shadow-pin)"
      }
    }), label && /*#__PURE__*/React.createElement(Tag, {
      color: cfg.color
    }, label));
  }

  // disc + pin both render a circular badge with a pointer tail
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 4,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      display: "inline-flex"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 38,
      height: 38,
      borderRadius: "50%",
      background: cfg.color,
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      border: "2.5px solid #fff",
      boxShadow: "var(--shadow-pin)"
    }
  }, glyph), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      bottom: -5,
      left: "50%",
      width: 12,
      height: 12,
      background: cfg.color,
      transform: "translateX(-50%) rotate(45deg)",
      borderRight: "2.5px solid #fff",
      borderBottom: "2.5px solid #fff"
    }
  })), label && /*#__PURE__*/React.createElement(Tag, {
    color: cfg.color
  }, label));
}
function Tag({
  children,
  color
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      background: "var(--surface)",
      color: "var(--text)",
      fontFamily: "var(--font-sans)",
      fontSize: 12,
      fontWeight: 600,
      padding: "2px 8px",
      borderRadius: "var(--radius-full)",
      boxShadow: "var(--shadow-sm)",
      borderBottom: `2px solid ${color}`,
      whiteSpace: "nowrap"
    }
  }, children);
}
Object.assign(__ds_scope, { MapMarker });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/ride/MapMarker.jsx", error: String((e && e.message) || e) }); }

// components/ride/ProgressDots.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — ProgressDots
 * Multi-leg journey progress. Numbered leg circles connected by transfer
 * links (a swap glyph). Completed legs go green, the current leg is accent,
 * upcoming legs are muted.
 */
function ProgressDots({
  legs = 2,
  current = 1,
  style,
  ...rest
}) {
  const items = [];
  for (let n = 1; n <= legs; n++) {
    const completed = n < current;
    const active = n === current;
    const bg = completed ? "var(--success)" : active ? "var(--accent)" : "var(--fill)";
    const fg = completed || active ? "#fff" : "var(--text-tertiary)";
    items.push(/*#__PURE__*/React.createElement("span", {
      key: `leg-${n}`,
      style: {
        display: "inline-flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 4
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        width: 24,
        height: 24,
        borderRadius: "50%",
        background: bg,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: "var(--font-sans)",
        fontSize: 12,
        fontWeight: 700,
        color: fg
      }
    }, n), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 11,
        color: "var(--text-secondary)"
      }
    }, "Leg ", n)));
    if (n < legs) {
      const passed = n < current;
      items.push(/*#__PURE__*/React.createElement("span", {
        key: `tr-${n}`,
        style: {
          flex: 1,
          display: "inline-flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 3,
          marginBottom: 15,
          minWidth: 28
        }
      }, /*#__PURE__*/React.createElement("span", {
        style: {
          height: 2,
          alignSelf: "stretch",
          background: passed ? "var(--success)" : "var(--fill)",
          borderRadius: 2
        }
      }), /*#__PURE__*/React.createElement("svg", {
        width: "13",
        height: "13",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: passed ? "var(--success)" : "var(--warning)",
        strokeWidth: "2.4",
        strokeLinecap: "round",
        strokeLinejoin: "round"
      }, /*#__PURE__*/React.createElement("path", {
        d: "M8 3 4 7l4 4"
      }), /*#__PURE__*/React.createElement("path", {
        d: "M4 7h16"
      }), /*#__PURE__*/React.createElement("path", {
        d: "m16 21 4-4-4-4"
      }), /*#__PURE__*/React.createElement("path", {
        d: "M20 17H4"
      }))));
    }
  }
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      alignItems: "center",
      ...style
    }
  }, rest), items);
}
Object.assign(__ds_scope, { ProgressDots });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/ride/ProgressDots.jsx", error: String((e && e.message) || e) }); }

// components/ride/SOSButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Liive Ride — SOSButton
 * The always-reachable emergency control. A red disc with a continuous
 * pulse halo; press shrinks it. Tap fires onActivate (host confirms before
 * contacting emergency services).
 */
function SOSButton({
  size = 64,
  onActivate,
  label = true,
  style,
  ...rest
}) {
  const [pressed, setPressed] = React.useState(false);
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    onClick: onActivate,
    onPointerDown: () => setPressed(true),
    onPointerUp: () => setPressed(false),
    onPointerLeave: () => setPressed(false),
    "aria-label": "Emergency SOS",
    style: {
      position: "relative",
      width: size,
      height: size,
      border: "none",
      borderRadius: "50%",
      background: "var(--danger)",
      boxShadow: "var(--shadow-sos)",
      cursor: "pointer",
      display: "inline-flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      gap: 1,
      transform: pressed ? "scale(0.94)" : "scale(1)",
      transition: "transform var(--dur-fast) var(--ease-out)",
      WebkitTapHighlightColor: "transparent",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      inset: 0,
      borderRadius: "50%",
      background: "var(--danger)",
      opacity: 0.35,
      animation: "liive-sos-pulse 1.5s ease-out infinite",
      zIndex: -1
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-rounded)",
      fontWeight: 700,
      fontSize: size * 0.28,
      color: "#fff",
      lineHeight: 1
    }
  }, "SOS"), label && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-rounded)",
      fontWeight: 600,
      fontSize: size * 0.15,
      color: "rgba(255,255,255,0.9)",
      letterSpacing: 0.5,
      lineHeight: 1
    }
  }, "HELP"), /*#__PURE__*/React.createElement("style", null, "@keyframes liive-sos-pulse{0%{transform:scale(1);opacity:.35}100%{transform:scale(1.5);opacity:0}}" + "@media (prefers-reduced-motion: reduce){[aria-label='Emergency SOS'] span{animation:none!important}}"));
}
Object.assign(__ds_scope, { SOSButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/ride/SOSButton.jsx", error: String((e && e.message) || e) }); }

// explorations/design-canvas.jsx
try { (() => {
// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)

/* BEGIN USAGE */
// DesignCanvas.jsx — Figma-ish design canvas wrapper
// Warm gray grid bg + Sections + Artboards + PostIt notes.
// Exports (to window): DesignCanvas, DCSection, DCArtboard, DCPostIt.
// Artboards are reorderable (grip-drag), deletable, labels/titles are
// inline-editable, and any artboard can be opened in a fullscreen focus
// overlay (←/→/Esc). State persists to a .design-canvas.state.json sidecar
// via the host bridge. No assets, no deps.
//
// Usage:
//   <DesignCanvas>
//     <DCSection id="onboarding" title="Onboarding" subtitle="First-run variants">
//       <DCArtboard id="a" label="A · Dusk" width={260} height={480}>…</DCArtboard>
//       <DCArtboard id="b" label="B · Minimal" width={260} height={480}>…</DCArtboard>
//     </DCSection>
//   </DesignCanvas>
//
// Artboards are static design frames, not scroll regions — never use
// height: 100% + overflow: auto/scroll on inner elements; size each artboard
// to fit its content (explicit pixel height, or let it grow).
/* END USAGE */

const DC = {
  bg: '#f0eee9',
  grid: 'rgba(0,0,0,0.06)',
  label: 'rgba(60,50,40,0.7)',
  title: 'rgba(40,30,20,0.85)',
  subtitle: 'rgba(60,50,40,0.6)',
  postitBg: '#fef4a8',
  postitText: '#5a4a2a',
  font: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif'
};

// One-time CSS injection (classes are dc-prefixed so they don't collide with
// the hosted design's own styles).
if (typeof document !== 'undefined' && !document.getElementById('dc-styles')) {
  const s = document.createElement('style');
  s.id = 'dc-styles';
  s.textContent = ['.dc-editable{cursor:text;outline:none;white-space:nowrap;border-radius:3px;padding:0 2px;margin:0 -2px}', '.dc-editable:focus{background:#fff;box-shadow:0 0 0 1.5px #c96442}', '[data-dc-slot]{transition:transform .18s cubic-bezier(.2,.7,.3,1)}', '[data-dc-slot].dc-dragging{transition:none;z-index:10;pointer-events:none}', '[data-dc-slot].dc-dragging .dc-card{box-shadow:0 12px 40px rgba(0,0,0,.25),0 0 0 2px #c96442;transform:scale(1.02)}',
  // isolation:isolate contains artboard content's z-indexes so a
  // z-indexed child (sticky navbar etc.) can't paint over .dc-header or
  // the .dc-menu popover that drops into the top of the card.
  '.dc-card{isolation:isolate;transition:box-shadow .15s,transform .15s}', '.dc-card *{scrollbar-width:none}', '.dc-card *::-webkit-scrollbar{display:none}',
  // Per-artboard header: grip + label on the left, delete/expand on the
  // right. Single flex row; when the artboard's on-screen width is too
  // narrow for both the label yields (ellipsis, then hidden entirely below
  // ~4ch via the container query) and the buttons stay on the row.
  '.dc-header{position:absolute;bottom:100%;left:-4px;margin-bottom:calc(4px * var(--dc-inv-zoom,1));z-index:2;', '  display:flex;align-items:center;container-type:inline-size}', '.dc-labelrow{display:flex;align-items:center;gap:4px;height:24px;flex:1 1 auto;min-width:0}', '.dc-grip{flex:0 0 auto;cursor:grab;display:flex;align-items:center;padding:5px 4px;border-radius:4px;transition:background .12s,opacity .12s}', '.dc-grip:hover{background:rgba(0,0,0,.08)}', '.dc-grip:active{cursor:grabbing}', '.dc-labeltext{flex:1 1 auto;min-width:0;cursor:pointer;border-radius:4px;padding:3px 6px;', '  display:flex;align-items:center;transition:background .12s;overflow:hidden}',
  // Below ~4ch of label room: hide the label entirely, and drop the grip to
  // hover-only (same reveal rule as .dc-btns) so a narrow header is clean
  // until the card is moused.
  '@container (max-width: 110px){', '  .dc-labeltext{display:none}', '  .dc-grip{opacity:0}', '  [data-dc-slot]:hover .dc-grip{opacity:1}', '}', '.dc-labeltext:hover{background:rgba(0,0,0,.05)}', '.dc-labeltext .dc-editable{overflow:hidden;text-overflow:ellipsis;max-width:100%}', '.dc-labeltext .dc-editable:focus{overflow:visible;text-overflow:clip}', '.dc-btns{flex:0 0 auto;margin-left:auto;display:flex;gap:2px;opacity:0;transition:opacity .12s}', '[data-dc-slot]:hover .dc-btns,.dc-btns:has(.dc-menu){opacity:1}', '.dc-expand,.dc-kebab{width:22px;height:22px;border-radius:5px;border:none;cursor:pointer;padding:0;', '  background:transparent;color:rgba(60,50,40,.7);display:flex;align-items:center;justify-content:center;', '  font:inherit;transition:background .12s,color .12s}', '.dc-expand:hover,.dc-kebab:hover{background:rgba(0,0,0,.06);color:#2a251f}',
  // Slot hosting an open menu floats above later siblings (which otherwise
  // paint on top — same z-index:auto, later DOM order) so the popup isn't
  // clipped by the next card.
  '[data-dc-slot]:has(.dc-menu){z-index:10}', '.dc-menu{position:absolute;top:100%;right:0;margin-top:4px;background:#fff;border-radius:8px;', '  box-shadow:0 8px 28px rgba(0,0,0,.18),0 0 0 1px rgba(0,0,0,.05);padding:4px;min-width:160px;z-index:10}', '.dc-menu button{display:block;width:100%;padding:7px 10px;border:0;background:transparent;', '  border-radius:5px;font-family:inherit;font-size:13px;font-weight:500;line-height:1.2;', '  color:#29261b;cursor:pointer;text-align:left;transition:background .12s;white-space:nowrap}', '.dc-menu button:hover{background:rgba(0,0,0,.05)}', '.dc-menu hr{border:0;border-top:1px solid rgba(0,0,0,.08);margin:4px 2px}', '.dc-menu .dc-danger{color:#c96442}', '.dc-menu .dc-danger:hover{background:rgba(201,100,66,.1)}',
  // Chrome (titles / labels / buttons) counter-scales against the viewport
  // zoom so it stays a constant on-screen size. --dc-inv-zoom is set by
  // DCViewport on every transform update and inherits to all descendants —
  // any overlay inside the world (e.g. a TweaksPanel on an artboard) can use
  // it the same way.
  //
  // The header uses transform:scale (out-of-flow, so layout impact doesn't
  // matter) with its world-space width set to card-width / inv-zoom so that
  // after counter-scaling its on-screen width exactly matches the card's —
  // that's what lets the container query + text-overflow behave against the
  // card's visible edge at every zoom level.
  //
  // The section head uses CSS zoom instead of transform so its layout box
  // grows with the counter-scale, pushing the card row down — otherwise the
  // constant-screen-size title would overflow into the (shrinking) world-
  // space gap and overlap the artboard headers at low zoom.
  '.dc-header{width:calc((100% + 4px) / var(--dc-inv-zoom,1));', '  transform:scale(var(--dc-inv-zoom,1));transform-origin:bottom left}', '.dc-sectionhead{zoom:var(--dc-inv-zoom,1)}'].join('\n');
  document.head.appendChild(s);
}
const DCCtx = React.createContext(null);

// Recursively unwrap React.Fragment so <>…</> grouping doesn't hide
// DCSection/DCArtboard children from the type-based walks below.
function dcFlatten(children) {
  const out = [];
  React.Children.forEach(children, c => {
    if (c && c.type === React.Fragment) out.push(...dcFlatten(c.props.children));else out.push(c);
  });
  return out;
}

// ─────────────────────────────────────────────────────────────
// DesignCanvas — stateful wrapper around the pan/zoom viewport.
// Owns runtime state (per-section order, renamed titles/labels, hidden
// artboards, focused artboard). Order/titles/labels/hidden persist to a
// .design-canvas.state.json
// sidecar next to the HTML. Reads go via plain fetch() so the saved
// arrangement is visible anywhere the HTML + sidecar are served together
// (omelette preview, direct link, downloaded zip). Writes go through the
// host's window.omelette bridge — editing requires the omelette runtime.
// Focus is ephemeral.
// ─────────────────────────────────────────────────────────────
const DC_STATE_FILE = '.design-canvas.state.json';
function DesignCanvas({
  children,
  minScale,
  maxScale,
  style
}) {
  const [state, setState] = React.useState({
    sections: {},
    focus: null
  });
  // Hold rendering until the sidecar read settles so the saved order/titles
  // appear on first paint (no source-order flash). didRead gates writes until
  // the read settles so the empty initial state can't clobber a slow read;
  // skipNextWrite suppresses the one echo-write that would otherwise follow
  // hydration.
  const [ready, setReady] = React.useState(false);
  const didRead = React.useRef(false);
  const skipNextWrite = React.useRef(false);
  React.useEffect(() => {
    let off = false;
    fetch('./' + DC_STATE_FILE).then(r => r.ok ? r.json() : null).then(saved => {
      if (off || !saved || !saved.sections) return;
      skipNextWrite.current = true;
      setState(s => ({
        ...s,
        sections: saved.sections
      }));
    }).catch(() => {}).finally(() => {
      didRead.current = true;
      if (!off) setReady(true);
    });
    const t = setTimeout(() => {
      if (!off) setReady(true);
    }, 150);
    return () => {
      off = true;
      clearTimeout(t);
    };
  }, []);
  React.useEffect(() => {
    if (!didRead.current) return;
    if (skipNextWrite.current) {
      skipNextWrite.current = false;
      return;
    }
    const t = setTimeout(() => {
      window.omelette?.writeFile(DC_STATE_FILE, JSON.stringify({
        sections: state.sections
      })).catch(() => {});
    }, 250);
    return () => clearTimeout(t);
  }, [state.sections]);

  // Build registries synchronously from children so FocusOverlay can read
  // them in the same render. Fragments are flattened; wrapping in other
  // elements still opts out of focus/reorder.
  const registry = {}; // slotId -> { sectionId, artboard }
  const sectionMeta = {}; // sectionId -> { title, subtitle, slotIds[] }
  const sectionOrder = [];
  dcFlatten(children).forEach(sec => {
    if (!sec || sec.type !== DCSection) return;
    const sid = sec.props.id ?? sec.props.title;
    if (!sid) return;
    sectionOrder.push(sid);
    const persisted = state.sections[sid] || {};
    const abs = [];
    dcFlatten(sec.props.children).forEach(ab => {
      if (!ab || ab.type !== DCArtboard) return;
      const aid = ab.props.id ?? ab.props.label;
      if (aid) abs.push([aid, ab]);
    });
    // hidden is scoped to one source revision — when the agent regenerates
    // (artboard-ID set changes), prior deletes don't apply to new content.
    const srcKey = abs.map(([k]) => k).join('\x1f');
    const hidden = persisted.srcKey === srcKey ? persisted.hidden || [] : [];
    const srcIds = [];
    abs.forEach(([aid, ab]) => {
      if (hidden.includes(aid)) return;
      registry[`${sid}/${aid}`] = {
        sectionId: sid,
        artboard: ab
      };
      srcIds.push(aid);
    });
    const kept = (persisted.order || []).filter(k => srcIds.includes(k));
    sectionMeta[sid] = {
      title: persisted.title ?? sec.props.title,
      subtitle: sec.props.subtitle,
      slotIds: [...kept, ...srcIds.filter(k => !kept.includes(k))]
    };
  });
  const api = React.useMemo(() => ({
    state,
    section: id => state.sections[id] || {},
    patchSection: (id, p) => setState(s => ({
      ...s,
      sections: {
        ...s.sections,
        [id]: {
          ...s.sections[id],
          ...(typeof p === 'function' ? p(s.sections[id] || {}) : p)
        }
      }
    })),
    setFocus: slotId => setState(s => ({
      ...s,
      focus: slotId
    }))
  }), [state]);

  // Esc exits focus; any outside pointerdown commits an in-progress rename.
  React.useEffect(() => {
    const onKey = e => {
      if (e.key === 'Escape') api.setFocus(null);
    };
    const onPd = e => {
      const ae = document.activeElement;
      if (ae && ae.isContentEditable && !ae.contains(e.target)) ae.blur();
    };
    document.addEventListener('keydown', onKey);
    document.addEventListener('pointerdown', onPd, true);
    return () => {
      document.removeEventListener('keydown', onKey);
      document.removeEventListener('pointerdown', onPd, true);
    };
  }, [api]);
  return /*#__PURE__*/React.createElement(DCCtx.Provider, {
    value: api
  }, /*#__PURE__*/React.createElement(DCViewport, {
    minScale: minScale,
    maxScale: maxScale,
    style: style
  }, ready && children), state.focus && registry[state.focus] && /*#__PURE__*/React.createElement(DCFocusOverlay, {
    entry: registry[state.focus],
    sectionMeta: sectionMeta,
    sectionOrder: sectionOrder
  }));
}

// ─────────────────────────────────────────────────────────────
// DCViewport — transform-based pan/zoom (internal)
//
// Input mapping (Figma-style):
//   • trackpad pinch  → zoom   (ctrlKey wheel; Safari gesture* events)
//   • trackpad scroll → pan    (two-finger)
//   • mouse wheel     → zoom   (notched; distinguished from trackpad scroll)
//   • middle-drag / primary-drag-on-bg → pan
//
// Transform state lives in a ref and is written straight to the DOM
// (translate3d + will-change) so wheel ticks don't go through React —
// keeps pans at 60fps on dense canvases.
// ─────────────────────────────────────────────────────────────
function DCViewport({
  children,
  minScale = 0.1,
  maxScale = 8,
  style = {}
}) {
  const vpRef = React.useRef(null);
  const worldRef = React.useRef(null);
  const tf = React.useRef({
    x: 0,
    y: 0,
    scale: 1
  });
  // Persist viewport across reloads so the user lands back where they were
  // after an agent edit or browser refresh. The sandbox origin is already
  // per-project; pathname keeps multiple canvas files in one project apart.
  const tfKey = 'dc-viewport:' + location.pathname;
  const saveT = React.useRef(0);
  const lastPostedScale = React.useRef();
  const apply = React.useCallback(() => {
    const {
      x,
      y,
      scale
    } = tf.current;
    const el = worldRef.current;
    if (!el) return;
    el.style.transform = `translate3d(${x}px, ${y}px, 0) scale(${scale})`;
    // Exposed for zoom-invariant chrome (labels, buttons, TweaksPanel).
    el.style.setProperty('--dc-inv-zoom', String(1 / scale));
    // Keep the host toolbar's % readout in sync with the canvas scale. Pan
    // ticks leave scale unchanged — skip the cross-frame post for those.
    if (lastPostedScale.current !== scale) {
      lastPostedScale.current = scale;
      window.parent.postMessage({
        type: '__dc_zoom',
        scale
      }, '*');
    }
    clearTimeout(saveT.current);
    saveT.current = setTimeout(() => {
      try {
        localStorage.setItem(tfKey, JSON.stringify(tf.current));
      } catch {}
    }, 200);
  }, [tfKey]);
  React.useLayoutEffect(() => {
    const flush = () => {
      clearTimeout(saveT.current);
      try {
        localStorage.setItem(tfKey, JSON.stringify(tf.current));
      } catch {}
    };
    let restored = false;
    try {
      const s = JSON.parse(localStorage.getItem(tfKey) || 'null');
      if (s && Number.isFinite(s.x) && Number.isFinite(s.y) && Number.isFinite(s.scale)) {
        tf.current = {
          x: s.x,
          y: s.y,
          scale: Math.min(maxScale, Math.max(minScale, s.scale))
        };
        apply();
        restored = true;
      }
    } catch {}
    // Visibility backstop (one-shot): a persisted pan is only meaningful
    // relative to content that may have changed since it was saved. If the
    // restored transform leaves every section/artboard off-screen, restoring
    // it faithfully just strands the user — reset to origin instead.
    // Content renders after the sidecar read settles, so poll briefly until
    // real boxes exist; any user input cancels (they may be mid-pan).
    let checks = 0;
    let checkT = 0;
    let sawInput = false;
    let hiddenStreak = 0;
    const onInput = () => {
      sawInput = true;
    };
    const cleanupCheck = () => {
      window.removeEventListener('wheel', onInput, true);
      window.removeEventListener('pointerdown', onInput, true);
    };
    const checkVisible = () => {
      const vp = vpRef.current,
        world = worldRef.current;
      checks += 1;
      if (!vp || !world || sawInput || checks > 10) {
        cleanupCheck();
        return;
      }
      const vr = vp.getBoundingClientRect();
      let sized = 0,
        visible = false;
      // Slots plus section-head titles: the [data-dc-section] wrapper (and
      // .dc-sectionhead) are full-width blocks whose boxes can stay
      // on-screen while everything real is stranded; the inline-block title
      // is text-sized and covers sections whose artboards were all deleted.
      world.querySelectorAll('[data-dc-slot], .dc-sectionhead .dc-editable').forEach(el => {
        const r = el.getBoundingClientRect();
        if (r.width <= 0 || r.height <= 0) return;
        sized += 1;
        if (r.right > vr.left && r.left < vr.right && r.bottom > vr.top && r.top < vr.bottom) visible = true;
      });
      if (visible) {
        cleanupCheck();
        return;
      }
      if (sized === 0) {
        hiddenStreak = 0;
        checkT = setTimeout(checkVisible, 400);
        return;
      } // not rendered yet
      // Two consecutive hidden reads before resetting — the sidecar read can
      // reorder/hide sections after first paint, transiently moving every
      // box; a single sample must not discard a healthy deliberate pan.
      hiddenStreak += 1;
      if (hiddenStreak < 2) {
        checkT = setTimeout(checkVisible, 400);
        return;
      }
      tf.current = {
        x: 0,
        y: 0,
        scale: 1
      };
      apply();
      cleanupCheck();
    };
    if (restored) {
      window.addEventListener('wheel', onInput, true);
      window.addEventListener('pointerdown', onInput, true);
      checkT = setTimeout(checkVisible, 250);
    }
    // Flush on pagehide and unmount so a reload within the 200ms debounce
    // window doesn't drop the last pan/zoom.
    window.addEventListener('pagehide', flush);
    return () => {
      clearTimeout(checkT);
      cleanupCheck();
      window.removeEventListener('pagehide', flush);
      flush();
    };
  }, []);
  React.useEffect(() => {
    const vp = vpRef.current;
    if (!vp) return;
    const zoomAt = (cx, cy, factor) => {
      const r = vp.getBoundingClientRect();
      const px = cx - r.left,
        py = cy - r.top;
      const t = tf.current;
      const next = Math.min(maxScale, Math.max(minScale, t.scale * factor));
      const k = next / t.scale;
      // --dc-inv-zoom consumers (.dc-sectionhead's CSS zoom, each section's
      // marginBottom) reflow on every scale change, vertically shifting the
      // world layout — so a world point mathematically pinned under the cursor
      // drifts as you zoom (content creeps up on zoom-in, down on zoom-out).
      // Anchor the DOM element under the cursor instead: record its screen Y,
      // apply the transform + --dc-inv-zoom, then cancel whatever vertical
      // drift the reflow introduced so it stays put on screen.
      let marker = null,
        markerY0 = 0;
      if (k !== 1) {
        const hit = document.elementFromPoint(cx, cy);
        marker = hit && hit.closest ? hit.closest('[data-dc-slot],[data-dc-section]') : null;
        if (marker) markerY0 = marker.getBoundingClientRect().top;
      }
      // keep the world point under the cursor fixed
      t.x = px - (px - t.x) * k;
      t.y = py - (py - t.y) * k;
      t.scale = next;
      apply();
      if (marker) {
        // A pure zoom around (cx, cy) maps screen Y → cy + (Y - cy) * k. Any
        // departure after the --dc-inv-zoom reflow is the layout drift.
        const drift = marker.getBoundingClientRect().top - (cy + (markerY0 - cy) * k);
        if (Math.abs(drift) > 0.1) {
          t.y -= drift;
          apply();
        }
      }
    };

    // Mouse-wheel vs trackpad-scroll heuristic. A physical wheel sends
    // line-mode deltas (Firefox) or large integer pixel deltas with no X
    // component (Chrome/Safari, typically multiples of 100/120). Trackpad
    // two-finger scroll sends small/fractional pixel deltas, often with
    // non-zero deltaX. ctrlKey is set by the browser for trackpad pinch.
    const isMouseWheel = e => e.deltaMode !== 0 || e.deltaX === 0 && Number.isInteger(e.deltaY) && Math.abs(e.deltaY) >= 40;
    const onWheel = e => {
      // A deck-stage nested on the canvas owns plain scrolling — its
      // thumbnail rail must stay natively scrollable, and panning a
      // full-viewport fixed deck only strands it. The shadow DOM retargets
      // rail events to the deck-stage host, so closest() sees it. ctrl/meta
      // pinch stays ours: unprevented it would browser-zoom the page.
      if (!(e.ctrlKey || e.metaKey) && e.target && e.target.closest && e.target.closest('deck-stage')) return;
      e.preventDefault();
      if (isGesturing) return; // Safari: gesture* owns the pinch — discard concurrent wheels
      if ((e.ctrlKey || e.metaKey) && !isMouseWheel(e)) {
        // trackpad pinch, or ctrl/cmd + smooth-scroll mouse. Notched
        // wheels fall through to the fixed-step branch below.
        zoomAt(e.clientX, e.clientY, Math.exp(-e.deltaY * 0.01));
      } else if (isMouseWheel(e)) {
        // notched mouse wheel — fixed-ratio step per click
        zoomAt(e.clientX, e.clientY, Math.exp(-Math.sign(e.deltaY) * 0.18));
      } else {
        // trackpad two-finger scroll — pan
        tf.current.x -= e.deltaX;
        tf.current.y -= e.deltaY;
        apply();
      }
    };

    // Safari sends native gesture* events for trackpad pinch with a smooth
    // e.scale; preferring these over the ctrl+wheel fallback gives a much
    // better feel there. No-ops on other browsers. Safari also fires
    // ctrlKey wheel events during the same pinch — isGesturing makes
    // onWheel drop those entirely so they neither zoom nor pan.
    let gsBase = 1;
    let isGesturing = false;
    const onGestureStart = e => {
      e.preventDefault();
      isGesturing = true;
      gsBase = tf.current.scale;
    };
    const onGestureChange = e => {
      e.preventDefault();
      zoomAt(e.clientX, e.clientY, gsBase * e.scale / tf.current.scale);
    };
    const onGestureEnd = e => {
      e.preventDefault();
      isGesturing = false;
    };

    // Drag-pan: middle button anywhere, or primary button on canvas
    // background (anything that isn't an artboard or an inline editor).
    let drag = null;
    const onPointerDown = e => {
      const onBg = !e.target.closest('[data-dc-slot], .dc-editable');
      if (!(e.button === 1 || e.button === 0 && onBg)) return;
      e.preventDefault();
      vp.setPointerCapture(e.pointerId);
      drag = {
        id: e.pointerId,
        lx: e.clientX,
        ly: e.clientY
      };
      vp.style.cursor = 'grabbing';
    };
    const onPointerMove = e => {
      if (!drag || e.pointerId !== drag.id) return;
      tf.current.x += e.clientX - drag.lx;
      tf.current.y += e.clientY - drag.ly;
      drag.lx = e.clientX;
      drag.ly = e.clientY;
      apply();
    };
    const onPointerUp = e => {
      if (!drag || e.pointerId !== drag.id) return;
      vp.releasePointerCapture(e.pointerId);
      drag = null;
      vp.style.cursor = '';
    };

    // Host-driven zoom (toolbar % menu). Zooms around viewport centre so the
    // visible midpoint stays fixed — matching the host's iframe-zoom feel.
    const onHostMsg = e => {
      const d = e.data;
      if (d && d.type === '__dc_set_zoom' && typeof d.scale === 'number') {
        const r = vp.getBoundingClientRect();
        zoomAt(r.left + r.width / 2, r.top + r.height / 2, d.scale / tf.current.scale);
      } else if (d && d.type === '__dc_probe') {
        // Host's [readyGen] reset asks whether a canvas is present; it
        // fires on the iframe's native 'load', which for canvases with
        // images/fonts is after our mount-time announce, so re-announce.
        // Clear the pan-tick guard so apply() re-posts the current scale
        // even if it's unchanged — the host just reset dcScale to 1.
        window.parent.postMessage({
          type: '__dc_present'
        }, '*');
        lastPostedScale.current = undefined;
        apply();
      }
    };
    window.addEventListener('message', onHostMsg);
    // Announce canvas mode so the host toolbar proxies its % control here
    // instead of scaling the iframe element (which would just shrink the
    // viewport window of an infinite canvas). The apply() that follows emits
    // the initial __dc_zoom so the toolbar % is correct before first pinch.
    // lastPostedScale reset mirrors the __dc_probe handler: the layout
    // effect's restore-path apply() may already have posted the restored
    // scale (before __dc_present), so clear the guard to re-post it in order.
    window.parent.postMessage({
      type: '__dc_present'
    }, '*');
    lastPostedScale.current = undefined;
    apply();
    vp.addEventListener('wheel', onWheel, {
      passive: false
    });
    vp.addEventListener('gesturestart', onGestureStart, {
      passive: false
    });
    vp.addEventListener('gesturechange', onGestureChange, {
      passive: false
    });
    vp.addEventListener('gestureend', onGestureEnd, {
      passive: false
    });
    vp.addEventListener('pointerdown', onPointerDown);
    vp.addEventListener('pointermove', onPointerMove);
    vp.addEventListener('pointerup', onPointerUp);
    vp.addEventListener('pointercancel', onPointerUp);
    return () => {
      window.removeEventListener('message', onHostMsg);
      vp.removeEventListener('wheel', onWheel);
      vp.removeEventListener('gesturestart', onGestureStart);
      vp.removeEventListener('gesturechange', onGestureChange);
      vp.removeEventListener('gestureend', onGestureEnd);
      vp.removeEventListener('pointerdown', onPointerDown);
      vp.removeEventListener('pointermove', onPointerMove);
      vp.removeEventListener('pointerup', onPointerUp);
      vp.removeEventListener('pointercancel', onPointerUp);
    };
  }, [apply, minScale, maxScale]);
  const gridSvg = `url("data:image/svg+xml,%3Csvg width='120' height='120' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M120 0H0v120' fill='none' stroke='${encodeURIComponent(DC.grid)}' stroke-width='1'/%3E%3C/svg%3E")`;
  return /*#__PURE__*/React.createElement("div", {
    ref: vpRef,
    className: "design-canvas",
    style: {
      height: '100vh',
      width: '100vw',
      background: DC.bg,
      overflow: 'hidden',
      overscrollBehavior: 'none',
      touchAction: 'none',
      position: 'relative',
      fontFamily: DC.font,
      boxSizing: 'border-box',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    ref: worldRef,
    style: {
      position: 'absolute',
      top: 0,
      left: 0,
      transformOrigin: '0 0',
      willChange: 'transform',
      width: 'max-content',
      minWidth: '100%',
      minHeight: '100%',
      padding: '60px 0 80px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: -6000,
      backgroundImage: gridSvg,
      backgroundSize: '120px 120px',
      pointerEvents: 'none',
      zIndex: -1
    }
  }), children));
}

// ─────────────────────────────────────────────────────────────
// DCSection — editable title + h-row of artboards in persisted order
// ─────────────────────────────────────────────────────────────
function DCSection({
  id,
  title,
  subtitle,
  children,
  gap = 48
}) {
  const ctx = React.useContext(DCCtx);
  const sid = id ?? title;
  const all = React.Children.toArray(dcFlatten(children));
  const artboards = all.filter(c => c && c.type === DCArtboard);
  const rest = all.filter(c => !(c && c.type === DCArtboard));
  const sec = ctx && sid && ctx.section(sid) || {};
  // Must match DesignCanvas's srcKey computation exactly (it filters falsy
  // IDs), or onDelete persists a srcKey that DesignCanvas never recognizes.
  const allIds = artboards.map(a => a.props.id ?? a.props.label).filter(Boolean);
  const srcKey = allIds.join('\x1f');
  const hidden = sec.srcKey === srcKey ? sec.hidden || [] : [];
  const srcOrder = allIds.filter(k => !hidden.includes(k));
  const order = React.useMemo(() => {
    const kept = (sec.order || []).filter(k => srcOrder.includes(k));
    return [...kept, ...srcOrder.filter(k => !kept.includes(k))];
  }, [sec.order, srcOrder.join('|')]);
  const byId = Object.fromEntries(artboards.map(a => [a.props.id ?? a.props.label, a]));

  // marginBottom counter-scales so the on-screen gap between sections stays
  // constant — otherwise at low zoom the (world-space) gap collapses while
  // the screen-constant sectionhead below it doesn't, and the title reads as
  // belonging to the section above. paddingBottom below is just enough for
  // the 24px artboard-header (abs-positioned above each card) plus ~8px, so
  // the title sits tight against its own row at every zoom.
  return /*#__PURE__*/React.createElement("div", {
    "data-dc-section": sid,
    style: {
      marginBottom: 'calc(80px * var(--dc-inv-zoom, 1))',
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 60px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "dc-sectionhead",
    style: {
      paddingBottom: 36
    }
  }, /*#__PURE__*/React.createElement(DCEditable, {
    tag: "div",
    value: sec.title ?? title,
    onChange: v => ctx && sid && ctx.patchSection(sid, {
      title: v
    }),
    style: {
      fontSize: 28,
      fontWeight: 600,
      color: DC.title,
      letterSpacing: -0.4,
      marginBottom: 6,
      display: 'inline-block'
    }
  }), subtitle && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      color: DC.subtitle
    }
  }, subtitle))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap,
      padding: '0 60px',
      alignItems: 'flex-start',
      width: 'max-content'
    }
  }, order.map(k => /*#__PURE__*/React.createElement(DCArtboardFrame, {
    key: k,
    sectionId: sid,
    artboard: byId[k],
    order: order,
    label: (sec.labels || {})[k] ?? byId[k].props.label,
    onRename: v => ctx && ctx.patchSection(sid, x => ({
      labels: {
        ...x.labels,
        [k]: v
      }
    })),
    onReorder: next => ctx && ctx.patchSection(sid, {
      order: next
    }),
    onDelete: () => ctx && ctx.patchSection(sid, x => ({
      hidden: [...(x.srcKey === srcKey ? x.hidden || [] : []), k],
      srcKey
    })),
    onFocus: () => ctx && ctx.setFocus(`${sid}/${k}`)
  }))), rest);
}

// DCArtboard — marker; rendered by DCArtboardFrame via DCSection.
function DCArtboard() {
  return null;
}

// Per-artboard export (kind: 'png' | 'html'). Both paths share the same
// self-contained clone: computed styles baked in, @font-face / <img> /
// inline-style background-image urls inlined as data URIs. PNG wraps the
// clone in foreignObject→canvas at 3× the artboard's natural width×height
// (same pipeline the host uses for page captures); HTML wraps it in a
// minimal standalone document. Both are independent of viewport zoom.
async function dcExport(node, w, h, name, kind) {
  try {
    await document.fonts.ready;
  } catch {}
  const toDataURL = url => fetch(url).then(r => r.blob()).then(b => new Promise(res => {
    const fr = new FileReader();
    fr.onload = () => res(fr.result);
    fr.onerror = () => res(url);
    fr.readAsDataURL(b);
  })).catch(() => url);

  // Collect @font-face rules. ss.cssRules throws SecurityError on
  // cross-origin sheets (e.g. fonts.googleapis.com) — in that case fetch
  // the CSS text directly (those endpoints send ACAO:*) and regex-extract
  // the blocks. @import and @media/@supports are walked so nested
  // @font-face rules aren't missed.
  const fontRules = [],
    pending = [],
    seen = new Set();
  const scrapeCss = href => {
    if (seen.has(href)) return;
    seen.add(href);
    pending.push(fetch(href).then(r => r.text()).then(css => {
      for (const m of css.match(/@font-face\s*{[^}]*}/g) || []) fontRules.push({
        css: m,
        base: href
      });
      for (const m of css.matchAll(/@import\s+(?:url\()?['"]?([^'")\s;]+)/g)) scrapeCss(new URL(m[1], href).href);
    }).catch(() => {}));
  };
  const walk = (rules, base) => {
    for (const r of rules) {
      if (r.type === CSSRule.FONT_FACE_RULE) fontRules.push({
        css: r.cssText,
        base
      });else if (r.type === CSSRule.IMPORT_RULE && r.styleSheet) {
        const ibase = r.styleSheet.href || base;
        try {
          walk(r.styleSheet.cssRules, ibase);
        } catch {
          scrapeCss(ibase);
        }
      } else if (r.cssRules) walk(r.cssRules, base);
    }
  };
  for (const ss of document.styleSheets) {
    const base = ss.href || location.href;
    try {
      walk(ss.cssRules, base);
    } catch {
      if (ss.href) scrapeCss(ss.href);
    }
  }
  while (pending.length) await pending.shift();
  const fontCss = (await Promise.all(fontRules.map(async rule => {
    let out = rule.css,
      m;
    const re = /url\((['"]?)([^'")]+)\1\)/g;
    while (m = re.exec(rule.css)) {
      if (m[2].indexOf('data:') === 0) continue;
      let abs;
      try {
        abs = new URL(m[2], rule.base).href;
      } catch {
        continue;
      }
      out = out.split(m[0]).join('url("' + (await toDataURL(abs)) + '")');
    }
    return out;
  }))).join('\n');
  const cloneStyled = src => {
    if (src.nodeType === 8 || src.nodeType === 1 && src.tagName === 'SCRIPT') return document.createTextNode('');
    const dst = src.cloneNode(false);
    if (src.nodeType === 1) {
      const cs = getComputedStyle(src);
      let txt = '';
      for (let i = 0; i < cs.length; i++) txt += cs[i] + ':' + cs.getPropertyValue(cs[i]) + ';';
      dst.setAttribute('style', txt + 'animation:none;transition:none;');
      if (src.tagName === 'CANVAS') try {
        const im = document.createElement('img');
        im.src = src.toDataURL();
        im.setAttribute('style', txt);
        return im;
      } catch {}
    }
    for (let c = src.firstChild; c; c = c.nextSibling) dst.appendChild(cloneStyled(c));
    return dst;
  };
  const clone = cloneStyled(node);
  clone.setAttribute('xmlns', 'http://www.w3.org/1999/xhtml');
  // Drop the card's own shadow/radius so the export is a flush w×h rect;
  // the artboard's own background (if any) is already in the computed style.
  clone.style.boxShadow = 'none';
  clone.style.borderRadius = '0';
  const jobs = [];
  clone.querySelectorAll('img').forEach(el => {
    const s = el.getAttribute('src');
    if (s && s.indexOf('data:') !== 0) jobs.push(toDataURL(el.src).then(d => el.setAttribute('src', d)));
  });
  [clone, ...clone.querySelectorAll('*')].forEach(el => {
    const bg = el.style.backgroundImage;
    if (!bg) return;
    let m;
    const re = /url\(["']?([^"')]+)["']?\)/g;
    while (m = re.exec(bg)) {
      const tok = m[0],
        url = m[1];
      if (url.indexOf('data:') === 0) continue;
      jobs.push(toDataURL(url).then(d => {
        el.style.backgroundImage = el.style.backgroundImage.split(tok).join('url("' + d + '")');
      }));
    }
  });
  await Promise.all(jobs);
  const xml = new XMLSerializer().serializeToString(clone);
  const save = (blob, ext) => {
    if (!blob) return;
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = name + '.' + ext;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  };
  if (kind === 'html') {
    const html = '<!doctype html><html><head><meta charset="utf-8"><title>' + name + '</title>' + (fontCss ? '<style>' + fontCss + '</style>' : '') + '</head><body style="margin:0">' + xml + '</body></html>';
    return save(new Blob([html], {
      type: 'text/html'
    }), 'html');
  }

  // PNG: the SVG's own width/height must be the output resolution — an
  // <img>-loaded SVG rasterizes at its intrinsic size, so sizing it at 1×
  // and ctx.scale()-ing up would just upscale a 1× bitmap. viewBox maps the
  // w×h foreignObject onto the px·w × px·h SVG canvas so the browser renders
  // the HTML at full resolution.
  const px = 3;
  const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + w * px + '" height="' + h * px + '" viewBox="0 0 ' + w + ' ' + h + '"><foreignObject width="' + w + '" height="' + h + '">' + (fontCss ? '<style><![CDATA[' + fontCss + ']]></style>' : '') + xml + '</foreignObject></svg>';
  const img = new Image();
  await new Promise((res, rej) => {
    img.onload = res;
    img.onerror = () => rej(new Error('svg load failed'));
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  });
  const cv = document.createElement('canvas');
  cv.width = w * px;
  cv.height = h * px;
  cv.getContext('2d').drawImage(img, 0, 0);
  cv.toBlob(blob => save(blob, 'png'), 'image/png');
}
function DCArtboardFrame({
  sectionId,
  artboard,
  label,
  order,
  onRename,
  onReorder,
  onFocus,
  onDelete
}) {
  const {
    id: rawId,
    label: rawLabel,
    width = 260,
    height = 480,
    children,
    style = {}
  } = artboard.props;
  const id = rawId ?? rawLabel;
  const ref = React.useRef(null);
  const cardRef = React.useRef(null);
  const menuRef = React.useRef(null);
  const [menuOpen, setMenuOpen] = React.useState(false);
  const [confirming, setConfirming] = React.useState(false);

  // ⋯ menu: close on any outside pointerdown. Two-click delete lives inside
  // the menu — first click arms the row, second commits; closing disarms.
  React.useEffect(() => {
    if (!menuOpen) {
      setConfirming(false);
      return;
    }
    const off = e => {
      if (!menuRef.current || !menuRef.current.contains(e.target)) setMenuOpen(false);
    };
    document.addEventListener('pointerdown', off, true);
    return () => document.removeEventListener('pointerdown', off, true);
  }, [menuOpen]);
  const doExport = kind => {
    setMenuOpen(false);
    if (!cardRef.current) return;
    const name = String(label || id || 'artboard').replace(/[^\w\s.-]+/g, '_');
    dcExport(cardRef.current, width, height, name, kind).catch(e => console.error('[design-canvas] export failed:', e));
  };

  // Live drag-reorder: dragged card sticks to cursor; siblings slide into
  // their would-be slots in real time via transforms. DOM order only
  // changes on drop.
  const onGripDown = e => {
    e.preventDefault();
    e.stopPropagation();
    const me = ref.current;
    // translateX is applied in local (pre-scale) space but pointer deltas and
    // getBoundingClientRect().left are screen-space — divide by the viewport's
    // current scale so the dragged card tracks the cursor at any zoom level.
    const scale = me.getBoundingClientRect().width / me.offsetWidth || 1;
    const peers = Array.from(document.querySelectorAll(`[data-dc-section="${sectionId}"] [data-dc-slot]`));
    const homes = peers.map(el => ({
      el,
      id: el.dataset.dcSlot,
      x: el.getBoundingClientRect().left
    }));
    const slotXs = homes.map(h => h.x);
    const startIdx = order.indexOf(id);
    const startX = e.clientX;
    let liveOrder = order.slice();
    me.classList.add('dc-dragging');
    const layout = () => {
      for (const h of homes) {
        if (h.id === id) continue;
        const slot = liveOrder.indexOf(h.id);
        h.el.style.transform = `translateX(${(slotXs[slot] - h.x) / scale}px)`;
      }
    };
    const move = ev => {
      const dx = ev.clientX - startX;
      me.style.transform = `translateX(${dx / scale}px)`;
      const cur = homes[startIdx].x + dx;
      let nearest = 0,
        best = Infinity;
      for (let i = 0; i < slotXs.length; i++) {
        const d = Math.abs(slotXs[i] - cur);
        if (d < best) {
          best = d;
          nearest = i;
        }
      }
      if (liveOrder.indexOf(id) !== nearest) {
        liveOrder = order.filter(k => k !== id);
        liveOrder.splice(nearest, 0, id);
        layout();
      }
    };
    const up = () => {
      document.removeEventListener('pointermove', move);
      document.removeEventListener('pointerup', up);
      const finalSlot = liveOrder.indexOf(id);
      me.classList.remove('dc-dragging');
      me.style.transform = `translateX(${(slotXs[finalSlot] - homes[startIdx].x) / scale}px)`;
      // After the settle transition, kill transitions + clear transforms +
      // commit the reorder in the same frame so there's no visual snap-back.
      setTimeout(() => {
        for (const h of homes) {
          h.el.style.transition = 'none';
          h.el.style.transform = '';
        }
        if (liveOrder.join('|') !== order.join('|')) onReorder(liveOrder);
        requestAnimationFrame(() => requestAnimationFrame(() => {
          for (const h of homes) h.el.style.transition = '';
        }));
      }, 180);
    };
    document.addEventListener('pointermove', move);
    document.addEventListener('pointerup', up);
  };
  return /*#__PURE__*/React.createElement("div", {
    ref: ref,
    "data-dc-slot": id,
    style: {
      position: 'relative',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "dc-header",
    "data-omelette-chrome": "",
    style: {
      color: DC.label
    },
    onPointerDown: e => e.stopPropagation()
  }, /*#__PURE__*/React.createElement("div", {
    className: "dc-labelrow"
  }, /*#__PURE__*/React.createElement("div", {
    className: "dc-grip",
    onPointerDown: onGripDown,
    title: "Drag to reorder"
  }, /*#__PURE__*/React.createElement("svg", {
    width: "9",
    height: "13",
    viewBox: "0 0 9 13",
    fill: "currentColor"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "2",
    cy: "2",
    r: "1.1"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "7",
    cy: "2",
    r: "1.1"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "2",
    cy: "6.5",
    r: "1.1"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "7",
    cy: "6.5",
    r: "1.1"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "2",
    cy: "11",
    r: "1.1"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "7",
    cy: "11",
    r: "1.1"
  }))), /*#__PURE__*/React.createElement("div", {
    className: "dc-labeltext",
    onClick: onFocus,
    title: "Click to focus"
  }, /*#__PURE__*/React.createElement(DCEditable, {
    value: label,
    onChange: onRename,
    onClick: e => e.stopPropagation(),
    style: {
      fontSize: 15,
      fontWeight: 500,
      color: DC.label,
      lineHeight: 1
    }
  }))), /*#__PURE__*/React.createElement("div", {
    className: "dc-btns"
  }, /*#__PURE__*/React.createElement("div", {
    ref: menuRef,
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "dc-kebab",
    title: "More",
    onClick: () => setMenuOpen(o => !o)
  }, /*#__PURE__*/React.createElement("svg", {
    width: "12",
    height: "12",
    viewBox: "0 0 12 12",
    fill: "currentColor"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "2.5",
    cy: "6",
    r: "1.1"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "6",
    cy: "6",
    r: "1.1"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "9.5",
    cy: "6",
    r: "1.1"
  }))), menuOpen && /*#__PURE__*/React.createElement("div", {
    className: "dc-menu",
    onPointerDown: e => e.stopPropagation()
  }, /*#__PURE__*/React.createElement("button", {
    onClick: () => doExport('png')
  }, "Download PNG"), /*#__PURE__*/React.createElement("button", {
    onClick: () => doExport('html')
  }, "Download HTML"), /*#__PURE__*/React.createElement("hr", null), /*#__PURE__*/React.createElement("button", {
    className: "dc-danger",
    onClick: () => {
      if (confirming) {
        setMenuOpen(false);
        onDelete();
      } else setConfirming(true);
    }
  }, confirming ? 'Click again to delete' : 'Delete'))), /*#__PURE__*/React.createElement("button", {
    className: "dc-expand",
    onClick: onFocus,
    title: "Focus"
  }, /*#__PURE__*/React.createElement("svg", {
    width: "12",
    height: "12",
    viewBox: "0 0 12 12",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.6",
    strokeLinecap: "round"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M7 1h4v4M5 11H1V7M11 1L7.5 4.5M1 11l3.5-3.5"
  }))))), /*#__PURE__*/React.createElement("div", {
    ref: cardRef,
    className: "dc-card",
    style: {
      borderRadius: 2,
      boxShadow: '0 1px 3px rgba(0,0,0,.08),0 4px 16px rgba(0,0,0,.06)',
      overflow: 'hidden',
      width,
      height,
      background: '#fff',
      ...style
    }
  }, children || /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: '#bbb',
      fontSize: 13,
      fontFamily: DC.font
    }
  }, id)));
}

// Inline rename — commits on blur or Enter.
function DCEditable({
  value,
  onChange,
  style,
  tag = 'span',
  onClick
}) {
  const T = tag;
  return /*#__PURE__*/React.createElement(T, {
    className: "dc-editable",
    contentEditable: true,
    suppressContentEditableWarning: true,
    onClick: onClick,
    onPointerDown: e => e.stopPropagation(),
    onBlur: e => onChange && onChange(e.currentTarget.textContent),
    onKeyDown: e => {
      if (e.key === 'Enter') {
        e.preventDefault();
        e.currentTarget.blur();
      }
    },
    style: style
  }, value);
}

// ─────────────────────────────────────────────────────────────
// Focus mode — overlay one artboard; ←/→ within section, ↑/↓ across
// sections, Esc or backdrop click to exit.
// ─────────────────────────────────────────────────────────────
function DCFocusOverlay({
  entry,
  sectionMeta,
  sectionOrder
}) {
  const ctx = React.useContext(DCCtx);
  const {
    sectionId,
    artboard
  } = entry;
  const sec = ctx.section(sectionId);
  const meta = sectionMeta[sectionId];
  const peers = meta.slotIds;
  const aid = artboard.props.id ?? artboard.props.label;
  const idx = peers.indexOf(aid);
  const secIdx = sectionOrder.indexOf(sectionId);
  const go = d => {
    const n = peers[(idx + d + peers.length) % peers.length];
    if (n) ctx.setFocus(`${sectionId}/${n}`);
  };
  const goSection = d => {
    // Sections whose artboards are all deleted have slotIds:[] — step past
    // them to the next non-empty section so ↑/↓ doesn't dead-end.
    const n = sectionOrder.length;
    for (let i = 1; i < n; i++) {
      const ns = sectionOrder[((secIdx + d * i) % n + n) % n];
      const first = sectionMeta[ns] && sectionMeta[ns].slotIds[0];
      if (first) {
        ctx.setFocus(`${ns}/${first}`);
        return;
      }
    }
  };
  React.useEffect(() => {
    const k = e => {
      if (e.key === 'ArrowLeft') {
        e.preventDefault();
        go(-1);
      }
      if (e.key === 'ArrowRight') {
        e.preventDefault();
        go(1);
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        goSection(-1);
      }
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        goSection(1);
      }
    };
    document.addEventListener('keydown', k);
    return () => document.removeEventListener('keydown', k);
  });
  const {
    width = 260,
    height = 480,
    children
  } = artboard.props;
  const [vp, setVp] = React.useState({
    w: window.innerWidth,
    h: window.innerHeight
  });
  React.useEffect(() => {
    const r = () => setVp({
      w: window.innerWidth,
      h: window.innerHeight
    });
    window.addEventListener('resize', r);
    return () => window.removeEventListener('resize', r);
  }, []);
  const scale = Math.max(0.1, Math.min((vp.w - 200) / width, (vp.h - 260) / height, 2));
  const [ddOpen, setDd] = React.useState(false);
  const Arrow = ({
    dir,
    onClick
  }) => /*#__PURE__*/React.createElement("button", {
    onClick: e => {
      e.stopPropagation();
      onClick();
    },
    style: {
      position: 'absolute',
      top: '50%',
      [dir]: 28,
      transform: 'translateY(-50%)',
      border: 'none',
      background: 'rgba(255,255,255,.08)',
      color: 'rgba(255,255,255,.9)',
      width: 44,
      height: 44,
      borderRadius: 22,
      fontSize: 18,
      cursor: 'pointer',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      transition: 'background .15s'
    },
    onMouseEnter: e => e.currentTarget.style.background = 'rgba(255,255,255,.18)',
    onMouseLeave: e => e.currentTarget.style.background = 'rgba(255,255,255,.08)'
  }, /*#__PURE__*/React.createElement("svg", {
    width: "18",
    height: "18",
    viewBox: "0 0 18 18",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "2",
    strokeLinecap: "round"
  }, /*#__PURE__*/React.createElement("path", {
    d: dir === 'left' ? 'M11 3L5 9l6 6' : 'M7 3l6 6-6 6'
  })));

  // Portal to body so position:fixed is the real viewport regardless of any
  // transform on DesignCanvas's ancestors (including the canvas zoom itself).
  return ReactDOM.createPortal(/*#__PURE__*/React.createElement("div", {
    onClick: () => ctx.setFocus(null),
    onWheel: e => e.preventDefault(),
    style: {
      position: 'fixed',
      inset: 0,
      zIndex: 100,
      background: 'rgba(24,20,16,.6)',
      backdropFilter: 'blur(14px)',
      fontFamily: DC.font,
      color: '#fff'
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      height: 72,
      display: 'flex',
      alignItems: 'flex-start',
      padding: '16px 20px 0',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: () => setDd(o => !o),
    style: {
      border: 'none',
      background: 'transparent',
      color: '#fff',
      cursor: 'pointer',
      padding: '6px 8px',
      borderRadius: 6,
      textAlign: 'left',
      fontFamily: 'inherit'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 18,
      fontWeight: 600,
      letterSpacing: -0.3
    }
  }, meta.title), /*#__PURE__*/React.createElement("svg", {
    width: "11",
    height: "11",
    viewBox: "0 0 11 11",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    style: {
      opacity: .7
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M2 4l3.5 3.5L9 4"
  }))), meta.subtitle && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: 13,
      opacity: .6,
      fontWeight: 400,
      marginTop: 2
    }
  }, meta.subtitle)), ddOpen && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: '100%',
      left: 0,
      marginTop: 4,
      background: '#2a251f',
      borderRadius: 8,
      boxShadow: '0 8px 32px rgba(0,0,0,.4)',
      padding: 4,
      minWidth: 200,
      zIndex: 10
    }
  }, sectionOrder.filter(sid => sectionMeta[sid].slotIds.length).map(sid => /*#__PURE__*/React.createElement("button", {
    key: sid,
    onClick: () => {
      setDd(false);
      const f = sectionMeta[sid].slotIds[0];
      if (f) ctx.setFocus(`${sid}/${f}`);
    },
    style: {
      display: 'block',
      width: '100%',
      textAlign: 'left',
      border: 'none',
      cursor: 'pointer',
      background: sid === sectionId ? 'rgba(255,255,255,.1)' : 'transparent',
      color: '#fff',
      padding: '8px 12px',
      borderRadius: 5,
      fontSize: 14,
      fontWeight: sid === sectionId ? 600 : 400,
      fontFamily: 'inherit'
    }
  }, sectionMeta[sid].title)))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("button", {
    onClick: () => ctx.setFocus(null),
    onMouseEnter: e => e.currentTarget.style.background = 'rgba(255,255,255,.12)',
    onMouseLeave: e => e.currentTarget.style.background = 'transparent',
    style: {
      border: 'none',
      background: 'transparent',
      color: 'rgba(255,255,255,.7)',
      width: 32,
      height: 32,
      borderRadius: 16,
      fontSize: 20,
      cursor: 'pointer',
      lineHeight: 1,
      transition: 'background .12s'
    }
  }, "\xD7")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 64,
      bottom: 56,
      left: 100,
      right: 100,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      width: width * scale,
      height: height * scale,
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width,
      height,
      transform: `scale(${scale})`,
      transformOrigin: 'top left',
      background: '#fff',
      borderRadius: 2,
      overflow: 'hidden',
      boxShadow: '0 20px 80px rgba(0,0,0,.4)'
    }
  }, children || /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: '#bbb'
    }
  }, aid))), /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      fontSize: 14,
      fontWeight: 500,
      opacity: .85,
      textAlign: 'center'
    }
  }, (sec.labels || {})[aid] ?? artboard.props.label, /*#__PURE__*/React.createElement("span", {
    style: {
      opacity: .5,
      marginLeft: 10,
      fontVariantNumeric: 'tabular-nums'
    }
  }, idx + 1, " / ", peers.length))), /*#__PURE__*/React.createElement(Arrow, {
    dir: "left",
    onClick: () => go(-1)
  }), /*#__PURE__*/React.createElement(Arrow, {
    dir: "right",
    onClick: () => go(1)
  }), /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      position: 'absolute',
      bottom: 20,
      left: '50%',
      transform: 'translateX(-50%)',
      display: 'flex',
      gap: 8
    }
  }, peers.map((p, i) => /*#__PURE__*/React.createElement("button", {
    key: p,
    onClick: () => ctx.setFocus(`${sectionId}/${p}`),
    style: {
      border: 'none',
      padding: 0,
      cursor: 'pointer',
      width: 6,
      height: 6,
      borderRadius: 3,
      background: i === idx ? '#fff' : 'rgba(255,255,255,.3)'
    }
  })))), document.body);
}

// ─────────────────────────────────────────────────────────────
// Post-it — absolute-positioned sticky note
// ─────────────────────────────────────────────────────────────
function DCPostIt({
  children,
  top,
  left,
  right,
  bottom,
  rotate = -2,
  width = 180
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top,
      left,
      right,
      bottom,
      width,
      background: DC.postitBg,
      padding: '14px 16px',
      fontFamily: '"Comic Sans MS", "Marker Felt", "Segoe Print", cursive',
      fontSize: 14,
      lineHeight: 1.4,
      color: DC.postitText,
      boxShadow: '0 2px 8px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08)',
      transform: `rotate(${rotate}deg)`,
      zIndex: 5
    }
  }, children);
}
Object.assign(window, {
  DesignCanvas,
  DCSection,
  DCArtboard,
  DCPostIt
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "explorations/design-canvas.jsx", error: String((e && e.message) || e) }); }

// ui_kits/liive-ride/MapCanvas.jsx
try { (() => {
/* Liive Ride — MapCanvas
   A stylised dark Mapbox-style map used as the persistent background behind
   every screen. Pure SVG + DS MapMarkers. No live tiles. */
(function () {
  const DS = () => window.LiiveRideDesignSystem_b6f128 || {};
  function MapCanvas({
    phase,
    multiLeg,
    carT = 0
  }) {
    const {
      MapMarker
    } = DS();

    // route geometry (in the 402x740 map area)
    const origin = {
      x: 196,
      y: 470
    };
    const dest = {
      x: 250,
      y: 165
    };
    const transfer = {
      x: 150,
      y: 320
    };

    // single vs multi-leg route path
    const routePath = multiLeg ? `M${origin.x},${origin.y} C 150,430 120,380 ${transfer.x},${transfer.y} C 175,285 230,230 ${dest.x},${dest.y}` : `M${origin.x},${origin.y} C 170,400 300,330 ${dest.x},${dest.y}`;

    // car position interpolated along a simple eased point set
    const carPts = multiLeg ? [origin, {
      x: 150,
      y: 400
    }, transfer, {
      x: 205,
      y: 250
    }, dest] : [origin, {
      x: 215,
      y: 390
    }, {
      x: 285,
      y: 300
    }, dest];
    const seg = Math.min(carPts.length - 2, Math.floor(carT * (carPts.length - 1)));
    const local = carT * (carPts.length - 1) - seg;
    const a = carPts[seg],
      b = carPts[seg + 1] || carPts[carPts.length - 1];
    const car = {
      x: a.x + (b.x - a.x) * local,
      y: a.y + (b.y - a.y) * local
    };
    const showRoute = phase !== "destination";
    const showCar = phase === "enroute";
    const showDest = phase !== "destination";
    return /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        inset: 0,
        overflow: "hidden",
        background: "var(--map-bg)"
      }
    }, /*#__PURE__*/React.createElement("svg", {
      viewBox: "0 0 402 740",
      preserveAspectRatio: "xMidYMid slice",
      style: {
        position: "absolute",
        inset: 0,
        width: "100%",
        height: "100%"
      }
    }, /*#__PURE__*/React.createElement("defs", null, /*#__PURE__*/React.createElement("filter", {
      id: "routeShadow",
      x: "-20%",
      y: "-20%",
      width: "140%",
      height: "140%"
    }, /*#__PURE__*/React.createElement("feDropShadow", {
      dx: "0",
      dy: "2",
      stdDeviation: "3",
      floodColor: "#000",
      floodOpacity: "0.35"
    }))), /*#__PURE__*/React.createElement("rect", {
      x: "-40",
      y: "540",
      width: "220",
      height: "260",
      fill: "var(--map-water)",
      opacity: "0.9",
      transform: "rotate(-8 70 670)"
    }), /*#__PURE__*/React.createElement("rect", {
      x: "250",
      y: "40",
      width: "240",
      height: "180",
      rx: "10",
      fill: "#222a22",
      opacity: "0.55"
    }), /*#__PURE__*/React.createElement("rect", {
      x: "-20",
      y: "120",
      width: "150",
      height: "150",
      rx: "8",
      fill: "#2a2722",
      opacity: "0.5"
    }), /*#__PURE__*/React.createElement("g", {
      stroke: "var(--map-road)",
      strokeWidth: "9",
      strokeLinecap: "round",
      opacity: "0.95"
    }, /*#__PURE__*/React.createElement("line", {
      x1: "-20",
      y1: "250",
      x2: "430",
      y2: "225"
    }), /*#__PURE__*/React.createElement("line", {
      x1: "-20",
      y1: "370",
      x2: "430",
      y2: "350"
    }), /*#__PURE__*/React.createElement("line", {
      x1: "-20",
      y1: "500",
      x2: "430",
      y2: "520"
    }), /*#__PURE__*/React.createElement("line", {
      x1: "-20",
      y1: "630",
      x2: "430",
      y2: "650"
    }), /*#__PURE__*/React.createElement("line", {
      x1: "70",
      y1: "-20",
      x2: "120",
      y2: "780"
    }), /*#__PURE__*/React.createElement("line", {
      x1: "210",
      y1: "-20",
      x2: "240",
      y2: "780"
    }), /*#__PURE__*/React.createElement("line", {
      x1: "330",
      y1: "-20",
      x2: "360",
      y2: "780"
    })), /*#__PURE__*/React.createElement("g", {
      stroke: "var(--map-road)",
      strokeWidth: "4",
      strokeLinecap: "round",
      opacity: "0.6"
    }, /*#__PURE__*/React.createElement("line", {
      x1: "-20",
      y1: "180",
      x2: "430",
      y2: "165"
    }), /*#__PURE__*/React.createElement("line", {
      x1: "-20",
      y1: "430",
      x2: "430",
      y2: "445"
    }), /*#__PURE__*/React.createElement("line", {
      x1: "140",
      y1: "-20",
      x2: "170",
      y2: "780"
    }), /*#__PURE__*/React.createElement("line", {
      x1: "280",
      y1: "-20",
      x2: "305",
      y2: "780"
    })), showRoute && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("path", {
      d: routePath,
      fill: "none",
      stroke: "var(--map-route)",
      strokeWidth: "7",
      strokeLinecap: "round",
      filter: "url(#routeShadow)"
    }), multiLeg && /*#__PURE__*/React.createElement("circle", {
      cx: transfer.x,
      cy: transfer.y,
      r: "5",
      fill: "#fff",
      stroke: "var(--warning)",
      strokeWidth: "3"
    }))), /*#__PURE__*/React.createElement(Layer, null, phase === "destination" && /*#__PURE__*/React.createElement(Pos, {
      x: origin.x,
      y: origin.y
    }, /*#__PURE__*/React.createElement(Pulse, null)), showRoute && !showCar && /*#__PURE__*/React.createElement(Pos, {
      x: origin.x,
      y: origin.y
    }, /*#__PURE__*/React.createElement(DS_Marker, {
      kind: "origin",
      label: "Pickup"
    })), showCar && /*#__PURE__*/React.createElement(Pos, {
      x: car.x,
      y: car.y
    }, /*#__PURE__*/React.createElement(DS_Marker, {
      kind: "car",
      label: multiLeg ? "Leg 2 · 3 min" : "4 min"
    })), multiLeg && showRoute && /*#__PURE__*/React.createElement(Pos, {
      x: transfer.x,
      y: transfer.y
    }, /*#__PURE__*/React.createElement(DS_Marker, {
      kind: "transfer",
      label: "Transfer"
    })), showDest && /*#__PURE__*/React.createElement(Pos, {
      x: dest.x,
      y: dest.y
    }, /*#__PURE__*/React.createElement(DS_Marker, {
      kind: "destination",
      label: "Union Square"
    }))), phase === "matching" && /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        left: "48.7%",
        top: "63.5%",
        transform: "translate(-50%,-50%)",
        width: 14,
        height: 14
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        position: "absolute",
        inset: 0,
        borderRadius: "50%",
        background: "var(--accent)",
        border: "3px solid #fff",
        boxShadow: "var(--shadow-pin)"
      }
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        position: "absolute",
        inset: 0,
        borderRadius: "50%",
        background: "var(--accent)",
        animation: "liive-radar 1.8s ease-out infinite"
      }
    })), /*#__PURE__*/React.createElement("style", null, "@keyframes liive-radar{0%{transform:scale(1);opacity:.5}100%{transform:scale(9);opacity:0}}"));
    function DS_Marker(props) {
      return MapMarker ? /*#__PURE__*/React.createElement(MapMarker, props) : null;
    }
  }

  // position helpers translate 402x740 coords into % of container
  function Layer({
    children
  }) {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        inset: 0
      }
    }, children);
  }
  function Pos({
    x,
    y,
    children
  }) {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        left: `${x / 402 * 100}%`,
        top: `${y / 740 * 100}%`,
        transform: "translate(-50%,-100%)"
      }
    }, children);
  }
  function Pulse() {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        position: "relative",
        width: 22,
        height: 22,
        transform: "translateY(11px)"
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        position: "absolute",
        inset: 0,
        borderRadius: "50%",
        background: "var(--accent)",
        border: "3px solid #fff",
        boxShadow: "var(--shadow-pin)"
      }
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        position: "absolute",
        inset: -4,
        borderRadius: "50%",
        background: "var(--accent-tint)",
        animation: "liive-radar2 2s ease-out infinite"
      }
    }), /*#__PURE__*/React.createElement("style", null, "@keyframes liive-radar2{0%{transform:scale(1);opacity:.6}100%{transform:scale(3);opacity:0}}"));
  }
  window.MapCanvas = MapCanvas;
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/liive-ride/MapCanvas.jsx", error: String((e && e.message) || e) }); }

// ui_kits/liive-ride/RideApp.jsx
try { (() => {
/* Liive Ride — app orchestrator (state machine + persistent map + chrome) */
(function () {
  const DS = () => window.LiiveRideDesignSystem_b6f128 || {};
  const Icon = (name, style) => /*#__PURE__*/React.createElement("i", {
    "data-lucide": name,
    style: style
  });
  const LS = "liive-ride-state";
  function RideApp() {
    const {
      GlassPanel,
      Badge,
      SOSButton,
      Button
    } = DS();
    const [screen, setScreen] = React.useState("destination");
    const [dest, setDest] = React.useState(null);
    const [paid, setPaid] = React.useState(false);
    const [mic, setMic] = React.useState(true);
    const [carT, setCarT] = React.useState(0);
    const [sos, setSos] = React.useState(false);
    const [config, setConfig] = React.useState({
      tier: "premium",
      price: 12.5,
      eta: "8 min",
      multiLeg: false,
      passengers: 1,
      bags: 1,
      femaleOnly: false,
      childSeat: false,
      destName: "Union Square"
    });

    // restore
    React.useEffect(() => {
      try {
        const s = JSON.parse(localStorage.getItem(LS) || "null");
        if (s) {
          setScreen(s.screen || "destination");
          if (s.config) setConfig(s.config);
          if (s.dest) setDest(s.dest);
        }
      } catch (e) {}
    }, []);
    // persist
    React.useEffect(() => {
      localStorage.setItem(LS, JSON.stringify({
        screen,
        config,
        dest
      }));
    }, [screen, config, dest]);

    // refresh icons after every render
    React.useEffect(() => {
      const id = setTimeout(() => window.lucide && window.lucide.createIcons(), 0);
      return () => clearTimeout(id);
    });

    // matching -> enroute
    React.useEffect(() => {
      if (screen !== "matching") return;
      const id = setTimeout(() => {
        setCarT(0);
        setScreen("enroute");
      }, 2600);
      return () => clearTimeout(id);
    }, [screen]);

    // car animation during enroute -> complete
    React.useEffect(() => {
      if (screen !== "enroute") return;
      let raf, start;
      const dur = 11000;
      const tick = t => {
        if (!start) start = t;
        const p = Math.min(1, (t - start) / dur);
        setCarT(p);
        if (p < 1) raf = requestAnimationFrame(tick);else setTimeout(() => setScreen("complete"), 700);
      };
      raf = requestAnimationFrame(tick);
      return () => cancelAnimationFrame(raf);
    }, [screen]);
    const go = s => setScreen(s);
    const reset = () => {
      setPaid(false);
      setDest(null);
      setCarT(0);
      setScreen("destination");
    };
    const phaseForMap = screen === "complete" ? "enroute" : screen;
    return /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        inset: 0,
        overflow: "hidden",
        background: "var(--bg)"
      }
    }, window.MapCanvas && /*#__PURE__*/React.createElement(window.MapCanvas, {
      phase: phaseForMap,
      multiLeg: config.multiLeg,
      carT: carT
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        inset: 0,
        background: screen === "complete" ? "rgba(0,0,0,0.35)" : "transparent",
        transition: "background 300ms",
        pointerEvents: "none"
      }
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        top: 58,
        left: 16,
        right: 16,
        display: "flex",
        alignItems: "flex-start",
        justifyContent: "space-between",
        zIndex: 20,
        pointerEvents: "none"
      }
    }, screen === "enroute" ? /*#__PURE__*/React.createElement(GlassPanel, {
      material: "thin",
      radius: "var(--radius-full)",
      padding: "7px 12px",
      style: {
        display: "inline-flex",
        alignItems: "center",
        pointerEvents: "auto"
      }
    }, /*#__PURE__*/React.createElement(Badge, {
      color: "success",
      dot: true
    }, "Voice connected")) : /*#__PURE__*/React.createElement("span", null), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        gap: 8,
        pointerEvents: "auto"
      }
    }, screen === "enroute" && /*#__PURE__*/React.createElement(GlassPill, {
      onClick: () => setMic(m => !m)
    }, Icon(mic ? "mic" : "mic-off", {
      width: 19,
      height: 19,
      color: mic ? "var(--text)" : "var(--danger)"
    })), /*#__PURE__*/React.createElement(GlassPill, null, /*#__PURE__*/React.createElement("span", {
      style: {
        display: "inline-flex"
      }
    }, Icon("locate-fixed", {
      width: 19,
      height: 19,
      color: "var(--accent)"
    }))))), (screen === "enroute" || screen === "matching") && SOSButton && /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        right: 16,
        top: 116,
        zIndex: 25
      }
    }, /*#__PURE__*/React.createElement(SOSButton, {
      size: 54,
      onActivate: () => setSos(true)
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        left: 0,
        right: 0,
        bottom: 0,
        zIndex: 30
      }
    }, screen === "destination" && /*#__PURE__*/React.createElement(window.DestinationSheet, {
      onPick: p => {
        setDest(p);
        setConfig(c => ({
          ...c,
          destName: p.title
        }));
        go("options");
      }
    }), screen === "options" && /*#__PURE__*/React.createElement(window.OptionsSheet, {
      dest: dest,
      config: config,
      setConfig: setConfig,
      onBack: () => go("destination"),
      onConfirm: () => go("matching")
    }), screen === "matching" && /*#__PURE__*/React.createElement(window.MatchingSheet, {
      config: config,
      onCancel: () => go("options")
    }), screen === "enroute" && /*#__PURE__*/React.createElement(window.EnrouteSheet, {
      config: config,
      onMessage: () => {},
      onCancel: () => reset()
    }), screen === "complete" && /*#__PURE__*/React.createElement(window.CompleteSheet, {
      config: config,
      paid: paid,
      onPay: () => setPaid(true),
      onDone: reset
    })), sos && /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        inset: 0,
        zIndex: 60,
        background: "rgba(0,0,0,0.55)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 28
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        background: "var(--surface)",
        borderRadius: "var(--radius-xl)",
        padding: 22,
        textAlign: "center",
        maxWidth: 300
      }
    }, /*#__PURE__*/React.createElement("div", {
      className: "t-title3",
      style: {
        color: "var(--text)"
      }
    }, "Emergency Alert"), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 14,
        color: "var(--text-secondary)",
        margin: "10px 0 18px"
      }
    }, "This will immediately alert emergency services and your emergency contacts. Are you sure?"), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        flexDirection: "column",
        gap: 8
      }
    }, Button && /*#__PURE__*/React.createElement(Button, {
      variant: "destructive",
      size: "lg",
      shape: "capsule",
      fullWidth: true,
      onClick: () => setSos(false)
    }, "Call Emergency Services"), Button && /*#__PURE__*/React.createElement(Button, {
      variant: "plain",
      onClick: () => setSos(false)
    }, "Cancel")))));
  }
  function GlassPill({
    children,
    onClick
  }) {
    const {
      GlassPanel
    } = DS();
    return /*#__PURE__*/React.createElement(GlassPanel, {
      material: "thin",
      radius: "var(--radius-full)",
      padding: 0,
      style: {
        width: 44,
        height: 44,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        cursor: "pointer",
        pointerEvents: "auto"
      },
      onClick: onClick
    }, children);
  }
  window.RideApp = RideApp;
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/liive-ride/RideApp.jsx", error: String((e && e.message) || e) }); }

// ui_kits/liive-ride/ios-frame.jsx
try { (() => {
// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)

/* BEGIN USAGE */
// iOS.jsx — Simplified iOS 26 (Liquid Glass) device frame
// Based on the iOS 26 UI Kit + Figma status bar spec. No assets, no deps.
// Exports (to window): IOSDevice, IOSStatusBar, IOSNavBar, IOSGlassPill, IOSList, IOSListRow, IOSKeyboard
//
// Usage — wrap your screen content in <IOSDevice> to get the bezel, status bar
// and home indicator (props: title, dark, keyboard):
//
//   <IOSDevice title="Settings">
//     ...your screen content...
//   </IOSDevice>
//   <IOSDevice dark title="Search" keyboard>…</IOSDevice>
/* END USAGE */

// ─────────────────────────────────────────────────────────────
// Status bar
// ─────────────────────────────────────────────────────────────
function IOSStatusBar({
  dark = false,
  time = '9:41'
}) {
  const c = dark ? '#fff' : '#000';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 154,
      alignItems: 'center',
      justifyContent: 'center',
      padding: '21px 24px 19px',
      boxSizing: 'border-box',
      position: 'relative',
      zIndex: 20,
      width: '100%'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 22,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      paddingTop: 1.5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: '-apple-system, "SF Pro", system-ui',
      fontWeight: 590,
      fontSize: 17,
      lineHeight: '22px',
      color: c
    }
  }, time)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 22,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 7,
      paddingTop: 1,
      paddingRight: 1
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: "19",
    height: "12",
    viewBox: "0 0 19 12"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "0",
    y: "7.5",
    width: "3.2",
    height: "4.5",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "4.8",
    y: "5",
    width: "3.2",
    height: "7",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "9.6",
    y: "2.5",
    width: "3.2",
    height: "9.5",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "14.4",
    y: "0",
    width: "3.2",
    height: "12",
    rx: "0.7",
    fill: c
  })), /*#__PURE__*/React.createElement("svg", {
    width: "17",
    height: "12",
    viewBox: "0 0 17 12"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z",
    fill: c
  }), /*#__PURE__*/React.createElement("path", {
    d: "M8.5 6.8C9.9 6.8 11.1 7.3 12 8.2L13.1 7.1C11.8 5.9 10.2 5.1 8.5 5.1C6.8 5.1 5.2 5.9 3.9 7.1L5 8.2C5.9 7.3 7.1 6.8 8.5 6.8Z",
    fill: c
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "8.5",
    cy: "10.5",
    r: "1.5",
    fill: c
  })), /*#__PURE__*/React.createElement("svg", {
    width: "27",
    height: "13",
    viewBox: "0 0 27 13"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "0.5",
    y: "0.5",
    width: "23",
    height: "12",
    rx: "3.5",
    stroke: c,
    strokeOpacity: "0.35",
    fill: "none"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "2",
    y: "2",
    width: "20",
    height: "9",
    rx: "2",
    fill: c
  }), /*#__PURE__*/React.createElement("path", {
    d: "M25 4.5V8.5C25.8 8.2 26.5 7.2 26.5 6.5C26.5 5.8 25.8 4.8 25 4.5Z",
    fill: c,
    fillOpacity: "0.4"
  }))));
}

// ─────────────────────────────────────────────────────────────
// Liquid glass pill — blur + tint + shine
// ─────────────────────────────────────────────────────────────
function IOSGlassPill({
  children,
  dark = false,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 44,
      minWidth: 44,
      borderRadius: 9999,
      position: 'relative',
      overflow: 'hidden',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      boxShadow: dark ? '0 2px 6px rgba(0,0,0,0.35), 0 6px 16px rgba(0,0,0,0.2)' : '0 1px 3px rgba(0,0,0,0.07), 0 3px 10px rgba(0,0,0,0.06)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 9999,
      backdropFilter: 'blur(12px) saturate(180%)',
      WebkitBackdropFilter: 'blur(12px) saturate(180%)',
      background: dark ? 'rgba(120,120,128,0.28)' : 'rgba(255,255,255,0.5)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 9999,
      boxShadow: dark ? 'inset 1.5px 1.5px 1px rgba(255,255,255,0.15), inset -1px -1px 1px rgba(255,255,255,0.08)' : 'inset 1.5px 1.5px 1px rgba(255,255,255,0.7), inset -1px -1px 1px rgba(255,255,255,0.4)',
      border: dark ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(0,0,0,0.06)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 1,
      display: 'flex',
      alignItems: 'center',
      padding: '0 4px'
    }
  }, children));
}

// ─────────────────────────────────────────────────────────────
// Navigation bar — glass pills + large title
// ─────────────────────────────────────────────────────────────
function IOSNavBar({
  title = 'Title',
  dark = false,
  trailingIcon = true
}) {
  const muted = dark ? 'rgba(255,255,255,0.6)' : '#404040';
  const text = dark ? '#fff' : '#000';
  const pillIcon = content => /*#__PURE__*/React.createElement(IOSGlassPill, {
    dark: dark
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 36,
      height: 36,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, content));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      paddingTop: 62,
      paddingBottom: 10,
      position: 'relative',
      zIndex: 5
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 16px'
    }
  }, pillIcon(/*#__PURE__*/React.createElement("svg", {
    width: "12",
    height: "20",
    viewBox: "0 0 12 20",
    fill: "none",
    style: {
      marginLeft: -1
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M10 2L2 10l8 8",
    stroke: muted,
    strokeWidth: "2.5",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }))), trailingIcon && pillIcon(/*#__PURE__*/React.createElement("svg", {
    width: "22",
    height: "6",
    viewBox: "0 0 22 6"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "3",
    cy: "3",
    r: "2.5",
    fill: muted
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "3",
    r: "2.5",
    fill: muted
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "19",
    cy: "3",
    r: "2.5",
    fill: muted
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px',
      fontFamily: '-apple-system, system-ui',
      fontSize: 34,
      fontWeight: 700,
      lineHeight: '41px',
      color: text,
      letterSpacing: 0.4
    }
  }, title));
}

// ─────────────────────────────────────────────────────────────
// Grouped list (inset card, r:26) + row (52px)
// ─────────────────────────────────────────────────────────────
function IOSListRow({
  title,
  detail,
  icon,
  chevron = true,
  isLast = false,
  dark = false
}) {
  const text = dark ? '#fff' : '#000';
  const sec = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const ter = dark ? 'rgba(235,235,245,0.3)' : 'rgba(60,60,67,0.3)';
  const sep = dark ? 'rgba(84,84,88,0.65)' : 'rgba(60,60,67,0.12)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      minHeight: 52,
      padding: '0 16px',
      position: 'relative',
      fontFamily: '-apple-system, system-ui',
      fontSize: 17,
      letterSpacing: -0.43
    }
  }, icon && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 30,
      height: 30,
      borderRadius: 7,
      background: icon,
      marginRight: 12,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      color: text
    }
  }, title), detail && /*#__PURE__*/React.createElement("span", {
    style: {
      color: sec,
      marginRight: 6
    }
  }, detail), chevron && /*#__PURE__*/React.createElement("svg", {
    width: "8",
    height: "14",
    viewBox: "0 0 8 14",
    style: {
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1 1l6 6-6 6",
    stroke: ter,
    strokeWidth: "2",
    fill: "none",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  })), !isLast && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      right: 0,
      left: icon ? 58 : 16,
      height: 0.5,
      background: sep
    }
  }));
}
function IOSList({
  header,
  children,
  dark = false
}) {
  const hc = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const bg = dark ? '#1C1C1E' : '#fff';
  return /*#__PURE__*/React.createElement("div", null, header && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: '-apple-system, system-ui',
      fontSize: 13,
      color: hc,
      textTransform: 'uppercase',
      padding: '8px 36px 6px',
      letterSpacing: -0.08
    }
  }, header), /*#__PURE__*/React.createElement("div", {
    style: {
      background: bg,
      borderRadius: 26,
      margin: '0 16px',
      overflow: 'hidden'
    }
  }, children));
}

// ─────────────────────────────────────────────────────────────
// Device frame
// ─────────────────────────────────────────────────────────────
function IOSDevice({
  children,
  width = 402,
  height = 874,
  dark = false,
  title,
  keyboard = false
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width,
      height,
      borderRadius: 48,
      overflow: 'hidden',
      position: 'relative',
      background: dark ? '#000' : '#F2F2F7',
      boxShadow: '0 40px 80px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.12)',
      fontFamily: '-apple-system, system-ui, sans-serif',
      WebkitFontSmoothing: 'antialiased'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 11,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 126,
      height: 37,
      borderRadius: 24,
      background: '#000',
      zIndex: 50
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      zIndex: 10
    }
  }, /*#__PURE__*/React.createElement(IOSStatusBar, {
    dark: dark
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column'
    }
  }, title !== undefined && /*#__PURE__*/React.createElement(IOSNavBar, {
    title: title,
    dark: dark
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: 'auto'
    }
  }, children), keyboard && /*#__PURE__*/React.createElement(IOSKeyboard, {
    dark: dark
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      left: 0,
      right: 0,
      zIndex: 60,
      height: 34,
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'flex-end',
      paddingBottom: 8,
      pointerEvents: 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 139,
      height: 5,
      borderRadius: 100,
      background: dark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.25)'
    }
  })));
}

// ─────────────────────────────────────────────────────────────
// Keyboard — iOS 26 liquid glass
// ─────────────────────────────────────────────────────────────
function IOSKeyboard({
  dark = false
}) {
  const glyph = dark ? 'rgba(255,255,255,0.7)' : '#595959';
  const sugg = dark ? 'rgba(255,255,255,0.6)' : '#333';
  const keyBg = dark ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.85)';

  // special-key icons
  const icons = {
    shift: /*#__PURE__*/React.createElement("svg", {
      width: "19",
      height: "17",
      viewBox: "0 0 19 17"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M9.5 1L1 9.5h4.5V16h8V9.5H18L9.5 1z",
      fill: glyph
    })),
    del: /*#__PURE__*/React.createElement("svg", {
      width: "23",
      height: "17",
      viewBox: "0 0 23 17"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M7 1h13a2 2 0 012 2v11a2 2 0 01-2 2H7l-6-7.5L7 1z",
      fill: "none",
      stroke: glyph,
      strokeWidth: "1.6",
      strokeLinejoin: "round"
    }), /*#__PURE__*/React.createElement("path", {
      d: "M10 5l7 7M17 5l-7 7",
      stroke: glyph,
      strokeWidth: "1.6",
      strokeLinecap: "round"
    })),
    ret: /*#__PURE__*/React.createElement("svg", {
      width: "20",
      height: "14",
      viewBox: "0 0 20 14"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M18 1v6H4m0 0l4-4M4 7l4 4",
      fill: "none",
      stroke: "#fff",
      strokeWidth: "1.8",
      strokeLinecap: "round",
      strokeLinejoin: "round"
    }))
  };
  const key = (content, {
    w,
    flex,
    ret,
    fs = 25,
    k
  } = {}) => /*#__PURE__*/React.createElement("div", {
    key: k,
    style: {
      height: 42,
      borderRadius: 8.5,
      flex: flex ? 1 : undefined,
      width: w,
      minWidth: 0,
      background: ret ? '#08f' : keyBg,
      boxShadow: '0 1px 0 rgba(0,0,0,0.075)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: '-apple-system, "SF Compact", system-ui',
      fontSize: fs,
      fontWeight: 458,
      color: ret ? '#fff' : glyph
    }
  }, content);
  const row = (keys, pad = 0) => /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6.5,
      justifyContent: 'center',
      padding: `0 ${pad}px`
    }
  }, keys.map(l => key(l, {
    flex: true,
    k: l
  })));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 15,
      borderRadius: 27,
      overflow: 'hidden',
      padding: '11px 0 2px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      boxShadow: dark ? '0 -2px 20px rgba(0,0,0,0.09)' : '0 -1px 6px rgba(0,0,0,0.018), 0 -3px 20px rgba(0,0,0,0.012)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 27,
      backdropFilter: 'blur(12px) saturate(180%)',
      WebkitBackdropFilter: 'blur(12px) saturate(180%)',
      background: dark ? 'rgba(120,120,128,0.14)' : 'rgba(255,255,255,0.25)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 27,
      boxShadow: dark ? 'inset 1.5px 1.5px 1px rgba(255,255,255,0.15)' : 'inset 1.5px 1.5px 1px rgba(255,255,255,0.7), inset -1px -1px 1px rgba(255,255,255,0.4)',
      border: dark ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(0,0,0,0.06)',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 20,
      alignItems: 'center',
      padding: '8px 22px 13px',
      width: '100%',
      boxSizing: 'border-box',
      position: 'relative'
    }
  }, ['"The"', 'the', 'to'].map((w, i) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: i
  }, i > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 1,
      height: 25,
      background: '#ccc',
      opacity: 0.3
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      textAlign: 'center',
      fontFamily: '-apple-system, system-ui',
      fontSize: 17,
      color: sugg,
      letterSpacing: -0.43,
      lineHeight: '22px'
    }
  }, w)))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 13,
      padding: '0 6.5px',
      width: '100%',
      boxSizing: 'border-box',
      position: 'relative'
    }
  }, row(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']), row(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'], 20), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14.25,
      alignItems: 'center'
    }
  }, key(icons.shift, {
    w: 45,
    k: 'shift'
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6.5,
      flex: 1
    }
  }, ['z', 'x', 'c', 'v', 'b', 'n', 'm'].map(l => key(l, {
    flex: true,
    k: l
  }))), key(icons.del, {
    w: 45,
    k: 'del'
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6,
      alignItems: 'center'
    }
  }, key('ABC', {
    w: 92.25,
    fs: 18,
    k: 'abc'
  }), key('', {
    flex: true,
    k: 'space'
  }), key(icons.ret, {
    w: 92.25,
    ret: true,
    k: 'ret'
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 56,
      width: '100%',
      position: 'relative'
    }
  }));
}
Object.assign(window, {
  IOSDevice,
  IOSStatusBar,
  IOSNavBar,
  IOSGlassPill,
  IOSList,
  IOSListRow,
  IOSKeyboard
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/liive-ride/ios-frame.jsx", error: String((e && e.message) || e) }); }

// ui_kits/liive-ride/screens1.jsx
try { (() => {
/* Liive Ride — Destination & Options sheets */
(function () {
  const DS = () => window.LiiveRideDesignSystem_b6f128 || {};
  const Icon = (name, style) => /*#__PURE__*/React.createElement("i", {
    "data-lucide": name,
    style: style
  });

  // ── 1. Where to? ───────────────────────────────────────────
  function DestinationSheet({
    onPick
  }) {
    const {
      BottomSheet,
      IconCircle,
      ListRow
    } = DS();
    const places = [{
      icon: "home",
      color: "accent",
      title: "Home",
      sub: "1208 Sutter St"
    }, {
      icon: "briefcase",
      color: "neutral",
      title: "Work",
      sub: "455 Market St, Floor 12"
    }, {
      icon: "clock",
      color: "neutral",
      title: "Union Square",
      sub: "Geary & Powell"
    }, {
      icon: "plane",
      color: "neutral",
      title: "SFO — Terminal 2",
      sub: "Airport"
    }];
    return /*#__PURE__*/React.createElement(BottomSheet, null, /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        marginBottom: 12
      }
    }, /*#__PURE__*/React.createElement("span", {
      className: "t-title2",
      style: {
        color: "var(--text)"
      }
    }, "Where to?"), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 14,
        color: "var(--accent)",
        fontWeight: 600
      }
    }, "Now \u25BE")), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        alignItems: "center",
        gap: 10,
        height: 46,
        padding: "0 14px",
        background: "var(--fill-tertiary)",
        borderRadius: "var(--radius-md)",
        marginBottom: 14
      }
    }, Icon("search", {
      width: 18,
      height: 18,
      color: "var(--text-secondary)"
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 16,
        color: "var(--text-tertiary)"
      }
    }, "Search a place or address")), /*#__PURE__*/React.createElement("div", {
      style: {
        background: "var(--surface-raised)",
        borderRadius: "var(--radius-lg)",
        overflow: "hidden"
      }
    }, places.map((p, i) => /*#__PURE__*/React.createElement(ListRow, {
      key: p.title,
      leading: /*#__PURE__*/React.createElement(IconCircle, {
        color: p.color,
        size: 36
      }, Icon(p.icon, {
        width: 17,
        height: 17
      })),
      title: p.title,
      subtitle: p.sub,
      chevron: true,
      divider: i < places.length - 1,
      onClick: () => onPick(p)
    }))));
  }

  // ── 2. Choose your ride ────────────────────────────────────
  function OptionsSheet({
    dest,
    config,
    setConfig,
    onBack,
    onConfirm
  }) {
    const {
      BottomSheet,
      Button,
      IconCircle,
      ListRow,
      Switch,
      Stepper,
      Badge
    } = DS();
    const tiers = [{
      id: "pool",
      icon: "users",
      name: "Pool",
      desc: "Share · may transfer once",
      price: 9.5,
      eta: "12 min",
      multiLeg: true
    }, {
      id: "premium",
      icon: "car",
      name: "Premium",
      desc: "Private · direct route",
      price: 12.5,
      eta: "8 min",
      multiLeg: false
    }, {
      id: "exclusive",
      icon: "star",
      name: "Exclusive",
      desc: "Top-rated · luxury",
      price: 18.0,
      eta: "7 min",
      multiLeg: false
    }];
    const sel = tiers.find(t => t.id === config.tier) || tiers[1];
    const setTier = t => setConfig({
      ...config,
      tier: t.id,
      price: t.price,
      eta: t.eta,
      multiLeg: t.multiLeg
    });
    return /*#__PURE__*/React.createElement(BottomSheet, null, /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        alignItems: "center",
        gap: 10,
        marginBottom: 4
      }
    }, /*#__PURE__*/React.createElement("button", {
      onClick: onBack,
      style: backBtn
    }, Icon("chevron-left", {
      width: 20,
      height: 20,
      color: "var(--text)"
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1
      }
    }, /*#__PURE__*/React.createElement("div", {
      className: "t-title3",
      style: {
        color: "var(--text)"
      }
    }, "Choose your ride"), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 13,
        color: "var(--text-secondary)"
      }
    }, "to ", dest?.title || "Union Square"))), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        flexDirection: "column",
        gap: 8,
        margin: "12px 0"
      }
    }, tiers.map(t => {
      const active = t.id === sel.id;
      return /*#__PURE__*/React.createElement("div", {
        key: t.id,
        onClick: () => setTier(t),
        style: {
          display: "flex",
          alignItems: "center",
          gap: 12,
          padding: 12,
          cursor: "pointer",
          background: "var(--surface-raised)",
          borderRadius: "var(--radius-lg)",
          border: active ? "1.5px solid var(--accent)" : "1.5px solid transparent",
          transition: "border-color 150ms"
        }
      }, /*#__PURE__*/React.createElement(IconCircle, {
        color: active ? "accent" : "neutral"
      }, Icon(t.icon, {
        width: 20,
        height: 20
      })), /*#__PURE__*/React.createElement("div", {
        style: {
          flex: 1
        }
      }, /*#__PURE__*/React.createElement("div", {
        style: {
          display: "flex",
          alignItems: "center",
          gap: 6
        }
      }, /*#__PURE__*/React.createElement("span", {
        style: {
          fontFamily: "var(--font-sans)",
          fontSize: 17,
          fontWeight: 600,
          color: "var(--text)"
        }
      }, t.name), t.multiLeg && /*#__PURE__*/React.createElement(Badge, {
        color: "warning"
      }, "2 legs")), /*#__PURE__*/React.createElement("div", {
        style: {
          fontFamily: "var(--font-sans)",
          fontSize: 13,
          color: "var(--text-secondary)",
          marginTop: 1
        }
      }, t.desc)), /*#__PURE__*/React.createElement("div", {
        style: {
          textAlign: "right"
        }
      }, /*#__PURE__*/React.createElement("div", {
        className: "tnum",
        style: {
          fontFamily: "var(--font-sans)",
          fontSize: 17,
          fontWeight: 700,
          color: "var(--text)"
        }
      }, "$", t.price.toFixed(2)), /*#__PURE__*/React.createElement("div", {
        style: {
          fontFamily: "var(--font-sans)",
          fontSize: 12,
          color: "var(--text-secondary)"
        }
      }, t.eta)));
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        background: "var(--surface-raised)",
        borderRadius: "var(--radius-lg)",
        overflow: "hidden",
        marginBottom: 14
      }
    }, /*#__PURE__*/React.createElement(ListRow, {
      leading: /*#__PURE__*/React.createElement(IconCircle, {
        color: "neutral",
        size: 32
      }, Icon("users", {
        width: 16,
        height: 16
      })),
      title: "Passengers",
      trailing: /*#__PURE__*/React.createElement(Stepper, {
        value: config.passengers,
        min: 1,
        max: 4,
        onChange: v => setConfig({
          ...config,
          passengers: v
        })
      })
    }), /*#__PURE__*/React.createElement(ListRow, {
      leading: /*#__PURE__*/React.createElement(IconCircle, {
        color: "neutral",
        size: 32
      }, Icon("luggage", {
        width: 16,
        height: 16
      })),
      title: "Bags",
      trailing: /*#__PURE__*/React.createElement(Stepper, {
        value: config.bags,
        min: 0,
        max: 4,
        onChange: v => setConfig({
          ...config,
          bags: v
        })
      })
    }), /*#__PURE__*/React.createElement(ListRow, {
      leading: /*#__PURE__*/React.createElement(IconCircle, {
        color: "success",
        size: 32
      }, Icon("shield", {
        width: 16,
        height: 16
      })),
      title: "Female-only pool",
      subtitle: "Match same-gender drivers & riders",
      trailing: /*#__PURE__*/React.createElement(Switch, {
        checked: config.femaleOnly,
        onChange: v => setConfig({
          ...config,
          femaleOnly: v
        })
      })
    }), /*#__PURE__*/React.createElement(ListRow, {
      leading: /*#__PURE__*/React.createElement(IconCircle, {
        color: "neutral",
        size: 32
      }, Icon("baby", {
        width: 16,
        height: 16
      })),
      title: "Child seat",
      divider: false,
      trailing: /*#__PURE__*/React.createElement(Switch, {
        checked: config.childSeat,
        onChange: v => setConfig({
          ...config,
          childSeat: v
        })
      })
    })), /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      size: "lg",
      shape: "capsule",
      fullWidth: true,
      onClick: onConfirm
    }, "Confirm Pickup \xB7 $", sel.price.toFixed(2)));
  }
  const backBtn = {
    width: 32,
    height: 32,
    borderRadius: "50%",
    border: "none",
    background: "var(--fill-tertiary)",
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    cursor: "pointer",
    flex: "none"
  };
  Object.assign(window, {
    DestinationSheet,
    OptionsSheet
  });
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/liive-ride/screens1.jsx", error: String((e && e.message) || e) }); }

// ui_kits/liive-ride/screens2.jsx
try { (() => {
/* Liive Ride — Matching, En-route & Complete sheets */
(function () {
  const DS = () => window.LiiveRideDesignSystem_b6f128 || {};
  const Icon = (name, style) => /*#__PURE__*/React.createElement("i", {
    "data-lucide": name,
    style: style
  });

  // ── 3. Matching ────────────────────────────────────────────
  function MatchingSheet({
    config,
    onCancel
  }) {
    const {
      BottomSheet,
      Button,
      Badge
    } = DS();
    return /*#__PURE__*/React.createElement(BottomSheet, null, /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        textAlign: "center",
        padding: "8px 0 4px"
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        gap: 6,
        marginBottom: 16
      }
    }, [0, 1, 2].map(i => /*#__PURE__*/React.createElement("span", {
      key: i,
      style: {
        width: 9,
        height: 9,
        borderRadius: "50%",
        background: "var(--accent)",
        animation: `liive-bounce 1.2s ${i * 0.16}s ease-in-out infinite`
      }
    }))), /*#__PURE__*/React.createElement("div", {
      className: "t-title3",
      style: {
        color: "var(--text)"
      }
    }, "Finding your driver\u2026"), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 14,
        color: "var(--text-secondary)",
        marginTop: 6,
        maxWidth: 280
      }
    }, "Matching you with a nearby", config.femaleOnly ? " female-only" : "", " ", config.tier, " driver and reserving a legal curb."), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        gap: 8,
        marginTop: 16
      }
    }, /*#__PURE__*/React.createElement(Badge, {
      color: "success",
      dot: true
    }, "Curb reserved"), config.femaleOnly && /*#__PURE__*/React.createElement(Badge, {
      color: "accent"
    }, "Female-only pool"))), /*#__PURE__*/React.createElement("div", {
      style: {
        marginTop: 22
      }
    }, /*#__PURE__*/React.createElement(Button, {
      variant: "secondary",
      size: "lg",
      shape: "capsule",
      fullWidth: true,
      onClick: onCancel
    }, "Cancel")), /*#__PURE__*/React.createElement("style", null, "@keyframes liive-bounce{0%,100%{transform:translateY(0);opacity:.5}50%{transform:translateY(-7px);opacity:1}}"));
  }

  // ── 4. En route ────────────────────────────────────────────
  function EnrouteSheet({
    config,
    onMessage,
    onCancel
  }) {
    const {
      BottomSheet,
      Button,
      DriverCard,
      ProgressDots
    } = DS();
    return /*#__PURE__*/React.createElement(BottomSheet, null, /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        alignItems: "baseline",
        justifyContent: "space-between",
        marginBottom: 12
      }
    }, /*#__PURE__*/React.createElement("span", {
      className: "t-title3",
      style: {
        color: "var(--text)"
      }
    }, config.multiLeg ? "On leg 2 of 2" : "Your driver is arriving"), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 14,
        color: "var(--text-secondary)"
      }
    }, "to ", config.destName)), /*#__PURE__*/React.createElement(DriverCard, {
      name: "John Driver",
      rating: 4.8,
      vehicle: "Toyota Camry \xB7 Blue",
      plate: "ABC 123",
      eta: config.multiLeg ? "3 min" : "4 min",
      speaking: true,
      trailing: /*#__PURE__*/React.createElement("div", {
        style: {
          display: "flex",
          gap: 8,
          flex: "none"
        }
      }, /*#__PURE__*/React.createElement(Button, {
        variant: "tinted",
        onClick: onMessage,
        style: {
          width: 44,
          padding: 0
        }
      }, Icon("phone", {
        width: 18,
        height: 18
      })))
    }), config.multiLeg && /*#__PURE__*/React.createElement("div", {
      style: {
        background: "var(--surface-raised)",
        borderRadius: "var(--radius-lg)",
        padding: 14,
        marginTop: 12
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        alignItems: "center",
        gap: 8,
        marginBottom: 10
      }
    }, Icon("map", {
      width: 16,
      height: 16,
      color: "var(--accent)"
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 15,
        fontWeight: 600,
        color: "var(--text)"
      }
    }, "Multi-leg journey")), /*#__PURE__*/React.createElement(ProgressDots, {
      legs: 2,
      current: 2
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        alignItems: "center",
        gap: 6,
        marginTop: 12,
        paddingTop: 10,
        borderTop: "1px solid var(--separator)"
      }
    }, Icon("footprints", {
      width: 15,
      height: 15,
      color: "var(--warning)"
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 13,
        color: "var(--text-secondary)"
      }
    }, "Transfer at Hayes St complete \xB7 150m walk"))), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        gap: 10,
        marginTop: 14
      }
    }, /*#__PURE__*/React.createElement(Button, {
      variant: "secondary",
      size: "lg",
      onClick: onMessage,
      style: {
        flex: 1
      },
      icon: Icon("message-circle", {
        width: 18,
        height: 18
      })
    }, "Message"), /*#__PURE__*/React.createElement(Button, {
      variant: "destructive-plain",
      size: "lg",
      onClick: onCancel,
      style: {
        flex: 1
      }
    }, "Cancel Ride")));
  }

  // ── 5. Trip complete & pay ─────────────────────────────────
  function CompleteSheet({
    config,
    paid,
    onPay,
    onDone
  }) {
    const {
      BottomSheet,
      Button,
      FareRow,
      IconCircle,
      ListRow
    } = DS();
    const [rating, setRating] = React.useState(0);
    const fare = config.price;
    const base = +(fare / 1.0875).toFixed(2);
    const tax = +(fare - base).toFixed(2);
    if (paid) {
      return /*#__PURE__*/React.createElement(BottomSheet, null, /*#__PURE__*/React.createElement("div", {
        style: {
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          textAlign: "center",
          padding: "10px 0"
        }
      }, /*#__PURE__*/React.createElement(IconCircle, {
        color: "success",
        filled: true,
        size: 56
      }, Icon("check", {
        width: 28,
        height: 28
      })), /*#__PURE__*/React.createElement("div", {
        className: "t-title2",
        style: {
          color: "var(--text)",
          marginTop: 14
        }
      }, "Thanks for riding"), /*#__PURE__*/React.createElement("div", {
        style: {
          fontFamily: "var(--font-sans)",
          fontSize: 15,
          color: "var(--text-secondary)",
          marginTop: 6
        }
      }, "$", fare.toFixed(2), " paid to John \xB7 receipt sent")), /*#__PURE__*/React.createElement("div", {
        style: {
          marginTop: 20
        }
      }, /*#__PURE__*/React.createElement(Button, {
        variant: "primary",
        size: "lg",
        shape: "capsule",
        fullWidth: true,
        onClick: onDone
      }, "Done")));
    }
    return /*#__PURE__*/React.createElement(BottomSheet, null, /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        alignItems: "center",
        gap: 10,
        marginBottom: 14
      }
    }, /*#__PURE__*/React.createElement(IconCircle, {
      color: "success",
      filled: true,
      size: 36
    }, Icon("flag", {
      width: 18,
      height: 18
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1
      }
    }, /*#__PURE__*/React.createElement("div", {
      className: "t-title3",
      style: {
        color: "var(--text)"
      }
    }, "You've arrived"), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 13,
        color: "var(--text-secondary)"
      }
    }, config.destName, " \xB7 18 min \xB7 5.2 km"))), /*#__PURE__*/React.createElement("div", {
      style: {
        background: "var(--surface-raised)",
        borderRadius: "var(--radius-lg)",
        padding: "8px 14px 14px",
        marginBottom: 12
      }
    }, /*#__PURE__*/React.createElement(FareRow, {
      label: "Ride fare",
      amount: `$${base.toFixed(2)}`
    }), /*#__PURE__*/React.createElement(FareRow, {
      label: "Tax & fees",
      amount: `$${tax.toFixed(2)}`
    }), config.multiLeg && /*#__PURE__*/React.createElement(FareRow, {
      label: "Cost-share credit",
      amount: "\u2013$2.00",
      muted: true
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        borderTop: "1px solid var(--separator)",
        margin: "4px 0 0"
      }
    }), /*#__PURE__*/React.createElement(FareRow, {
      label: "Total",
      amount: `$${fare.toFixed(2)}`,
      total: true
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        background: "var(--surface-raised)",
        borderRadius: "var(--radius-lg)",
        overflow: "hidden",
        marginBottom: 12
      }
    }, /*#__PURE__*/React.createElement(ListRow, {
      leading: /*#__PURE__*/React.createElement(IconCircle, {
        color: "neutral",
        size: 32
      }, Icon("apple", {
        width: 16,
        height: 16
      })),
      title: "Apple Pay",
      value: "default",
      chevron: true,
      divider: false
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 8,
        marginBottom: 16
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: 14,
        color: "var(--text-secondary)"
      }
    }, "Rate your driver"), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        gap: 6
      }
    }, [1, 2, 3, 4, 5].map(n => /*#__PURE__*/React.createElement("button", {
      key: n,
      onClick: () => setRating(n),
      style: {
        background: "none",
        border: "none",
        padding: 2,
        cursor: "pointer"
      }
    }, /*#__PURE__*/React.createElement("svg", {
      width: "28",
      height: "28",
      viewBox: "0 0 24 24",
      fill: n <= rating ? "var(--star)" : "var(--fill)"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.8 5.9 21.4l1.4-6.8L2.2 9.9l6.9-.8z"
    })))))), /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      size: "lg",
      shape: "capsule",
      fullWidth: true,
      onClick: onPay
    }, "Pay $", fare.toFixed(2)), /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: "center",
        marginTop: 10,
        fontFamily: "var(--font-sans)",
        fontSize: 12,
        color: "var(--text-tertiary)"
      }
    }, "Secured by Stripe"));
  }
  Object.assign(window, {
    MatchingSheet,
    EnrouteSheet,
    CompleteSheet
  });
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/liive-ride/screens2.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Avatar = __ds_scope.Avatar;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.IconCircle = __ds_scope.IconCircle;

__ds_ns.ListRow = __ds_scope.ListRow;

__ds_ns.RatingStars = __ds_scope.RatingStars;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.Stepper = __ds_scope.Stepper;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.BottomSheet = __ds_scope.BottomSheet;

__ds_ns.DriverCard = __ds_scope.DriverCard;

__ds_ns.FareRow = __ds_scope.FareRow;

__ds_ns.GlassPanel = __ds_scope.GlassPanel;

__ds_ns.MapMarker = __ds_scope.MapMarker;

__ds_ns.ProgressDots = __ds_scope.ProgressDots;

__ds_ns.SOSButton = __ds_scope.SOSButton;

})();
