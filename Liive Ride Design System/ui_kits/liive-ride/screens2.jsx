/* Liive Ride — Matching, En-route & Complete sheets */
(function () {
  const DS = () => window.LiiveRideDesignSystem_b6f128 || {};
  const Icon = (name, style) => <i data-lucide={name} style={style}></i>;

  // ── 3. Matching ────────────────────────────────────────────
  function MatchingSheet({ config, onCancel }) {
    const { BottomSheet, Button, Badge } = DS();
    return (
      <BottomSheet>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", padding: "8px 0 4px" }}>
          <div style={{ display: "flex", gap: 6, marginBottom: 16 }}>
            {[0, 1, 2].map((i) => (
              <span key={i} style={{
                width: 9, height: 9, borderRadius: "50%", background: "var(--accent)",
                animation: `liive-bounce 1.2s ${i * 0.16}s ease-in-out infinite`,
              }} />
            ))}
          </div>
          <div className="t-title3" style={{ color: "var(--text)" }}>Finding your driver…</div>
          <div style={{ fontFamily: "var(--font-sans)", fontSize: 14, color: "var(--text-secondary)", marginTop: 6, maxWidth: 280 }}>
            Matching you with a nearby{config.femaleOnly ? " female-only" : ""} {config.tier} driver and reserving a legal curb.
          </div>
          <div style={{ display: "flex", gap: 8, marginTop: 16 }}>
            <Badge color="success" dot>Curb reserved</Badge>
            {config.femaleOnly && <Badge color="accent">Female-only pool</Badge>}
          </div>
        </div>
        <div style={{ marginTop: 22 }}>
          <Button variant="secondary" size="lg" shape="capsule" fullWidth onClick={onCancel}>Cancel</Button>
        </div>
        <style>{"@keyframes liive-bounce{0%,100%{transform:translateY(0);opacity:.5}50%{transform:translateY(-7px);opacity:1}}"}</style>
      </BottomSheet>
    );
  }

  // ── 4. En route ────────────────────────────────────────────
  function EnrouteSheet({ config, onMessage, onCancel }) {
    const { BottomSheet, Button, DriverCard, ProgressDots } = DS();
    return (
      <BottomSheet>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", marginBottom: 12 }}>
          <span className="t-title3" style={{ color: "var(--text)" }}>
            {config.multiLeg ? "On leg 2 of 2" : "Your driver is arriving"}
          </span>
          <span style={{ fontFamily: "var(--font-sans)", fontSize: 14, color: "var(--text-secondary)" }}>
            to {config.destName}
          </span>
        </div>

        <DriverCard name="John Driver" rating={4.8} vehicle="Toyota Camry · Blue" plate="ABC 123"
          eta={config.multiLeg ? "3 min" : "4 min"} speaking
          trailing={
            <div style={{ display: "flex", gap: 8, flex: "none" }}>
              <Button variant="tinted" onClick={onMessage} style={{ width: 44, padding: 0 }}>{Icon("phone", { width: 18, height: 18 })}</Button>
            </div>
          } />

        {config.multiLeg && (
          <div style={{ background: "var(--surface-raised)", borderRadius: "var(--radius-lg)", padding: 14, marginTop: 12 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10 }}>
              {Icon("map", { width: 16, height: 16, color: "var(--accent)" })}
              <span style={{ fontFamily: "var(--font-sans)", fontSize: 15, fontWeight: 600, color: "var(--text)" }}>Multi-leg journey</span>
            </div>
            <ProgressDots legs={2} current={2} />
            <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 12, paddingTop: 10, borderTop: "1px solid var(--separator)" }}>
              {Icon("footprints", { width: 15, height: 15, color: "var(--warning)" })}
              <span style={{ fontFamily: "var(--font-sans)", fontSize: 13, color: "var(--text-secondary)" }}>
                Transfer at Hayes St complete · 150m walk
              </span>
            </div>
          </div>
        )}

        <div style={{ display: "flex", gap: 10, marginTop: 14 }}>
          <Button variant="secondary" size="lg" onClick={onMessage} style={{ flex: 1 }} icon={Icon("message-circle", { width: 18, height: 18 })}>Message</Button>
          <Button variant="destructive-plain" size="lg" onClick={onCancel} style={{ flex: 1 }}>Cancel Ride</Button>
        </div>
      </BottomSheet>
    );
  }

  // ── 5. Trip complete & pay ─────────────────────────────────
  function CompleteSheet({ config, paid, onPay, onDone }) {
    const { BottomSheet, Button, FareRow, IconCircle, ListRow } = DS();
    const [rating, setRating] = React.useState(0);
    const fare = config.price;
    const base = +(fare / 1.0875).toFixed(2);
    const tax = +(fare - base).toFixed(2);

    if (paid) {
      return (
        <BottomSheet>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", padding: "10px 0" }}>
            <IconCircle color="success" filled size={56}>{Icon("check", { width: 28, height: 28 })}</IconCircle>
            <div className="t-title2" style={{ color: "var(--text)", marginTop: 14 }}>Thanks for riding</div>
            <div style={{ fontFamily: "var(--font-sans)", fontSize: 15, color: "var(--text-secondary)", marginTop: 6 }}>
              ${fare.toFixed(2)} paid to John · receipt sent
            </div>
          </div>
          <div style={{ marginTop: 20 }}>
            <Button variant="primary" size="lg" shape="capsule" fullWidth onClick={onDone}>Done</Button>
          </div>
        </BottomSheet>
      );
    }

    return (
      <BottomSheet>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
          <IconCircle color="success" filled size={36}>{Icon("flag", { width: 18, height: 18 })}</IconCircle>
          <div style={{ flex: 1 }}>
            <div className="t-title3" style={{ color: "var(--text)" }}>You've arrived</div>
            <div style={{ fontFamily: "var(--font-sans)", fontSize: 13, color: "var(--text-secondary)" }}>
              {config.destName} · 18 min · 5.2 km
            </div>
          </div>
        </div>

        <div style={{ background: "var(--surface-raised)", borderRadius: "var(--radius-lg)", padding: "8px 14px 14px", marginBottom: 12 }}>
          <FareRow label="Ride fare" amount={`$${base.toFixed(2)}`} />
          <FareRow label="Tax & fees" amount={`$${tax.toFixed(2)}`} />
          {config.multiLeg && <FareRow label="Cost-share credit" amount="–$2.00" muted />}
          <div style={{ borderTop: "1px solid var(--separator)", margin: "4px 0 0" }}></div>
          <FareRow label="Total" amount={`$${fare.toFixed(2)}`} total />
        </div>

        <div style={{ background: "var(--surface-raised)", borderRadius: "var(--radius-lg)", overflow: "hidden", marginBottom: 12 }}>
          <ListRow leading={<IconCircle color="neutral" size={32}>{Icon("apple", { width: 16, height: 16 })}</IconCircle>}
            title="Apple Pay" value="default" chevron divider={false} />
        </div>

        {/* rate */}
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8, marginBottom: 16 }}>
          <span style={{ fontFamily: "var(--font-sans)", fontSize: 14, color: "var(--text-secondary)" }}>Rate your driver</span>
          <div style={{ display: "flex", gap: 6 }}>
            {[1, 2, 3, 4, 5].map((n) => (
              <button key={n} onClick={() => setRating(n)} style={{ background: "none", border: "none", padding: 2, cursor: "pointer" }}>
                <svg width="28" height="28" viewBox="0 0 24 24" fill={n <= rating ? "var(--star)" : "var(--fill)"}>
                  <path d="M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.8 5.9 21.4l1.4-6.8L2.2 9.9l6.9-.8z" />
                </svg>
              </button>
            ))}
          </div>
        </div>

        <Button variant="primary" size="lg" shape="capsule" fullWidth onClick={onPay}>Pay ${fare.toFixed(2)}</Button>
        <div style={{ textAlign: "center", marginTop: 10, fontFamily: "var(--font-sans)", fontSize: 12, color: "var(--text-tertiary)" }}>
          Secured by Stripe
        </div>
      </BottomSheet>
    );
  }

  Object.assign(window, { MatchingSheet, EnrouteSheet, CompleteSheet });
})();
