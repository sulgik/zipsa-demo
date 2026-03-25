"""
Simple HTTP Basic Auth middleware for Zipsa Demo.
Injected at startup when DEMO_PASSWORD env var is set.

Usage:
    DEMO_PASSWORD=yourpassword  → enables basic auth (user: "demo")
    DEMO_PASSWORD not set       → no auth (open access)
"""
import os
import secrets
import base64
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

DEMO_USER = os.environ.get("DEMO_USER", "demo")
DEMO_PASSWORD = os.environ.get("DEMO_PASSWORD", "")


class BasicAuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Always allow health check (for Fly.io)
        if request.url.path == "/health":
            return await call_next(request)

        if not DEMO_PASSWORD:
            return await call_next(request)

        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Basic "):
            try:
                decoded = base64.b64decode(auth_header[6:]).decode("utf-8")
                user, password = decoded.split(":", 1)
                if secrets.compare_digest(user, DEMO_USER) and secrets.compare_digest(password, DEMO_PASSWORD):
                    return await call_next(request)
            except Exception:
                pass

        return Response(
            content="Unauthorized",
            status_code=401,
            headers={"WWW-Authenticate": 'Basic realm="Zipsa Demo"'},
        )
