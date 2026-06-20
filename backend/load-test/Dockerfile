FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy load test scripts
COPY . .

# Expose Locust web UI port
EXPOSE 8089

# Default command to run Locust
CMD ["locust", "--host=https://us-central1-liive-ride-sharing.cloudfunctions.net"] 