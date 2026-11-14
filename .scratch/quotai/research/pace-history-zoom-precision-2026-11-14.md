# Pace history zoom precision — 14 November 2026

## Evidence from the plotting data

The 16:25 screenshot highlighted a Cursor hover reading of 76.87% while the rendered trajectory appeared higher. This investigation uses the actual `pace-history.json`, not image-derived coordinates.

- Source: `~/Library/Application Support/dev.marotron.QuotAI/pace-history.json`.
- Frozen audit input: `/private/tmp/quotai-rc4-pace-history.json`, containing 2,759 Cursor samples at capture.
- Audit executable/source: `/private/tmp/quotai-curve-audit` and `/private/tmp/quotai-curve-audit.swift`, linked to the built QuotAICore framework, exercising the real downsample and interpolation functions.
- Target: 9 November 2026 20:37 London/UTC, elapsed 67.94758064516128%.

Surrounding observations:

| Observed time | Cursor used % |
|---|---:|
| 19:55:54 | 76.7088888888889 |
| 20:09:43 | 76.7088888888889 |
| 20:19:09 | 76.7088888888889 |
| 20:49:10 | 76.98222222222222 |
| 21:00:52 | 77.14 |
| 21:30:53 | 77.84 |

The original-sample linear interpolation at 20:37 is **76.87139987743701%**, which correctly rounds to the tooltip's **76.87%**. It is an interpolated value, not a measurement taken at 20:37.

## Cause

Before RC4, zoomed quota lines used LTTB reduction capped at 200 points followed by Charts monotone interpolation. Hover markers and tooltip values used linear interpolation of the original history. Removing source vertices changes the shape before smoothing; monotone rendering further differs from the hover interpolation.

For a representative 63–73% elapsed window there are 956 original interior readings, of which the old reducer omits 758. Linear interpolation of the reduced points at the target is **77.19827274666287%**, already inconsistent with the original 76.8714% before accounting for Charts smoothing. This is a data-backed discrepancy; the precise old smoothed pixel value was not inferred from the screenshot or claimed measured.

## RC4 correction and audit

Zoomed quota lines now use visible original samples with one neighboring sample on each side, without Y quantization or a point-count limit. Exactly collinear middle points are removed losslessly (typically repeated plateau observations). Quota lines use linear interpolation while zoomed, matching the hover calculation. Overview reduction/smoothing remains unchanged. Hover balls use 0.5 color opacity.

| Elapsed window | Original interior readings | RC4 plotted points, including context | RC4 maximum error at original readings | RC4 maximum error at checked interval midpoints |
|---|---:|---:|---:|---:|
| 60–70% | 198 | 107 | 0 | 0 |
| 61–71% | 963 | 166 | 0 | 0 |
| 62–72% | 955 | 158 | 0 | 0 |
| 63–73% | 956 | 162 | 0 | 0 |
| 64–74% | 1,430 | 238 | 0 | 0 |
| 65–75% | 1,954 | 268 | 0 | 0 |
| 66–76% | 1,943 | 267 | 0 | 0 |
| 67–77% | 2,044 | 255 | 0 | 0 |

Every window also reproduces the target 76.87139987743701% exactly in this audit. Midpoints are compared using the original interpolation function at the same floating-point X coordinate, rather than assuming the floating-point midpoint maps to precisely t=0.5.

Regression tests compare original and zoomed geometry beyond the former point budget, including domain edges and between-sample positions. Another test verifies that non-collinear readings exceeding 200 points are never discarded. `make test` passes. RC4/build 48 was built and locally relaunched; no release/tag/commit was created. These are data/geometry and build checks, not a completed native screenshot comparison.
