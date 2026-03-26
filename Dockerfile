FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install runtime dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY . .

# Expose service port for HTTP
ENV PORT=8080
EXPOSE 8080

# Run as a lightweight web service (used by Logic App to fetch JSON)
ENTRYPOINT ["gunicorn", "-b", "0.0.0.0:8080", "trending_service:app"]
