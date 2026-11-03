# Draft Spec: AI Model Catalog & Ranking Module

Status: idea — parked, not scheduled. Captured 2026-11-03 from a rough external draft.

## QuotAI fit (notes, not part of the original draft)

- Original draft assumes a web app (server-side `/api/*` endpoints, SQLite, scheduler). QuotAI is a local macOS app — endpoints in §7 become local service/view-model surfaces, SQLite can stay client-side, and the daily sync becomes a background refresh or on-demand "sync now".
- Sources are still valid: Cursor SDK/model list for discovery, OpenRouter `GET /api/v1/models` for metadata, Artificial Analysis API for benchmarks/pricing.
- MVP slice for QuotAI would be: discover Cursor models → enrich → normalized sortable table + cost estimator. Matching confidence, snapshots, and alias config can follow.
- Needs a decision before implementation: is a model catalog a natural QuotAI feature (how does it relate to quoting/quotes app domain) or a standalone helper?

---

## 1. Overview

Build a module that automatically discovers the **third-party AI models available in the user's Cursor account**, enriches them with independent pricing, capability, and benchmark data, and presents a clear, sortable comparison. The module should distinguish Cursor's first-party models (for example Grok and Composer) from external models such as Claude, GPT, and Gemini.

The initial version will be read-only: it collects, normalizes, stores, and displays model data. Later versions can add user-defined rankings, cost estimates, and automated model-selection recommendations.

## 2. Goals

- Automatically retrieve the models available to the authenticated Cursor account.
- Exclude Cursor first-party models and generic router entries from the "external models" view.
- Enrich each model with price, context length, supported parameters, benchmark scores, and latency/throughput data.
- Normalize model identities across Cursor, OpenRouter, and Artificial Analysis.
- Store historical snapshots so users can see price and ranking changes over time.
- Provide a clean UI/API for filtering, sorting, and comparing models.

## 3. Non-goals

- The first version will not benchmark models by sending coding tasks through Cursor.
- It will not provide a general chat-completions proxy.
- It will not make purchasing or provider-selection decisions automatically.
- It will not scrape Cursor's website; it should use Cursor's supported SDK/API where available.

Cursor's SDK is an agent SDK rather than a standalone inference or chat-completions API, so the app should treat Cursor as the source of model availability, not necessarily as the source of fair model benchmarks.

## 4. Data sources

| Source | Purpose | Access method |
|---|---|---|
| Cursor SDK / API | Discover models available to the user's account, including parameters and variants | `Cursor.models.list()` or `GET /v1/models` for Cloud Agents |
| Artificial Analysis | Independent intelligence, coding, speed, latency, throughput, and pricing metrics | Documented model-data API; free tier includes headline indices, median performance, and input/output prices |
| OpenRouter | Canonical model metadata, context length, supported parameters, architecture, and detailed pricing | `GET /api/v1/models`; returns standardized model objects |
| User configuration | API keys, preferred providers, filters, aliases, and display preferences | Local encrypted settings or server-side secrets |

OpenRouter model records include `id`, `canonical_slug`, `name`, `context_length`, `architecture`, `pricing`, `top_provider`, rate limits, supported parameters, and default parameters.

## 5. Functional requirements

### 5.1 Cursor model discovery

The system shall:

1. Authenticate using a user-provided Cursor API key.
2. Retrieve the available model catalog.
3. Store the raw API response, including retrieval timestamp.
4. Identify and label Cursor first-party models.
5. Identify generic router/auto entries, such as `auto` or `auto-smart`.
6. Produce a filtered list of external models available in Cursor.

Cursor's own models currently include Grok 4.7, Grok 4.6, Grok 4.5, and Composer 2.5; external models include models from providers such as OpenAI, Anthropic, and Google.

### 5.2 External metadata enrichment

For every external Cursor model, the system shall attempt to retrieve:

- Canonical model name and provider.
- Input price per million tokens.
- Output price per million tokens.
- Cache-read and cache-write prices, where available.
- Context window size.
- Supported API parameters.
- Modality support, such as text, image input, or reasoning.
- Benchmark scores, especially coding and intelligence indices.
- Median latency and output throughput.
- Data-source confidence and last-updated timestamp.

Artificial Analysis provides independent benchmark, pricing, latency, throughput, availability, and model-metadata data through a documented API.

