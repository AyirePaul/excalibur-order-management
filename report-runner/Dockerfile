# syntax=docker/dockerfile:1.7
FROM eclipse-temurin:17-jre-alpine AS base
WORKDIR /app

# Install jasperstarter + Python for the runner script
RUN apk add --no-cache python3 py3-pip curl && \
    pip3 install --no-cache-dir --break-system-packages boto3 psycopg[binary] && \
    curl -fsSL https://github.com/cenote/jasperstarter/releases/download/v3.6.1/jasperstarter-3.6.1-dist.zip \
        -o /tmp/jasperstarter.zip && \
    unzip /tmp/jasperstarter.zip -d /opt && \
    rm /tmp/jasperstarter.zip && \
    ln -s /opt/jasperstarter-3.6.1/bin/jasperstarter /usr/local/bin/jasperstarter

COPY reports/ ./reports/
COPY runner.py ./

ENTRYPOINT ["python3", "runner.py"]
