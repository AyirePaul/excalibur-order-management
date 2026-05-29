# syntax=docker/dockerfile:1.7

FROM node:20-alpine AS base
WORKDIR /app
COPY package.json ./

# --- dev stage: Vite dev server ---
FROM base AS dev
RUN npm install
COPY . .
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

# --- builder: compile static bundle ---
FROM base AS builder
# VITE_API_BASE_URL defaults to "" so the production bundle uses relative URLs.
# The ALB routes /orders* and /api/* to the backend on the same domain, so no
# absolute URL needs to be baked in. Override via --build-arg if deploying the
# frontend on a separate domain.
ARG VITE_API_BASE_URL=""
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm install
COPY . .
RUN npm run build

# --- runtime: nginx serves static files ---
FROM nginx:1.27-alpine AS runtime
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1
CMD ["nginx", "-g", "daemon off;"]
