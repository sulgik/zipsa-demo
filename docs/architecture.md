# Zipsa Demo Architecture

This document describes the architecture of the Zipsa cloud demo deployment.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLOUD DEPLOYMENT                                │
│                                                                              │
│  ┌─────────────┐                                                            │
│  │   User      │                                                            │
│  │  (Public)   │────────┐                                                   │
│  └─────────────┘        │                                                   │
│                         ▼                                                   │
│                  ┌──────────────┐                                           │
│                  │    Nginx     │                                           │
│                  │  :80 / :443  │                                           │
│                  └──────┬───────┘                                           │
│                         │                                                   │
│         ┌───────────────┼───────────────┐                                   │
│         │               │               │                                   │
│         ▼               ▼               ▼                                   │
│    ┌─────────┐    ┌───────────┐   ┌───────────┐                            │
│    │   /     │    │ /monitor  │   │  /health  │                            │
│    │ (public)│    │(auth req) │   │  (public) │                            │
│    └────┬────┘    └─────┬─────┘   └─────┬─────┘                            │
│         │               │               │                                   │
│         ▼               ▼               ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐           │
│  │                       ZIPSA CONTAINER                        │           │
│  │                                                              │           │
│  │  ┌──────────────────┐      ┌──────────────────┐             │           │
│  │  │   Relay API      │      │  Monitor (Gradio) │             │           │
│  │  │     :8000        │      │      :7861        │             │           │
│  │  └────────┬─────────┘      └──────────────────┘             │           │
│  │           │                                                  │           │
│  │           ▼                                                  │           │
│  │  ┌──────────────────────────────────────────┐               │           │
│  │  │            Privacy Router                 │               │           │
│  │  │  - Analyzes request content               │               │           │
│  │  │  - Detects PII/sensitive data             │               │           │
│  │  │  - Routes to appropriate LLM              │               │           │
│  │  └────────────────┬─────────────────────────┘               │           │
│  │                   │                                          │           │
│  └───────────────────┼──────────────────────────────────────────┘           │
│                      │                                                       │
│         ┌────────────┴────────────┐                                         │
│         ▼                         ▼                                         │
│  ┌──────────────┐         ┌──────────────┐                                  │
│  │ Local Model  │         │ External LLM │                                  │
│  │(Ollama Cloud)│         │  (Claude)    │                                  │
│  │  or Heuristic│         │              │                                  │
│  └──────────────┘         └──────────────┘                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Nginx Reverse Proxy

**Purpose:** Single entry point, routing, authentication, rate limiting

- **Port 80/443:** Public HTTPS endpoint
- **Route `/`:** Proxies to Zipsa relay API (public access)
- **Route `/monitor`:** Proxies to Gradio dashboard (requires `Authorization: Bearer TOKEN`)
- **Route `/health`:** Health check endpoint (public)
- **Rate limiting:** 10 req/s for API, 5 req/s for monitor

### 2. Zipsa Container

