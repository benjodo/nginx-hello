# Pin base image to specific version for reproducibility and security
FROM nginx:1.27.3-alpine

# Install wget for health checks (minimal Alpine doesn't include it)
RUN apk add --no-cache wget

# Remove default nginx configuration and static assets
RUN rm -rf /usr/share/nginx/html/* /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration that runs on port 8080 with security headers
COPY nginx.conf /etc/nginx/nginx.conf

# Copy our custom HTML file
COPY index.html /usr/share/nginx/html/

# Create non-root user and group
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Create necessary directories and set permissions for non-root user
# nginx needs write access to these directories for operation
RUN mkdir -p /var/cache/nginx /var/log/nginx /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    chown -R appuser:appuser /var/cache/nginx /var/log/nginx /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp /usr/share/nginx/html && \
    chmod -R 755 /var/cache/nginx /var/log/nginx /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

# Switch to non-root user
USER appuser

# Expose unprivileged port (non-root users cannot bind to ports < 1024)
EXPOSE 8080

# Health check using wget to verify nginx is responding
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/healthz || exit 1

# Start nginx in foreground mode
CMD ["nginx", "-g", "daemon off;"]
