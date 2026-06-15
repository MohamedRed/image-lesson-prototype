/* Liive Ride — MapCanvas
   A stylised dark Mapbox-style map used as the persistent background behind
   every screen. Pure SVG + DS MapMarkers. No live tiles. */
(function () {
  const DS = () => window.LiiveRideDesignSystem_b6f128 || {};

  function MapCanvas({ phase, multiLeg, carT = 0 }) {
    const { MapMarker } = DS();

    // route geometry (in the 402x740 map area)
    const origin = { x: 196, y: 470 };
    const dest = { x: 250, y: 165 };
    const transfer = { x: 150, y: 320 };

    // single vs multi-leg route path
    const routePath = multiLeg
      ? `M${origin.x},${origin.y} C 150,430 120,380 ${transfer.x},${transfer.y} C 175,285 230,230 ${dest.x},${dest.y}`
      : `M${origin.x},${origin.y} C 170,400 300,330 ${dest.x},${dest.y}`;

    // car position interpolated along a simple eased point set
    const carPts = multiLeg
      ? [origin, { x: 150, y: 400 }, transfer, { x: 205, y: 250 }, dest]
      : [origin, { x: 215, y: 390 }, { x: 285, y: 300 }, dest];
    const seg = Math.min(carPts.length - 2, Math.floor(carT * (carPts.length - 1)));
    const local = carT * (carPts.length - 1) - seg;
    const a = carPts[seg], b = carPts[seg + 1] || carPts[carPts.length - 1];
    const car = { x: a.x + (b.x - a.x) * local, y: a.y + (b.y - a.y) * local };

    const showRoute = phase !== "destination";
    const showCar = phase === "enroute";
    const showDest = phase !== "destination";

    return (
      <div style={{ position: "absolute", inset: 0, overflow: "hidden", background: "var(--map-bg)" }}>
        <svg viewBox="0 0 402 740" preserveAspectRatio="xMidYMid slice"
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}>
          <defs>
            <filter id="routeShadow" x="-20%" y="-20%" width="140%" height="140%">
              <feDropShadow dx="0" dy="2" stdDeviation="3" floodColor="#000" floodOpacity="0.35" />
            </filter>
          </defs>
          {/* water / park blocks */}
          <rect x="-40" y="540" width="220" height="260" fill="var(--map-water)" opacity="0.9" transform="rotate(-8 70 670)" />
          <rect x="250" y="40" width="240" height="180" rx="10" fill="#222a22" opacity="0.55" />
          <rect x="-20" y="120" width="150" height="150" rx="8" fill="#2a2722" opacity="0.5" />

          {/* street grid */}
          <g stroke="var(--map-road)" strokeWidth="9" strokeLinecap="round" opacity="0.95">
            <line x1="-20" y1="250" x2="430" y2="225" />
            <line x1="-20" y1="370" x2="430" y2="350" />
            <line x1="-20" y1="500" x2="430" y2="520" />
            <line x1="-20" y1="630" x2="430" y2="650" />
            <line x1="70" y1="-20" x2="120" y2="780" />
            <line x1="210" y1="-20" x2="240" y2="780" />
            <line x1="330" y1="-20" x2="360" y2="780" />
          </g>
          <g stroke="var(--map-road)" strokeWidth="4" strokeLinecap="round" opacity="0.6">
            <line x1="-20" y1="180" x2="430" y2="165" />
            <line x1="-20" y1="430" x2="430" y2="445" />
            <line x1="140" y1="-20" x2="170" y2="780" />
            <line x1="280" y1="-20" x2="305" y2="780" />
          </g>

          {/* route */}
          {showRoute && (
            <>
              <path d={routePath} fill="none" stroke="var(--map-route)" strokeWidth="7"
                strokeLinecap="round" filter="url(#routeShadow)" />
              {multiLeg && (
                <circle cx={transfer.x} cy={transfer.y} r="5" fill="#fff"
                  stroke="var(--warning)" strokeWidth="3" />
              )}
            </>
          )}
        </svg>

        {/* DS markers layered on top, positioned in the same 402x740 space */}
        <Layer>
          {phase === "destination" && <Pos x={origin.x} y={origin.y}><Pulse /></Pos>}
          {showRoute && !showCar && <Pos x={origin.x} y={origin.y}><DS_Marker kind="origin" label="Pickup" /></Pos>}
          {showCar && <Pos x={car.x} y={car.y}><DS_Marker kind="car" label={multiLeg ? "Leg 2 · 3 min" : "4 min"} /></Pos>}
          {multiLeg && showRoute && <Pos x={transfer.x} y={transfer.y}><DS_Marker kind="transfer" label="Transfer" /></Pos>}
          {showDest && <Pos x={dest.x} y={dest.y}><DS_Marker kind="destination" label="Union Square" /></Pos>}
        </Layer>

        {/* matching radar sweep */}
        {phase === "matching" && (
          <div style={{
            position: "absolute", left: "48.7%", top: "63.5%", transform: "translate(-50%,-50%)",
            width: 14, height: 14,
          }}>
            <span style={{
              position: "absolute", inset: 0, borderRadius: "50%", background: "var(--accent)",
              border: "3px solid #fff", boxShadow: "var(--shadow-pin)",
            }} />
            <span style={{
              position: "absolute", inset: 0, borderRadius: "50%", background: "var(--accent)",
              animation: "liive-radar 1.8s ease-out infinite",
            }} />
          </div>
        )}
        <style>{"@keyframes liive-radar{0%{transform:scale(1);opacity:.5}100%{transform:scale(9);opacity:0}}"}</style>
      </div>
    );

    function DS_Marker(props) { return MapMarker ? <MapMarker {...props} /> : null; }
  }

  // position helpers translate 402x740 coords into % of container
  function Layer({ children }) {
    return <div style={{ position: "absolute", inset: 0 }}>{children}</div>;
  }
  function Pos({ x, y, children }) {
    return (
      <div style={{
        position: "absolute", left: `${(x / 402) * 100}%`, top: `${(y / 740) * 100}%`,
        transform: "translate(-50%,-100%)",
      }}>{children}</div>
    );
  }
  function Pulse() {
    return (
      <div style={{ position: "relative", width: 22, height: 22, transform: "translateY(11px)" }}>
        <span style={{ position: "absolute", inset: 0, borderRadius: "50%", background: "var(--accent)", border: "3px solid #fff", boxShadow: "var(--shadow-pin)" }} />
        <span style={{ position: "absolute", inset: -4, borderRadius: "50%", background: "var(--accent-tint)", animation: "liive-radar2 2s ease-out infinite" }} />
        <style>{"@keyframes liive-radar2{0%{transform:scale(1);opacity:.6}100%{transform:scale(3);opacity:0}}"}</style>
      </div>
    );
  }

  window.MapCanvas = MapCanvas;
})();
