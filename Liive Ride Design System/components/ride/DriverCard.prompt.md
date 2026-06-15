First-line one-sentence: The matched-driver summary card — avatar, name, rating, vehicle and plate, with an ETA pill and a trailing action slot.

```jsx
<DriverCard name="John Driver" rating={4.8} vehicle="Toyota Camry · Blue"
  plate="ABC 123" eta="4 min" speaking
  trailing={<Button variant="tinted" icon={<i data-lucide="phone"/>} />} />
```

Composes `Avatar` + `RatingStars`. Set `speaking` to ring the avatar while the driver is on the voice channel.
