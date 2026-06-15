First-line one-sentence: One line of the Stripe fare breakdown — label and tabular amount, with an emphasised total variant.

```jsx
<FareRow label="Ride fare" amount="$11.49" />
<FareRow label="Tax & fees" amount="$1.01" />
<div style={{borderTop:"1px solid var(--separator)"}} />
<FareRow label="Total" amount="$12.50" total />
```
