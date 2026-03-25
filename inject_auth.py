"""Inject BasicAuth middleware into main.py at build time."""
import re

with open("/app/main.py") as f:
    content = f.read()

inject = """
# --- Demo Basic Auth (injected by zipsa-demo) ---
import os as _demo_os
if _demo_os.environ.get("DEMO_PASSWORD"):
    from auth_middleware import BasicAuthMiddleware
    app.add_middleware(BasicAuthMiddleware)
"""

# Insert right after the app = FastAPI(...) definition
content = re.sub(
    r"(app\s*=\s*FastAPI\([^)]*\))",
    r"\1" + inject,
    content,
    count=1,
)

with open("/app/main.py", "w") as f:
    f.write(content)

print("Auth middleware injected successfully.")
