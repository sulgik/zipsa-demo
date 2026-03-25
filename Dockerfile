FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git \
    && rm -rf /var/lib/apt/lists/*

# Pull latest Zipsa from GitHub
RUN git clone --depth 1 https://github.com/sulgik/zipsa.git /app

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir gradio>=4.0.0

# Create directories
RUN mkdir -p logs data

# Inject Basic Auth middleware for demo protection
COPY auth_middleware.py /app/auth_middleware.py
COPY inject_auth.py /app/inject_auth.py
RUN python3 /app/inject_auth.py

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
