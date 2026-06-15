First-line one-sentence: A capsule badge for status and metadata, with semantic colors, tinted or solid fills, and an optional live status dot.

```jsx
<Badge color="success" dot>Connected</Badge>
<Badge color="warning" solid>Surge ×1.5</Badge>
<Badge color="accent">2 legs</Badge>
```

Color: `neutral` (default) · `accent` · `success` · `warning` · `danger` · `info`.
`solid` for a filled badge; `dot` for a leading status dot (used for the LiveKit connection state). Pass `icon` for a leading glyph.
