/* Liive Ride — Destination & Options sheets */
(function () {
  const DS = () => window.LiiveRideDesignSystem_b6f128 || {};
  const Icon = (name, style) => <i data-lucide={name} style={style}></i>;

  // ── 1. Where to? ───────────────────────────────────────────
  function DestinationSheet({ onPick }) {
    const { BottomSheet, IconCircle, ListRow } = DS();
    const places = [
      { icon: "home", color: "accent", title: "Home", sub: "1208 Sutter St" },
      { icon: "briefcase", color: "neutral", title: "Work", sub: "455 Market St, Floor 12" },
      { icon: "clock", color: "neutral", title: "Union Square", sub: "Geary & Powell" },
      { icon: "plane", color: "neutral", title: "SFO — Terminal 2", sub: "Airport" },
    ];
    return (
      <BottomSheet>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
          <span className="t-title2" style={{ color: "var(--text)" }}>Where to?</span>
          <span style={{ fontFamily: "var(--font-sans)", fontSize: 14, color: "var(--accent)", fontWeight: 600 }}>
            Now ▾
          </span>
        </div>

        <div style={{
          display: "flex", alignItems: "center", gap: 10, height: 46, padding: "0 14px",
          background: "var(--fill-tertiary)", borderRadius: "var(--radius-md)", marginBottom: 14,
        }}>
          {Icon("search", { width: 18, height: 18, color: "var(--text-secondary)" })}
          <span style={{ fontFamily: "var(--font-sans)", fontSize: 16, color: "var(--text-tertiary)" }}>
            Search a place or address
          </span>
        </div>

        <div style={{ background: "var(--surface-raised)", borderRadius: "var(--radius-lg)", overflow: "hidden" }}>
          {places.map((p, i) => (
            <ListRow key={p.title}
              leading={<IconCircle color={p.color} size={36}>{Icon(p.icon, { width: 17, height: 17 })}</IconCircle>}
              title={p.title} subtitle={p.sub} chevron divider={i < places.length - 1}
              onClick={() => onPick(p)} />
          ))}
        </div>
      </BottomSheet>
    );
  }

  // ── 2. Choose your ride ────────────────────────────────────
  function OptionsSheet({ dest, config, setConfig, onBack, onConfirm }) {
    const { BottomSheet, Button, IconCircle, ListRow, Switch, Stepper, Badge } = DS();
    const tiers = [
      { id: "pool", icon: "users", name: "Pool", desc: "Share · may transfer once", price: 9.5, eta: "12 min", multiLeg: true },
      { id: "premium", icon: "car", name: "Premium", desc: "Private · direct route", price: 12.5, eta: "8 min", multiLeg: false },
      { id: "exclusive", icon: "star", name: "Exclusive", desc: "Top-rated · luxury", price: 18.0, eta: "7 min", multiLeg: false },
    ];
    const sel = tiers.find((t) => t.id === config.tier) || tiers[1];

    const setTier = (t) => setConfig({ ...config, tier: t.id, price: t.price, eta: t.eta, multiLeg: t.multiLeg });

    return (
      <BottomSheet>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 4 }}>
          <button onClick={onBack} style={backBtn}>{Icon("chevron-left", { width: 20, height: 20, color: "var(--text)" })}</button>
          <div style={{ flex: 1 }}>
            <div className="t-title3" style={{ color: "var(--text)" }}>Choose your ride</div>
            <div style={{ fontFamily: "var(--font-sans)", fontSize: 13, color: "var(--text-secondary)" }}>
              to {dest?.title || "Union Square"}
            </div>
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 8, margin: "12px 0" }}>
          {tiers.map((t) => {
            const active = t.id === sel.id;
            return (
              <div key={t.id} onClick={() => setTier(t)} style={{
                display: "flex", alignItems: "center", gap: 12, padding: 12, cursor: "pointer",
                background: "var(--surface-raised)", borderRadius: "var(--radius-lg)",
                border: active ? "1.5px solid var(--accent)" : "1.5px solid transparent",
                transition: "border-color 150ms",
              }}>
                <IconCircle color={active ? "accent" : "neutral"}>{Icon(t.icon, { width: 20, height: 20 })}</IconCircle>
                <div style={{ flex: 1 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                    <span style={{ fontFamily: "var(--font-sans)", fontSize: 17, fontWeight: 600, color: "var(--text)" }}>{t.name}</span>
                    {t.multiLeg && <Badge color="warning">2 legs</Badge>}
                  </div>
                  <div style={{ fontFamily: "var(--font-sans)", fontSize: 13, color: "var(--text-secondary)", marginTop: 1 }}>{t.desc}</div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <div className="tnum" style={{ fontFamily: "var(--font-sans)", fontSize: 17, fontWeight: 700, color: "var(--text)" }}>${t.price.toFixed(2)}</div>
                  <div style={{ fontFamily: "var(--font-sans)", fontSize: 12, color: "var(--text-secondary)" }}>{t.eta}</div>
                </div>
              </div>
            );
          })}
        </div>

        {/* ride details */}
        <div style={{ background: "var(--surface-raised)", borderRadius: "var(--radius-lg)", overflow: "hidden", marginBottom: 14 }}>
          <ListRow leading={<IconCircle color="neutral" size={32}>{Icon("users", { width: 16, height: 16 })}</IconCircle>}
            title="Passengers"
            trailing={<Stepper value={config.passengers} min={1} max={4} onChange={(v) => setConfig({ ...config, passengers: v })} />} />
          <ListRow leading={<IconCircle color="neutral" size={32}>{Icon("luggage", { width: 16, height: 16 })}</IconCircle>}
            title="Bags"
            trailing={<Stepper value={config.bags} min={0} max={4} onChange={(v) => setConfig({ ...config, bags: v })} />} />
          <ListRow leading={<IconCircle color="success" size={32}>{Icon("shield", { width: 16, height: 16 })}</IconCircle>}
            title="Female-only pool" subtitle="Match same-gender drivers & riders"
            trailing={<Switch checked={config.femaleOnly} onChange={(v) => setConfig({ ...config, femaleOnly: v })} />} />
          <ListRow leading={<IconCircle color="neutral" size={32}>{Icon("baby", { width: 16, height: 16 })}</IconCircle>}
            title="Child seat" divider={false}
            trailing={<Switch checked={config.childSeat} onChange={(v) => setConfig({ ...config, childSeat: v })} />} />
        </div>

        <Button variant="primary" size="lg" shape="capsule" fullWidth onClick={onConfirm}>
          Confirm Pickup · ${sel.price.toFixed(2)}
        </Button>
      </BottomSheet>
    );
  }

  const backBtn = {
    width: 32, height: 32, borderRadius: "50%", border: "none", background: "var(--fill-tertiary)",
    display: "inline-flex", alignItems: "center", justifyContent: "center", cursor: "pointer", flex: "none",
  };

  Object.assign(window, { DestinationSheet, OptionsSheet });
})();
