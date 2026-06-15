First-line one-sentence: The iOS segmented control with a sliding selected pill, for mode switches and ride tiers.

```jsx
const [mode, setMode] = React.useState("rider");
<SegmentedControl options={["rider", "driver"]} value={mode} onChange={setMode} />
<SegmentedControl options={[{label:"Pool",value:"pool"},{label:"Premium",value:"premium"}]} value={tier} onChange={setTier} />
```
