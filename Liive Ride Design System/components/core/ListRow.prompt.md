First-line one-sentence: The iOS grouped-list row with a leading icon, title/subtitle, a trailing value, control or chevron, and tap-dim feedback.

```jsx
<ListRow leading={<IconCircle color="accent"><i data-lucide="users"/></IconCircle>}
         title="Passengers" value="2" chevron onClick={...} />
<ListRow title="Female-only pool" trailing={<Switch checked />} divider={false} />
```

Compose multiple rows inside a `Card` (padding 0) to build a grouped list. Set `divider={false}` on the last row.