### 5.3 Model identity matching

The system shall map Cursor model identifiers to external canonical model records using:

1. Exact identifier match.
2. Configured alias table.
3. Normalized-name matching.
4. Provider plus family/version matching.
5. Manual user confirmation for uncertain matches.

Each match shall store a confidence level:

- `exact`
- `high`
- `medium`
- `low`
- `unmatched`

The system must not silently merge a Cursor model with an external record when confidence is `low` or `unmatched`.

### 5.4 Snapshot history

The system shall store a new snapshot at a configurable interval, defaulting to daily.

Each snapshot shall preserve:

- Cursor catalog response.
- Artificial Analysis response.
- OpenRouter response.
- Match results.
- Computed metrics.
- Snapshot timestamp.
- Source API versions/endpoints.

This allows the app to show trends such as "Model X became 20% cheaper" or "Model Y improved its coding benchmark score."

### 5.5 Comparison views

The UI shall provide:

- A table of all available external Cursor models.
- Filters by provider, context length, price, benchmark score, and supported capabilities.
- Sorting by price, coding score, intelligence score, latency, throughput, and value score.
- A model-detail view showing all available metrics and source links.
- A side-by-side comparison view for two to five models.
- A cost estimator using user-defined input/output token assumptions.

### 5.6 Cost estimation

The system shall calculate estimated task cost using:

\[
\text{estimated cost} =
\frac{i \times p_i + o \times p_o + c_r \times p_{cr} + c_w \times p_{cw}}{1{,}000{,}000}
\]

Where:

- \(i\) = input tokens
- \(o\) = output tokens
- \(c_r\) = cached input tokens read
- \(c_w\) = cached input tokens written
- \(p_i\) = input price per million tokens
- \(p_o\) = output price per million tokens
- \(p_{cr}\) = cache-read price per million tokens
- \(p_{cw}\) = cache-write price per million tokens

OpenRouter pricing includes prompt, completion, request, image, web-search, reasoning, cache-read, and cache-write fields; pricing values are expressed in USD per token/request/unit.

## 6. Data model

### `models`

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Internal model record ID |
| `cursor_model_id` | text | Cursor model identifier |
| `display_name` | text | Human-readable model name |
| `provider` | text | Model provider, e.g. Anthropic, OpenAI, Google |
| `is_first_party` | boolean | Whether Cursor provides the model directly |
| `is_router` | boolean | Whether it is an auto/router entry |
| `canonical_external_id` | text | Matched external model ID |
| `match_confidence` | enum | `exact`, `high`, `medium`, `low`, `unmatched` |
| `first_seen_at` | timestamp | When first observed in Cursor |
| `last_seen_at` | timestamp | Most recent Cursor observation |

### `model_snapshots`

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Snapshot ID |
| `model_id` | UUID | Foreign key to `models` |
| `captured_at` | timestamp | Snapshot time |
| `input_price_per_m` | numeric | Input price per 1M tokens |
| `output_price_per_m` | numeric | Output price per 1M tokens |
| `cache_read_price_per_m` | numeric | Cache-read price per 1M tokens |
| `cache_write_price_per_m` | numeric | Cache-write price per 1M tokens |
| `context_length` | integer | Maximum context tokens |
| `intelligence_score` | numeric | General intelligence benchmark |
| `coding_score` | numeric | Coding-specific benchmark |
| `median_output_tokens_per_second` | numeric | Throughput |
| `median_time_to_first_token_ms` | numeric | Latency |
| `supported_parameters` | JSON | Supported request parameters |
| `raw_sources` | JSON | Raw source payloads or references |

## 7. API design

### `GET /api/models`

Returns the current normalized model catalog.

Query parameters:

- `provider`
- `min_context`
- `max_input_price`
- `max_output_price`
- `min_coding_score`
- `sort`
- `order`
- `include_first_party`
- `include_router`

Example:

```http
GET /api/models?provider=anthropic&min_context=200000&sort=coding_score&order=desc
```

### `GET /api/models/{model_id}`

Returns full current metadata, benchmark data, pricing, source confidence, and historical trend data.

### `GET /api/models/{model_id}/history`

Returns snapshots over time.

### `POST /api/models/{model_id}/match`

Allows an authenticated user to confirm or correct an external-model match.

### `POST /api/sync`

Triggers an on-demand synchronization job.

