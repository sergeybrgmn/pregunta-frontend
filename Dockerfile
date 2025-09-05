# -------------------------
# Build stage
# -------------------------
FROM node:22-alpine AS build

WORKDIR /app

# Install deps
COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .

# Build static assets (will use env vars like VITE_CLERK_PUBLISHABLE_KEY)
RUN npm run build

# -------------------------
# Serve stage
# -------------------------
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy built assets from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Copy default nginx config (optional but good for SPA)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
