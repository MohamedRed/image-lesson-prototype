/* Liive Ride — app orchestrator (state machine + persistent map + chrome) */
(function () {
  const DS = () => window.LiiveRideDesignSystem_b6f128 || {};
  const Icon = (name, style) => <i data-lucide={name} style={style}></i>;
  const LS = "liive-ride-state";

  function RideApp() {
    const { GlassPanel, Badge, SOSButton, Button } = DS();
    const [screen, setScreen] = React.useState("destination");
    const [dest, setDest] = React.useState(null);
    const [paid, setPaid] = React.useState(false);
    const [mic, setMic] = React.useState(true);
    const [carT, setCarT] = React.useState(0);
    const [sos, setSos] = React.useState(false);
    const [config, setConfig] = React.useState({
      tier: "premium", price: 12.5, eta: "8 min", multiLeg: false,
      passengers: 1, bags: 1, femaleOnly: false, childSeat: false, destName: "Union Square",
    });

    // restore
    React.useEffect(() => {
      try {
        const s = JSON.parse(localStorage.getItem(LS) || "null");
        if (s) { setScreen(s.screen || "destination"); if (s.config) setConfig(s.config); if (s.dest) setDest(s.dest); }
      } catch (e) {}
    }, []);
    // persist
    React.useEffect(() => {
      localStorage.setItem(LS, JSON.stringify({ screen, config, dest }));
    }, [screen, config, dest]);

    // refresh icons after every render
    React.useEffect(() => {
      const id = setTimeout(() => window.lucide && window.lucide.createIcons(), 0);
      return () => clearTimeout(id);
    });

    // matching -> enroute
    React.useEffect(() => {
      if (screen !== "matching") return;
      const id = setTimeout(() => { setCarT(0); setScreen("enroute"); }, 2600);
      return () => clearTimeout(id);
    }, [screen]);

    // car animation during enroute -> complete
    React.useEffect(() => {
      if (screen !== "enroute") return;
      let raf, start;
      const dur = 11000;
      const tick = (t) => {
        if (!start) start = t;
        const p = Math.min(1, (t - start) / dur);
        setCarT(p);
        if (p < 1) raf = requestAnimationFrame(tick);
        else setTimeout(() => setScreen("complete"), 700);
      };
      raf = requestAnimationFrame(tick);
      return () => cancelAnimationFrame(raf);
    }, [screen]);

    const go = (s) => setScreen(s);
    const reset = () => { setPaid(false); setDest(null); setCarT(0); setScreen("destination"); };

    const phaseForMap = screen === "complete" ? "enroute" : screen;

    return (
      <div style={{ position: "absolute", inset: 0, overflow: "hidden", background: "var(--bg)" }}>
        {/* persistent map */}
        {window.MapCanvas && <window.MapCanvas phase={phaseForMap} multiLeg={config.multiLeg} carT={carT} />}
        <div style={{ position: "absolute", inset: 0, background: screen === "complete" ? "rgba(0,0,0,0.35)" : "transparent", transition: "background 300ms", pointerEvents: "none" }} />

        {/* top chrome */}
        <div style={{ position: "absolute", top: 58, left: 16, right: 16, display: "flex", alignItems: "flex-start", justifyContent: "space-between", zIndex: 20, pointerEvents: "none" }}>
          {screen === "enroute" ? (
            <GlassPanel material="thin" radius="var(--radius-full)" padding="7px 12px" style={{ display: "inline-flex", alignItems: "center", pointerEvents: "auto" }}>
              <Badge color="success" dot>Voice connected</Badge>
            </GlassPanel>
          ) : <span />}

          <div style={{ display: "flex", gap: 8, pointerEvents: "auto" }}>
            {screen === "enroute" && (
              <GlassPill onClick={() => setMic((m) => !m)}>
                {Icon(mic ? "mic" : "mic-off", { width: 19, height: 19, color: mic ? "var(--text)" : "var(--danger)" })}
              </GlassPill>
            )}
            <GlassPill><span style={{ display: "inline-flex" }}>{Icon("locate-fixed", { width: 19, height: 19, color: "var(--accent)" })}</span></GlassPill>
          </div>
        </div>

        {/* SOS during active ride */}
        {(screen === "enroute" || screen === "matching") && SOSButton && (
          <div style={{ position: "absolute", right: 16, top: 116, zIndex: 25 }}>
            <SOSButton size={54} onActivate={() => setSos(true)} />
          </div>
        )}

        {/* bottom sheet area */}
        <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, zIndex: 30 }}>
          {screen === "destination" && (
            <window.DestinationSheet onPick={(p) => { setDest(p); setConfig((c) => ({ ...c, destName: p.title })); go("options"); }} />
          )}
          {screen === "options" && (
            <window.OptionsSheet dest={dest} config={config} setConfig={setConfig} onBack={() => go("destination")} onConfirm={() => go("matching")} />
          )}
          {screen === "matching" && (
            <window.MatchingSheet config={config} onCancel={() => go("options")} />
          )}
          {screen === "enroute" && (
            <window.EnrouteSheet config={config} onMessage={() => {}} onCancel={() => reset()} />
          )}
          {screen === "complete" && (
            <window.CompleteSheet config={config} paid={paid} onPay={() => setPaid(true)} onDone={reset} />
          )}
        </div>

        {/* SOS confirm overlay */}
        {sos && (
          <div style={{ position: "absolute", inset: 0, zIndex: 60, background: "rgba(0,0,0,0.55)", display: "flex", alignItems: "center", justifyContent: "center", padding: 28 }}>
            <div style={{ background: "var(--surface)", borderRadius: "var(--radius-xl)", padding: 22, textAlign: "center", maxWidth: 300 }}>
              <div className="t-title3" style={{ color: "var(--text)" }}>Emergency Alert</div>
              <div style={{ fontFamily: "var(--font-sans)", fontSize: 14, color: "var(--text-secondary)", margin: "10px 0 18px" }}>
                This will immediately alert emergency services and your emergency contacts. Are you sure?
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                {Button && <Button variant="destructive" size="lg" shape="capsule" fullWidth onClick={() => setSos(false)}>Call Emergency Services</Button>}
                {Button && <Button variant="plain" onClick={() => setSos(false)}>Cancel</Button>}
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  function GlassPill({ children, onClick }) {
    const { GlassPanel } = DS();
    return (
      <GlassPanel material="thin" radius="var(--radius-full)" padding={0}
        style={{ width: 44, height: 44, display: "inline-flex", alignItems: "center", justifyContent: "center", cursor: "pointer", pointerEvents: "auto" }}
        onClick={onClick}>
        {children}
      </GlassPanel>
    );
  }

  window.RideApp = RideApp;
})();
