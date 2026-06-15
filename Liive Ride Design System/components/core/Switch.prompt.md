First-line one-sentence: The iOS toggle switch — system green when on, grey when off.

```jsx
const [on, setOn] = React.useState(true);
<Switch checked={on} onChange={setOn} />
```

Typically used as the `trailing` element of a `ListRow` (e.g. "Female-only pool", "Record audio").
