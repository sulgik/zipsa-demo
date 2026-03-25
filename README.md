# Zipsa Cloud Demo

Live demo deployment for [Zipsa](https://github.com/sulgik/zipsa) — the privacy-preserving AI relay.

> **Note on Architecture**
>
> Zipsa is designed to run with a **local LLM inside your trust zone** — an on-prem or self-hosted model that never touches external servers. The local LLM handles sensitive queries entirely within your private boundary.
>
> This demo is for **evaluation purposes only**. Instead of a trust-zone LLM, it connects to a small external model (via OpenRouter) to simulate local LLM behavior. This means all queries leave the server — the privacy guarantees of a real deployment do not apply here.
>
> **Production setup:** Run Zipsa with Ollama or any self-hosted LLM inside your own infrastructure.

## What This Is

A standalone deployment that:
- Runs Zipsa relay API publicly on port 8000
- Runs Gradio monitor dashboard on port 7861 (admin-only)
- Uses **OpenRouter** for both "local" (small model) and "external" (capable model) LLM routing
- Nginx reverse proxy with admin authentication

## Prerequisites

- Docker & Docker Compose
- OpenRouter API key (https://openrouter.ai)
- Domain pointed to your server (for HTTPS, optional)

## Quick Deploy

### 1. Clone and configure

```bash
git clone https://github.com/your-org/zipsa-demo.git
cd zipsa-demo
cp .env.example .env
# Edit .env with your API keys
```

### 2. Deploy

**Option A: Fly.io (recommended)**
```bash
./scripts/deploy.sh fly
```

**Option B: Any VPS with Docker**
```bash
./scripts/deploy.sh vps
```

### 3. Verify

```bash
./scripts/health-check.sh https://demo.zipsa.ai
```

## Admin Access

The monitor dashboard at `/monitor` requires authentication:

```bash
# Access with curl
curl -H "Authorization: Bearer YOUR_ADMIN_TOKEN" https://demo.zipsa.ai/monitor

# Or in browser, use a header injection extension
```

The `ADMIN_TOKEN` is set in your `.env` file.

## Architecture

```
[User] → [Nginx :80/443] → [Zipsa :8000] → [Ollama Cloud / Heuristic]
                                         → [Claude API]
[Admin] → [Nginx /monitor + auth] → [Zipsa :7861 Gradio]
```

See [docs/architecture.md](docs/architecture.md) for details.

## Cost Estimate

### Fly.io

| Tier | Cost | Notes |
|------|------|-------|
| Free | $0/mo | 3 shared-cpu VMs, 256MB RAM each |
| Hobby | ~$5/mo | 1 shared-cpu, 1GB RAM — recommended |
| Production | ~$15/mo | 2 shared-cpu, 2GB RAM, HA |

### API Costs

| Service | Pricing | Typical Demo Usage |
|---------|---------|-------------------|
| Claude API | $3/M input, $15/M output tokens | ~$10-50/mo depending on traffic |
| Ollama Cloud | Pay-per-token | ~$5-20/mo (optional) |

### Heuristic-Only Mode

Set `LOCAL_HOST=` (empty) to skip Ollama entirely. Zipsa will use heuristics for routing decisions, falling back to Claude for everything. This reduces costs but may be less accurate for local-capable queries.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_API_KEY` | Yes | Claude API key |
| `LOCAL_HOST` | No | Ollama Cloud endpoint |
| `LOCAL_API_KEY` | No | Ollama Cloud API key |
| `LOCAL_MODEL` | No | Model name (default: qwen3.5:9b) |
| `ADMIN_TOKEN` | Yes | Token for /monitor access |
| `DEMO_MODE` | No | Enable demo restrictions |
| `LOG_DIR` | No | Log directory (default: logs) |

## Development

To run locally for testing:

```bash
docker-compose up --build
```

Access:
- Relay API: http://localhost:8000
- Monitor: http://localhost:7861

## License

MIT — See the main [Zipsa repository](https://github.com/sulgik/zipsa) for details.
