First-line one-sentence: The always-reachable emergency SOS control — a red disc with a continuous pulse halo and press-shrink, fixed during an active ride.

```jsx
<SOSButton onActivate={() => setConfirmOpen(true)} />
<SOSButton size={56} label={false} />
```

Uses SF Pro Rounded for the "SOS / HELP" lettering and the danger color + glow shadow. Pulse respects `prefers-reduced-motion`.