**Source:** Built from [github.com/sulgik/zipsa](https://github.com/sulgik/zipsa)

#### Relay API (:8000)

- OpenAI-compatible API (`/v1/chat/completions`)
- Receives all user requests
- Routes based on privacy analysis

#### Monitor Dashboard (:7861)

- Gradio-based UI
- Real-time request monitoring
- Privacy classification stats
- Admin-only access

### 3. External Services

#### Claude API (Anthropic)

- Primary external LLM
- Used for: complex reasoning, code generation, creative tasks
- Cost: Pay-per-token ($3/M input, $15/M output)

#### Ollama Cloud (Optional)

- Local model endpoint (cloud-hosted)
- Used for: simple queries, PII-containing requests
- Can be disabled for heuristic-only mode

## Data Flow

### Request Processing

1. **User sends request** to `demo.zipsa.ai/v1/chat/completions`
2. **Nginx** rate-limits and proxies to Zipsa
3. **Privacy Router** analyzes the request:
   - Scans for PII (names, emails, addresses, etc.)
   - Evaluates query complexity
   - Checks for sensitive topics
4. **Routing Decision:**
   - **Local-capable + PII detected** → Ollama Cloud (or heuristic response)
   - **Complex reasoning needed** → Claude API
   - **Mixed case** → May split or redact before external
5. **Response** flows back through Nginx to user

### Admin Monitoring

1. **Admin** sends request with `Authorization: Bearer ADMIN_TOKEN`
2. **Nginx** validates token, proxies to Gradio on :7861
3. **Monitor** displays:
   - Live request stream
   - Routing decisions
   - PII detection logs
   - Performance metrics

## Trust Model

### Current State (v1)

```
┌──────────────────────────────────────────────────────────────┐
│                    TRUST BOUNDARY                             │
│                                                               │
│  ┌─────────────┐                                             │
│  │   Zipsa     │  ← Has access to raw PII                    │
│  │   Server    │  ← Runs on cloud VM                         │
│  │             │  ← Operator can inspect logs                │
│  └─────────────┘                                             │
│                                                               │
│  Trust assumptions:                                           │
│  - Cloud provider (Fly.io, AWS, etc.) is trusted             │
│  - Zipsa operator is trusted with user data                  │
│  - TLS protects data in transit                              │
│  - Logs may contain PII (stored in /app/logs)                │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**Important:** In this demo deployment, Zipsa processes PII in the clear on cloud infrastructure. Users should be aware that:

- The demo operator can see all requests
- Cloud provider has theoretical access to VM memory
- Logs may be retained containing sensitive data

### Planned (v2): AWS Nitro Enclave

```
┌──────────────────────────────────────────────────────────────┐
│                 HARDWARE TRUST BOUNDARY                       │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐     │
│  │              AWS Nitro Enclave                       │     │
│  │                                                      │     │
│  │  ┌─────────────┐                                    │     │
│  │  │   Zipsa     │  ← Encrypted memory               │     │
│  │  │   Server    │  ← No operator access             │     │
│  │  │             │  ← Attestation-verified           │     │
│  │  └─────────────┘                                    │     │
│  │                                                      │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                               │
│  Trust assumptions:                                           │
│  - Only AWS silicon is trusted                               │
│  - Operator CANNOT access memory or logs                     │
│  - Cryptographic attestation proves code integrity           │
│  - Even cloud provider cannot inspect enclave                │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## Environment Variables

| Variable | Component | Description |
|----------|-----------|-------------|
| `ANTHROPIC_API_KEY` | Zipsa | Claude API authentication |
| `LOCAL_HOST` | Zipsa | Ollama Cloud endpoint (optional) |
| `LOCAL_API_KEY` | Zipsa | Ollama Cloud authentication |
| `LOCAL_MODEL` | Zipsa | Model name for local queries |
| `ADMIN_TOKEN` | Nginx | Bearer token for /monitor access |
| `DEMO_MODE` | Zipsa | Enable demo-specific restrictions |

## Volumes

| Mount | Purpose |
|-------|---------|
| `./logs:/app/logs` | Request logs, routing decisions |
| `./data:/app/data` | Persistent data, caches |
| `./nginx/ssl:/etc/nginx/ssl` | TLS certificates |

## Ports

| Port | Service | Access |
|------|---------|--------|
| 80 | Nginx HTTP | Public |
| 443 | Nginx HTTPS | Public |
| 8000 | Zipsa API | Internal (via Nginx) |
| 7861 | Zipsa Monitor | Internal (via Nginx + auth) |

## Security Considerations

1. **API Key Protection:** Store in `.env`, never commit to git
2. **Admin Access:** Protected by bearer token, consider IP allowlisting
3. **Rate Limiting:** Prevents abuse, configured in Nginx
4. **TLS:** Required for production, use Let's Encrypt
5. **Log Retention:** Consider automatic rotation/deletion of PII-containing logs
6. **Network Isolation:** Zipsa container not directly exposed

## Scaling

For higher traffic:

1. **Horizontal:** Run multiple Zipsa containers behind Nginx
2. **Caching:** Add Redis for response caching (privacy-aware)
3. **CDN:** CloudFlare or similar for static assets
4. **Region:** Deploy in multiple regions for latency
