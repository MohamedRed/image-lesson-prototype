First-line one-sentence: A compact star rating with fractional fill and an optional numeric value, used on driver cards.

```jsx
<RatingStars value={4.8} />
<RatingStars value={4.8} showValue={false} size={12} />
```

Fills stars proportionally to `value / max`; the yellow fill uses the iOS system yellow.
