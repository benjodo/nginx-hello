# Pin to a newer slim Alpine image with patched OS packages.
FROM nginx:1.28.2-alpine3.23-slim

# Remove default nginx configuration and static assets.
RUN rm -rf /usr/share/nginx/html/* /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration that runs on port 8080 with security headers
COPY nginx.conf /etc/nginx/nginx.conf

# Copy our custom HTML file
COPY index.html /usr/share/nginx/html/

# Create non-root user and set up writable paths for nginx.
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    mkdir -p /var/cache/nginx /var/log/nginx /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    chown -R appuser:appuser /var/cache/nginx /var/log/nginx /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp /usr/share/nginx/html && \
    chmod -R 755 /var/cache/nginx /var/log/nginx /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

# Switch to non-root user
USER appuser

# Expose unprivileged port (non-root users cannot bind to ports < 1024)
EXPOSE 8080

# Start nginx in foreground mode
CMD ["nginx", "-g", "daemon off;"]
