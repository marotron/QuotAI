# Fair-share bars + trajectory — prototype

**Question:** Two bar encodings — **δ vs ideal diagonal**, and **burnRatio** vs fair.

**Data:** Synthetic hourly readings across **elapsed 0 → 100%**. Irregular idle/burst regimes (uneven lengths, random target swings) so the curve mixes above and below ideal without a metronomic zig-zag.

**Prototype:** [`index.html`](index.html)

```bash
open .scratch/quotai/pace-fair-share-bars-prototype/index.html
```

Query: `?variant=A|B|C&meter=all|cursor|other|grok&H=1|2|4|6|8&bars=diagonal|ratio|delta|absolute`

## Experiment A — default `bars=diagonal`

Map the trajectory’s two ideal-diagonal triangles onto the bars chart halves:

| Triangle (trajectory) | Bars half |
| --- | --- |
| `(0,0)–(0,100)–(100,100)` over | upper half → `[0, +1]` |
| `(0,0)–(100,0)–(100,100)` under | lower half → `[−1, 0]` |

At elapsed `e`, normalize within that vertical slice so the triangle fills the half:

| Term | Formula |
| --- | --- |
| burn | `usage_b − usage_a` = used(slotEnd) − used(slotStart) |
| fairShare | `100 × H / periodHours` |
| δ (raw) | `used% − elapsed%` · stats / table only |
| △ over | `(used − e) / (100 − e)` ∈ `[0, 1]` · **+1 = used 100%** |
| △ under | `−(e − used) / e` ∈ `[−1, 0]` · **−1 = used 0%** |
| bar Y | △ map · mid **0 = on the ideal line** · frame fixed `±1` |
| walk | `δ₀ = used₀ − elapsed₀`; each slot `δ ← δ + burn − fairShare`; `tri = △(e,u)` |

Early elapsed: over-slice is tall → small raw gaps look small. Late elapsed: over-slice shrinks toward `(100,100)` → same raw gap fills more of the upper half.

**Bar geometry:** thickness (horizontal slot width) stays **constant** (`= fairShare` / H). Only **length** (vertical |△| from mid) follows the triangle warp.

## Experiment B — `bars=ratio`

Per-slot burn intensity relative to fair allowance.

| Term | Formula |
| --- | --- |
| burn | `usage_b − usage_a` |
| fairShare | `100 × H / periodHours` |
| burnRatio | `burn / fairShare` · **1× = exact fair** |
| 1d form | `dayΔ% / quotaPerDay%` (same formula with H = 24) |
| under | ratio &lt; 1 · blue |
| over | ratio &gt; 1 · orange |

Note: dial currently has H ∈ {1,2,4,6,8}. The 1d form is identical math; add H=24 when regenerating bucket data if needed.

## Legacy encodings

| Mode | Bar |
| --- | --- |
| `delta` | `burn − fairShare` (per-slot unused fair) |
| `absolute` | burn from 0 + blue gap to fair |

## Corridors

Same `PaceAlertBands` math as the app (Cursor 25/95/25/95; Grok 35/85/40/90).

| Chart | Encoding |
| --- | --- |
| Bars `diagonal` | Corridor edges via same △ map (`triangleMap(e, overUsed·100)`) |
| Bars `ratio` | Horizontal significant bands at 0.75× / 1.30× |
| Trajectory / overlay | Classic used% × elapsed% fills (orange over / blue under @ 16%) |

## Layout variants

| Key | Layout |
| --- | --- |
| A | Stacked — bars, then trajectory |
| B | Dual pane — shared elapsed axis |
| C | Overlay — bars under used/ideal; mid-plot = δ=0 or 1× |

## Related

- Issue: [../issues/19-pace-surplus-vs-ideal-redesign.md](../issues/19-pace-surplus-vs-ideal-redesign.md)
