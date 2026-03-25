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

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
