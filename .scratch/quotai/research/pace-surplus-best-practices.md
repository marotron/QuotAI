# Pace surplus vs ideal — industry patterns

Research for GitHub [#47](https://github.com/marotron/QuotAI/issues/47) / scratch `19-pace-surplus-vs-ideal-redesign.md`.  
Date: 2026-11-09.

## QuotAI today (baseline)

Ideal even burn (locked in `04-burn-rate-formula.md`):

\[
t = \mathrm{clamp}\!\left(\frac{\mathrm{now}-\mathrm{start}}{\mathrm{end}-\mathrm{start}},\,\varepsilon,\,1\right),\quad
u = \frac{\%\ \mathrm{used}}{100}
\]

Primary headline (`PaceCalculator`):

\[
r = \frac{u}{t}
\]

Corridor alerts (`PaceAlertBands`) already live on the used×elapsed plane: over/under curves around the even-pace diagonal \(u = t\).

## Industry patterns

### 1. Earned Value Management (PMI) — closest formal twin

Sources: [PMI — Earned Value Management guide](https://www.pmi.org/blog/earned-value-management), [PMI learning library — The earned schedule](https://www.pmi.org/learning/library/evm-cpm-evaluate-project-performance-6355).

| Metric | Formula | Role |
|--------|---------|------|
| Schedule variance (SV) | \(\mathrm{EV} - \mathrm{PV}\) | **Absolute** ahead/behind plan |
| Schedule performance index (SPI) | \(\mathrm{EV} / \mathrm{PV}\) | **Ratio** pace vs plan |
| Schedule variance % | \(\mathrm{SV} / \mathrm{PV}\) | Relative variance |

Mapping to QuotAI (quota as “budgeted work” over the period):

| EVM | QuotAI |
|-----|--------|
| \(\mathrm{PV}\) (planned by now) | ideal used \(t\) (or \(100t\%\)) |
| \(\mathrm{EV}\) (done by now) | actual used \(u\) |
| \(\mathrm{SV}\) | surplus \(\delta = u - t\) |
| \(\mathrm{SPI}\) | today’s ratio \(r = u / t\) |

PMI treats **both** as first-class: variance for “how far,” index for “how efficient.” Best practice is not ratio-or-delta — it is **delta for distance, index as companion**.

### 2. Google Ads — forecast status, not a raw pace %

Source: [About budget pacing insights](https://support.google.com/google-ads/answer/13685469?hl=en).

Statuses: **Limited by budget** · **Budget remaining** · **On track**. Framed as projected monthly utilization vs budget goals, with recommendations — not “you are at 130% pace.” Total-budget flights re-pace remaining spend evenly after under/over days ([campaign total budgets FAQ](https://support.google.com/google-ads/answer/15137812?hl=en)).

Takeaway for QuotAI: user-facing language prefers **outcome categories + forecast**, while the internal control loop is still “spend evenly over remaining time.”

### 3. Meta Ads — even (standard) pacing as default

Sources: [Pacing and Scheduling (Marketing API)](https://developers.facebook.com/docs/marketing-api/bidding/overview/pacing-and-scheduling/), [Bid and budget pacing](https://www.facebook.com/business/help/571961726580148).

Standard pacing adjusts bids from **budget left and time left** so delivery lasts the flight. Accelerated / `no_pacing` removes that. Ideal reference is again **even consumption over the period**.

### 4. AWS Budgets / FinOps — actual vs forecast vs threshold

Sources: [Managing costs with AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html), [Notification API](https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/API_budgets_Notification.html).

Alerts split:

- `ACTUAL` — spend already past a % or absolute of budget
- `FORECASTED` — projected end-of-period spend past threshold

No published “pace ratio” in the public API. The product spine is **budget remainder + forecast breach**.

## Implications for QuotAI variants

| ID | Metric | Equation (fractions) | Pros | Cons |
|----|--------|----------------------|------|------|
| A | Absolute surplus | \(\delta = u - t\) | Matches user ask; EVM SV; same units as chart Y−X; easy “+12 pp” | Early period: small absolute can hide wild rate |
| B | Ratio (today) | \(r = u / t\) | EVM SPI; scale-free; good for dials | Misread as “% of quota”; explodes near \(t\approx 0\) |
| C | Relative surplus | \(\delta / t\) or \(\delta / (1-t)\) | Normalizes by planned or remaining | Still ratio-ish; harder copy |
| D | Corridor distance | \(u - u_{\mathrm{over}}(t)\), etc. | Already shipped for alerts | Threshold geometry, not a single headline |
| E | Forecast / exhaust | project \(u(1)\) or days-to-100% | AWS-style; answers “will I make it?” | Needs burn assumption; noisier |

**Comment on the user’s approach:** Starting from surplus vs ideal is the right *primary* story. It aligns the number people see with the plane QuotAI already draws, and with how PMI names “how far off plan.” Keep a ratio or forecast as secondary; do not delete corridors — use surplus for **display**, corridors (+ optional forecast) for **alerts**.

## Recommended stack (proposal, not locked)

1. **Display primary:** \(\delta\) in percentage points (`+12` / `−8` / `~0`)
2. **Alert primary:** existing corridor kind (D), optionally also \(|\delta| > \tau\)
3. **Secondary:** days-to-exhaust / projected empty (E)
4. **Optional debug / advanced:** ratio \(r\) (B)

## Sources

- PMI EVM overview: https://www.pmi.org/blog/earned-value-management
- PMI earned schedule paper: https://www.pmi.org/learning/library/evm-cpm-evaluate-project-performance-6355
- Google Ads budget pacing insights: https://support.google.com/google-ads/answer/13685469?hl=en
- Google Ads campaign total budgets: https://support.google.com/google-ads/answer/15137812?hl=en
- Meta pacing API: https://developers.facebook.com/docs/marketing-api/bidding/overview/pacing-and-scheduling/
- AWS Budgets: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html
