First-line one-sentence: A frosted-glass material panel that floats over the live map, mirroring SwiftUI's .ultraThinMaterial — the home for HUD chips and the voice pill.

```jsx
<GlassPanel material="thin" radius="var(--radius-full)" padding={8}>
  <Badge color="success" dot>Connected</Badge>
</GlassPanel>
```

`material`: `thin` · `regular` (default) · `thick`. Always place it over the map, never on a solid sheet.
