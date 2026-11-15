# Direct Swift quota feasibility probe

Throwaway experiment, not a product implementation. Does native browser OAuth followed by a subscription quota GET work without installing or bundling Codex?

Run from the repo root:

```sh
zsh .scratch/openai-quota/direct-swift-spike/run.sh
```

It opens the system browser. Complete OpenAI sign-in there; the terminal prints only quota percentages, window durations and reset times. Closing/exiting the probe discards credentials. It does not read existing Codex/ChatGPT credential files, import browser cookies, save tokens, invoke a model, redeem credits, or change QuotAI's settings/history.

Compile and exercise synthetic parsing/PKCE checks without signing in or contacting OpenAI:

```sh
zsh .scratch/openai-quota/direct-swift-spike/run.sh --offline-check
```

The native OAuth parameters follow the public Codex implementation at `d32063f96c2dff1dc96af839b3952abb6acfeda4`, with the actual `quotai` originator, a fresh nonce and narrower identity/offline scopes (no connector permissions). This tests the existing public-native Codex OAuth client flow; it is not a registered own-app Sign in with ChatGPT integration or evidence of a supported standalone quota API. See the [research findings](../../quotai/research/openai-quota-sources-2026-11-14.md).

The callback binds only 127.0.0.1 on upstream-supported port 1455, falling back to 1457. It validates the path, host, state and single-valued callback parameters. Token requests use ephemeral networking without cookie storage or redirects. ID-token RS256 signature, issuer, audience, expiry and nonce are checked against OpenAI's public signing keys before account routing is used. Errors never include token responses or raw quota payloads.

The prototype deliberately does not persist or refresh tokens. Keychain ownership, refresh rotation, revocation, scheduling, Settings and menu-bar integration remain production work after live feasibility is established. The runner compiles a small native executable into the temporary directory; its size can be measured independently of the full 218 MB app-server.
