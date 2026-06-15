First-line one-sentence: The base filled surface card — soft shadow, no border, with an accent stroke for the selected/active state.

```jsx
<Card>…</Card>
<Card active onClick={() => choose("premium")}>Premium ride</Card>
```

`active` swaps the shadow for the accent selection stroke; `raised` uses the tertiary surface color for nested rows; pass `onClick` to make it pressable.