## 8. Synchronization workflow

1. Fetch Cursor model catalog.
2. Create or update `models` records.
3. Mark missing models as no longer available, but retain history.
4. Fetch OpenRouter model metadata.
5. Fetch Artificial Analysis benchmark and pricing data.
6. Match Cursor models to external records.
7. Calculate derived metrics.
8. Save a snapshot.
9. Invalidate or refresh cached API responses.
10. Emit a `models.updated` event for the UI.

The scheduler should run daily by default, with manual sync available in the UI.

## 9. Matching algorithm

### Normalization

Convert model names to a comparable form:

```text
Claude Sonnet 5.5 → claude-sonnet-5-5
GPT-5.6 Terra → gpt-5-6-terra
Gemini 3.1 Pro → gemini-3-1-pro
```

### Matching order

1. Exact Cursor ID to OpenRouter `id`.
2. Exact Cursor ID to OpenRouter `canonical_slug`.
3. Alias-table lookup.
4. Normalized-name exact match.
5. Provider plus normalized family/version match.
6. Fuzzy match with a configurable threshold.
7. Mark as `unmatched`.

### Alias configuration

Users should be able to define aliases such as:

```json
{
  "claude-sonnet-5-5": "anthropic/claude-sonnet-5.5",
  "gpt-5-6-terra": "openai/gpt-5.6-terra",
  "gemini-3-1-pro": "google/gemini-3.1-pro"
}
```

## 10. Ranking metrics

The app should not rely on one universal "best model" score. It should expose separate rankings:

| Ranking | Formula or basis | Use case |
|---|---|---|
| Best coding model | Highest coding benchmark score | Code generation and refactoring |
| Best value | Coding score divided by blended cost | Cost-conscious development |
| Fastest | Lowest median time to first token or highest output tokens/sec | Interactive agent use |
| Longest context | Highest context window | Large repositories or long sessions |
| Cheapest | Lowest blended cost for a user-defined workload | Bulk or routine tasks |
| Best overall | User-weighted composite score | Personal preference |

A useful default blended-cost workload could be:

```text
100,000 input tokens
10,000 output tokens
80% of input tokens served from cache
```

## 11. Security and privacy

- Store API keys encrypted at rest.
- Never expose provider API keys to the browser.
- Use server-side proxy endpoints for all external API calls.
- Cache external responses to reduce API usage and comply with provider guidance.
- Log only non-sensitive request metadata.
- Allow users to delete stored account-linked data.
- Do not place third-party API keys in client-side code.

Artificial Analysis's free API is intended for analysis and has usage limits; responses should be cached rather than requested repeatedly from a client application.

## 12. Error handling

| Situation | Behaviour |
|---|---|
| Cursor API unavailable | Retain last known catalog; show stale-data warning |
| Artificial Analysis unavailable | Show Cursor/OpenRouter data; hide unavailable benchmark fields |
| OpenRouter unavailable | Show Cursor/Artificial Analysis data; hide missing metadata |
| Model unmatched | Display model with `unmatched` badge and manual-match option |
| Conflicting prices | Prefer Cursor-listed price for Cursor usage; retain external price separately |
| Rate limit | Use exponential backoff and cached data |
| Invalid API key | Prompt user to update credentials |

## 13. MVP scope

### Included

- Cursor model discovery.
- First-party/router filtering.
- OpenRouter metadata enrichment.
- Artificial Analysis benchmark and pricing enrichment.
- Basic alias and normalized matching.
- SQLite storage.
- Daily sync.
- Sortable model table.
- Model-detail view.
- Basic cost estimator.

### Deferred

- Automated coding benchmarks through Cursor.
- Multi-user teams and role-based access.
- Model recommendation engine.
- Historical charts.
- Slack/email price-change alerts.
- Provider fallback simulation.
- Full admin dashboard.

## 14. Acceptance criteria

- The app can retrieve and display the external models available in the authenticated user's Cursor account.
- Cursor first-party and router models are clearly separated from external models.
- Each external model displays price, context, benchmark, and speed data where available.
- Model matches include a confidence level and can be manually corrected.
- The app preserves historical snapshots.
- The UI can sort and filter models by price, context, coding score, intelligence score, and speed.
- A user can estimate the cost of a defined workload for any displayed model.
- The app continues to display the last successful data snapshot when an external source is temporarily unavailable.
