# Pin base image to specific version for reproducibility and security
FROM nginx:1.27.3-alpine

# Install wget for health checks and remove default nginx configuration
# Pin wget version for reproducibility
RUN apk add --no-cache wget=1.24.5-r0 && \
    rm -rf /usr/share/nginx/html/* /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration that runs on port 8080 with security headers
COPY nginx.conf /etc/nginx/nginx.conf

# Copy our custom HTML file
COPY index.html /usr/share/nginx/html/

# Create non-root user and setup permissions
# nginx needs write access to cache/log directories for operation
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    mkdir -p /var/cache/nginx /var/log/nginx /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
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
