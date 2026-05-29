# syntax=docker/dockerfile:1.7
FROM eclipse-temurin:17-jre-alpine AS base
WORKDIR /app

RUN apk add --no-cache python3 py3-pip curl unzip && \
    pip3 install --no-cache-dir --break-system-packages psycopg[binary]

# Install jasperstarter
RUN curl -fsSL "https://sourceforge.net/projects/jasperstarter/files/JasperStarter-3.6/jasperstarter-3.6.2-bin.zip/download" \
        -o /tmp/jasperstarter.zip && \
    unzip /tmp/jasperstarter.zip -d /opt/jasperstarter && \
    rm /tmp/jasperstarter.zip && \
    chmod +x "$(find /opt/jasperstarter -name jasperstarter -type f)" && \
    ln -s "$(find /opt/jasperstarter -name jasperstarter -type f)" /usr/local/bin/jasperstarter

# Add PostgreSQL JDBC driver — jasperstarter does not bundle it
RUN JDBC_DIR="$(find /opt/jasperstarter -type d -name jdbc 2>/dev/null || echo /opt/jasperstarter/jdbc)" && \
    mkdir -p "$JDBC_DIR" && \
    curl -fsSL "https://jdbc.postgresql.org/download/postgresql-42.7.4.jar" \
        -o "$JDBC_DIR/postgresql.jar"

COPY reports/ ./reports/
COPY runner.py ./

ENTRYPOINT ["python3", "runner.py"]
