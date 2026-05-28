#!/bin/bash
# Rust Skills Meta-Cognition Hook  (Claude Code UserPromptSubmit)
#
# This hook's stdout is injected into the model's context for the current turn.
# It used to emit the full "META-COGNITION ROUTING" block UNCONDITIONALLY on
# every prompt, adding ~600-800 tokens of imperative ("MANDATORY/CRITICAL/You
# MUST") text even on non-Rust prompts. That carried three costs:
#   1. it competes for attention against the actual task;
#   2. a fake "MANDATORY" every turn desensitises the agent to the very
#      injection channel that real system-reminders rely on; and
#   3. it risks the agent emitting Rust "Reasoning Chain" theatre on prompts
#      that have nothing to do with Rust.
#
# Fix: read the submitted prompt from stdin (the UserPromptSubmit JSON) and emit
# the block ONLY when the prompt carries Rust-error / Rust-domain signals.
# Otherwise emit nothing. Every code path exits 0 -- a no-match and empty stdin
# are normal outcomes, not errors.
#
# The signal set below mirrors the block's own "Layer 1 Signals" plus the
# Rust-specific names from its "Layer 3 Domain" table. Generic domain words
# (HTTP, docker, ML, payment, ...) are intentionally NOT matched: firing on them
# would re-introduce exactly the per-turn noise this gate exists to remove.
# Send / Sync are matched case-sensitively and word-bounded (the Rust marker
# traits) so ordinary English "send" / "sync" prose does not trip the gate.

set -uo pipefail

# Slurp whatever Claude Code piped in. Never block or fail on empty stdin.
input="$(cat 2>/dev/null || true)"

# Extract the user's prompt. Prefer jq; if jq is absent or the payload is not
# valid JSON, fall back to scanning the raw blob (the prompt text is embedded in
# the JSON, so signal-grepping it still works, at a minor false-positive cost).
if command -v jq >/dev/null 2>&1; then
    if ! prompt="$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)"; then
        prompt="$input"
    fi
else
    prompt="$input"
fi

# Nothing to inspect (empty stdin or empty prompt) -> stay silent, exit cleanly.
[ -n "$prompt" ] || exit 0

# Case-insensitive Rust signals: error codes, borrow/ownership/type vocabulary,
# Rust crates/tooling, the .rs extension, attribute syntax, and the word "rust".
ci_re='E0[0-9]{3,4}|\bborrow|\blifetime\b|moved[[:space:]]+value|cannot[[:space:]]+be[[:space:]]+sent|does[[:space:]]+not[[:space:]]+live[[:space:]]+long[[:space:]]+enough|trait[[:space:]]+bound|impl[[:space:]]+trait|\basync[[:space:]]+fn\b|\bcargo\b|\bclippy\b|\brustc\b|\.rs\b|\baxum\b|\bactix\b|\btokio\b|\bclap\b|\bserde\b|\bno_std\b|\bunsafe\b|\bwasm\b|#\[|\brust\b'

# Case-sensitive signals: the Send / Sync marker traits (capitalised, bounded).
cs_re='\bSend\b|\bSync\b'

# No Rust signal in the prompt -> emit nothing and exit 0 (default to silence).
if printf '%s' "$prompt" | grep -qiE "$ci_re" \
    || printf '%s' "$prompt" | grep -qE "$cs_re"; then
    : # Rust signal present -> fall through and emit the block verbatim.
else
    exit 0
fi

cat << 'EOF'

=== RUST SKILLS DISPLAY FORMAT ===
When showing Rust Skills loaded, display in this EXACT order:
1. FIRST: "🦀 Rust Skills Loaded" text
2. THEN: The Ferris crab ASCII art BELOW the text
The text must be ABOVE the crab, not below.
===

=== MANDATORY: META-COGNITION ROUTING ===

CRITICAL: You MUST follow the COMPLETE meta-cognition framework.
Partial compliance (only loading L1 skill) is NOT acceptable.

## STEP 1: IDENTIFY ENTRY LAYER + DOMAIN

### Layer 1 Signals (Start here, trace UP):
- Error codes: E0382, E0597, E0277, E0499, etc.
- Keywords: cannot be sent, moved value, borrowed, lifetime

### Layer 3 Domain Signals (MUST also load domain skill):

| Keywords in Question | Domain Skill to Load |
|---------------------|---------------------|
| Web API, HTTP, REST, axum, actix, handler, router | domain-web |
| payment, trading, fintech, decimal, currency | domain-fintech |
| CLI, command line, clap, terminal | domain-cli |
| embedded, no_std, MCU, firmware | domain-embedded |
| kubernetes, docker, grpc, microservice | domain-cloud-native |
| MQTT, sensor, IoT, telemetry | domain-iot |
| tensor, model, inference, ML | domain-ml |

**CRITICAL**: If domain keywords are present, you MUST load BOTH:
1. The Layer 1 skill (e.g., m07-concurrency)
2. The Layer 3 domain skill (e.g., domain-web)

## STEP 2: EXECUTE TRACING (MANDATORY)

For Layer 1 entry with domain context:

```
L1 Error (e.g., Rc not Send)
    ^ TRACE UP: Why this design constraint?
    ^ Load domain skill (e.g., domain-web)
    ^ Find domain constraint (e.g., "handlers run on any thread")
    v TRACE DOWN: What pattern satisfies constraint?
    v Return to L1 with context-aware solution
```

## STEP 3: MANDATORY OUTPUT FORMAT

Your response MUST include ALL of these sections:

### Reasoning Chain
```
+-- Layer 1: [specific error]
|   Problem: [error description]
|       ^
+-- Layer 3: [domain name] (domain-xxx)
|   Constraint: [what is the domain constraint]
|   Rule: [why this constraint exists]
|       v
+-- Layer 2: Design Choice
    Decision: [design decision based on domain constraint]
```

### Domain Constraints Analysis
- MUST reference specific rules from domain-xxx skill
- Explain WHY this domain has this constraint

### Recommended Solution
- Provide solution that follows domain best practices
- Not just fixing the compile error

## EXAMPLE: Web API + Send Error

Question: "Web API config sharing error: Rc cannot be sent"

CORRECT Response:
```
### Reasoning Chain
+-- Layer 1: Send/Sync Error
|   Problem: Rc<T> cannot be sent between threads
|       ^
+-- Layer 3: Web Domain (domain-web)
|   Constraint: Handlers run on any thread
|   Rule: Shared state must be thread-safe
|       v
+-- Layer 2: Design Choice
    Decision: Use Arc<T> + State extractor

### Domain Constraints Analysis
From domain-web:
- "Rc in state" is a Common Mistake
- Web handlers require Send + Sync
- Recommended: axum State<Arc<T>> pattern

### Recommended Solution
[Code following Web best practices]
```

WRONG Response (stops at L1):
```
Problem: Rc is not Send
Solution: Use Arc
```

## SKILLS TO INVOKE

Always invoke with Skill() tool:
- Skill(rust-router) - First, to get routing
- Skill(m0x-xxx) - Layer 1 skill based on error
- Skill(domain-xxx) - Layer 3 skill based on domain keywords

===================================

EOF
