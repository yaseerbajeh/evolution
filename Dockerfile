FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

LABEL version="2.3.1" description="Api to control whatsapp features through http requests." 
LABEL maintainer="Davidson Gomes" git="https://github.com/DavidsonGomes"
LABEL contact="contato@evolution-api.com"

WORKDIR /evolution

# Copy package files
COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

# Install dependencies
RUN npm ci --silent --no-audit --no-fund

# Copy source files
COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./
COPY ./Docker ./Docker

# Make scripts executable and convert line endings
RUN chmod +x ./Docker/scripts/* && \
    dos2unix ./Docker/scripts/* 2>/dev/null || true

# Generate Prisma client
RUN ./Docker/scripts/generate_database.sh

# Build the application
RUN npm run build

# Production stage
FROM node:24-alpine AS final

RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl && \
    rm -rf /var/cache/apk/*

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true
ENV NODE_ENV=production

WORKDIR /evolution

# Copy package files
COPY ./package*.json ./

# Install only production dependencies (ignore scripts to skip husky prepare)
RUN npm ci --silent --only=production --ignore-scripts --no-audit --no-fund && \
    npm cache clean --force

# Copy built application from builder
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8080', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod"]
