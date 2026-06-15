First-line one-sentence: The iOS action button — filled accent for primary actions, with tinted, plain and destructive variants and an automatic press (dim + shrink) state.

```jsx
<Button variant="primary" size="lg" shape="capsule" fullWidth>Request Ride</Button>
<Button variant="tinted" icon={<i data-lucide="phone" />}>Call driver</Button>
<Button variant="destructive-plain">Cancel Ride</Button>
```

Variants: `primary` (filled blue, default) · `secondary` (gray fill) · `tinted` (blue on blue-tint) · `plain` (text-only blue link) · `destructive` (filled red) · `destructive-plain` (red text).
Sizes: `sm` 32 · `md` 44 · `lg` 50. Use `shape="capsule"` + `fullWidth` for the bottom-pinned CTA.
Pass `loading` for an inline spinner, `icon` / `iconRight` for leading/trailing glyphs.
