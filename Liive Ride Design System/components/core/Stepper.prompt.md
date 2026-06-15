First-line one-sentence: The iOS −/+ stepper for small integer counts like passengers, luggage and pets.

```jsx
const [seats, setSeats] = React.useState(1);
<Stepper value={seats} min={1} max={4} onChange={setSeats} />
```

Pair with a `ListRow` `value` showing the current count, or use the stepper as the row's `trailing`.
