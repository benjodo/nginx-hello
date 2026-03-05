# Nginx Hello World: Best Practices Deployment Guide

A comprehensive reference implementation demonstrating how to build, scan, and deploy a production-ready Docker container to Aptible, following security and DevOps best practices.

## What This Repository Demonstrates

This repository shows you how to:

- **Build hardened Docker images** with pinned base images, non-root users, and health checks
- **Implement security headers** and nginx best practices
- **Scan for vulnerabilities** using Trivy before deployment
- **Automate CI/CD** with GitHub Actions for linting, scanning, and publishing
- **Deploy to Aptible** using pre-scanned images from GitHub Container Registry
- **Follow the principle of immutability** by deploying exact, tested image artifacts

While this example serves a simple static HTML page, the patterns demonstrated here scale to real-world applications with databases, migrations, and complex build processes.

## Repository Structure

```
.
├── Dockerfile                              # Hardened multi-layer image with non-root user
├── nginx.conf                              # Custom nginx config with security headers
├── index.html                              # Sample static HTML page
├── .aptible.yml                            # Aptible deployment hooks configuration
├── .dockerignore                           # Excludes CI/CD files from image
├── .github/workflows/
│   ├── build-scan-publish.yml             # CI: Lint, build, scan, publish to GHCR
│   └── deploy-to-aptible.yml              # CD: Deploy from GHCR to Aptible
└── README.md                               # This comprehensive guide
```

## Prerequisites

Before you begin, ensure you have:

- **Docker** installed locally ([Get Docker](https://docs.docker.com/get-docker/))
- **Git** for version control
- **GitHub account** with Actions enabled
- **Aptible account** ([Sign up](https://www.aptible.com/))
- **Aptible CLI** installed ([Installation guide](https://deploy-docs.aptible.com/docs/cli))

## Docker Best Practices Explained

### Pinned Base Image

```dockerfile
FROM nginx:1.27.3-alpine
```

**Why?** Using `:alpine` or `:latest` tags can introduce breaking changes or vulnerabilities when the upstream image updates. Pinning to a specific version ensures:
- **Reproducible builds** - same Dockerfile produces same image every time
- **Predictable updates** - you control when to upgrade
- **Security** - you can track which CVEs affect your specific version

**When to update?** When Trivy scans detect vulnerabilities in your base image, update the tag and test thoroughly before deploying.

### Non-Root User

```dockerfile
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser
USER appuser
```

**Why?** Running containers as root is a security risk. If an attacker exploits your application, they gain root privileges inside the container. A non-root user limits the blast radius of any security breach.

**Trade-off:** Non-root users cannot bind to privileged ports (< 1024), so we use port 8080 instead of 80.

### Unprivileged Port

```dockerfile
EXPOSE 8080
```

**Why?** Ports below 1024 require root privileges on Linux. By using port 8080, we can run nginx as a non-root user. Aptible's load balancer handles the mapping from public port 80/443 to your container's port 8080.

### Health Check

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/healthz || exit 1
```

**Why?** Docker and orchestrators like Kubernetes use health checks to:
- Detect when containers are stuck or unresponsive
- Avoid routing traffic to unhealthy containers
- Automatically restart failed containers

We created a lightweight `/healthz` endpoint in nginx.conf that returns a simple 200 OK response.

### Minimal Dependencies

```dockerfile
RUN apk add --no-cache wget=1.24.5-r0
```

**Why?** Alpine Linux keeps images small (< 50MB vs 100MB+ for Debian). We only install `wget` for health checks. Fewer packages = smaller attack surface and faster pulls.

**Version pinning:** We pin the wget version to ensure reproducible builds and avoid unexpected updates that could introduce vulnerabilities or breaking changes.

## Security Hardening

### Security Headers (nginx.conf)

Our nginx configuration adds critical security headers to every response:

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Content-Security-Policy "default-src 'self' https://fonts.googleapis.com https://fonts.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com;" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

**What each header does:**

- **X-Frame-Options:** Prevents clickjacking attacks by controlling iframe embedding
- **X-Content-Type-Options:** Prevents MIME-type sniffing attacks
- **X-XSS-Protection:** Enables browser XSS filters (legacy browsers)
- **Content-Security-Policy:** Restricts resource loading to trusted sources
- **Referrer-Policy:** Limits referer information leakage

### Version Hiding

```nginx
server_tokens off;
```

**Why?** Hiding the nginx version makes it harder for attackers to find version-specific exploits.

### Read-Only Filesystem Compatibility

All nginx temporary directories are configured to use `/tmp`:

```nginx
client_body_temp_path /tmp/client_temp;
proxy_temp_path /tmp/proxy_temp_path;
# ... etc
```

**Why?** This allows the container to run with a read-only root filesystem (advanced hardening), since `/tmp` can be mounted as writable while everything else is read-only.

## Local Development

### Build the Image

```bash
docker build -t nginx-hello .
```

### Run the Container

```bash
docker run -d -p 8080:8080 --name nginx-hello-test nginx-hello
```

Visit [http://localhost:8080](http://localhost:8080) to see the page.

### Verify Health Check

```bash
# Check health check endpoint
curl http://localhost:8080/healthz

# Inspect container health status
docker inspect --format='{{.State.Health.Status}}' nginx-hello-test
```

### Verify Security Headers

```bash
curl -I http://localhost:8080
```

You should see all security headers in the response.

### Test with Read-Only Filesystem (Advanced)

```bash
docker run -d -p 8080:8080 --read-only --tmpfs /tmp --tmpfs /var/cache/nginx --tmpfs /var/log/nginx nginx-hello
```

This proves the container works with maximum security hardening.

### Development with Live Reload

```bash
docker run -d -p 8080:8080 -v $(pwd)/index.html:/usr/share/nginx/html/index.html nginx-hello
```

Edit `index.html` and refresh your browser to see changes instantly.

### Stop the Container

```bash
docker stop nginx-hello-test
docker rm nginx-hello-test
```

## CI/CD Pipeline

### Build, Scan, and Publish Workflow

The `.github/workflows/build-scan-publish.yml` workflow runs on every push and pull request:

#### 1. Dockerfile Linting (Hadolint)

```yaml
- name: Run Hadolint
  uses: hadolint/hadolint-action@v3.1.0
  with:
    dockerfile: Dockerfile
    failure-threshold: warning
```

[Hadolint](https://github.com/hadolint/hadolint) catches common Dockerfile mistakes like:
- Missing version pins
- Using `sudo` in containers
- Installing unnecessary packages
- Inefficient layer caching

#### 2. Image Building

Uses Docker Buildx with layer caching for faster builds:

```yaml
- name: Build Docker image
  uses: docker/build-push-action@v5
  with:
    context: .
    push: false
    load: true
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

#### 3. Vulnerability Scanning (Trivy)

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@0.28.0
  with:
    image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
    severity: 'CRITICAL,HIGH'
    exit-code: '1'  # Fail the build if vulnerabilities found
```

**Trivy scans for:**
- OS package vulnerabilities (Alpine packages)
- Application dependencies vulnerabilities
- Misconfigurations
- Secrets accidentally included in image

**Results are uploaded to GitHub Security:**
- View vulnerabilities in the "Security" tab → "Code scanning alerts"
- Get automated Dependabot-style alerts for new CVEs

**Running Trivy locally (reproduces CI failure):**

```bash
# Install Trivy (macOS)
brew install trivy

# One command: build image and run same scan as CI
./scripts/trivy-scan.sh

# Or manually: build then scan with same settings as CI
docker build -t nginx-hello .
trivy image --severity CRITICAL,HIGH --exit-code 1 nginx-hello
```

#### 4. Publishing to GitHub Container Registry

If the scan passes and you're on the `main` branch or pushing a tag:

```yaml
- name: Push Docker image to GHCR
  if: github.event_name != 'pull_request'
  uses: docker/build-push-action@v5
  with:
    push: true
    tags: ${{ steps.meta.outputs.tags }}
```

**Image tagging strategy:**

- **Latest:** `ghcr.io/your-org/nginx-hello:latest` (main branch only)
- **Branch:** `ghcr.io/your-org/nginx-hello:main`
- **SHA:** `ghcr.io/your-org/nginx-hello:main-abc1234` (exact commit)
- **Semver tags:** `ghcr.io/your-org/nginx-hello:v1.0.0`, `v1.0`, `v1` (on version tags)

This allows you to:
- Deploy specific tested commits with SHA tags
- Use semantic versioning for releases
- Test from feature branches (PR builds don't push)

### Making Your GHCR Images Public

By default, images pushed to GitHub Container Registry are private. To make them public:

1. Navigate to your package at `https://github.com/users/YOUR_USERNAME/packages/container/nginx-hello`
2. Click "Package settings"
3. Scroll to "Danger Zone"
4. Click "Change visibility" → Select "Public"

Alternatively, keep images private and configure Aptible with GHCR credentials (see deployment section).

## Deploying to Aptible

### Initial Setup

#### 1. Create an Aptible App

```bash
# Login to Aptible
aptible login

# Create a new app
aptible apps:create nginx-hello --environment <your-environment>
```

#### 2. Configure Image Pull Credentials (for Private GHCR Images)

If your GHCR images are private, configure Aptible with GitHub credentials:

```bash
aptible config:set --app nginx-hello \
  DOCKER_REGISTRY_USERNAME=your-github-username \
  DOCKER_REGISTRY_PASSWORD=ghp_your_personal_access_token
```

**Creating a GitHub Personal Access Token:**
1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scope: `read:packages`
4. Copy the token and use it as `DOCKER_REGISTRY_PASSWORD`

For public images, you can skip this step.

### Automated Deployment via GitHub Actions

The `.github/workflows/deploy-to-aptible.yml` workflow can deploy your scanned image to Aptible automatically.

#### Required GitHub Secrets

Add these to your repository secrets (Settings → Secrets and variables → Actions):

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `APTIBLE_EMAIL` | Your Aptible account email | Your login email |
| `APTIBLE_PASSWORD` | Your Aptible account password | Your login password |

#### Required GitHub Variables

Add this to repository variables (Settings → Secrets and variables → Actions → Variables):

| Variable Name | Example Value | Description |
|---------------|---------------|-------------|
| `APTIBLE_APP` | `nginx-hello` | Your Aptible app name |

#### Deployment Triggers

**1. Manual Deployment (workflow_dispatch)**

Deploy any image tag on-demand:

```bash
# Via GitHub UI:
# Actions → Deploy to Aptible → Run workflow → Enter image tag (e.g., "v1.0.0" or "latest")

# Via GitHub CLI:
gh workflow run deploy-to-aptible.yml -f image_tag=v1.0.0
```

**2. Automatic on Release**

When you create a GitHub release:

```bash
# Create a release (pushes a tag and triggers deployment)
git tag v1.0.0
git push origin v1.0.0

# Or via GitHub UI: Releases → Create a new release
```

The workflow automatically deploys the image tagged with the release version.

### Manual Deployment via Aptible CLI

You can also deploy directly from the command line:

```bash
# Deploy the latest scanned image
aptible deploy \
  --app nginx-hello \
  --docker-image ghcr.io/your-org/nginx-hello:latest

# Deploy a specific version
aptible deploy \
  --app nginx-hello \
  --docker-image ghcr.io/your-org/nginx-hello:v1.0.0

# Deploy with private registry credentials (if image is private)
aptible deploy \
  --app nginx-hello \
  --docker-image ghcr.io/your-org/nginx-hello:latest \
  --private-registry-username your-github-username \
  --private-registry-password ghp_your_token
```

**Why deploy from GHCR?**

By deploying pre-built, scanned images from GHCR rather than building on Aptible:
- You deploy the **exact image** that passed security scans
- Deployments are faster (no build time)
- You maintain **immutability** - the artifact that was tested is what runs in production
- You can roll back to any previous image tag instantly

## Verifying Deployment

### Check App Status

```bash
# List all apps
aptible apps

# Get app details
aptible apps:info --app nginx-hello

# View recent logs
aptible logs --app nginx-hello
```

### Access Your App

```bash
# Get the app URL
aptible endpoints --app nginx-hello
```

Visit the endpoint URL in your browser. You should see the "Hello, World!" page.

### Monitor Health

Aptible uses your Dockerfile's `HEALTHCHECK` to monitor container health. If the health check fails, Aptible will restart the container.

```bash
# View app metrics
aptible metrics --app nginx-hello
```

## Troubleshooting

### Health Check Failing

**Symptom:** Container restarts repeatedly, logs show health check timeouts

**Cause:** Health check is trying the wrong port

**Solution:** Verify the Dockerfile `HEALTHCHECK` uses port 8080, matching the nginx.conf configuration:

```dockerfile
HEALTHCHECK CMD wget --no-verbose --tries=1 --spider http://localhost:8080/healthz || exit 1
```

### Permission Denied Errors

**Symptom:** nginx fails to start with "permission denied" errors

**Cause:** Non-root user lacks write permissions to required directories

**Solution:** Check that the Dockerfile sets proper ownership:

```bash
# Verify locally
docker run -it nginx-hello sh
$ id  # Should show uid=1000(appuser)
$ ls -la /var/cache/nginx  # Should be owned by appuser
```

### Image Pull Authentication Failed

**Symptom:** Aptible deployment fails with "unauthorized: authentication required"

**Cause:** Private GHCR image without credentials configured

**Solutions:**

1. **Make image public** (see "Making Your GHCR Images Public" above)
2. **Configure registry credentials:**
   ```bash
   aptible config:set --app nginx-hello \
     DOCKER_REGISTRY_USERNAME=your-github-username \
     DOCKER_REGISTRY_PASSWORD=ghp_your_token
   ```

### Trivy Scan Failures

**Symptom:** CI workflow fails at the "Run Trivy vulnerability scanner" step

**Cause:** CRITICAL or HIGH vulnerabilities detected in base image or dependencies

**Solutions:**

1. **Update base image:** Change `nginx:1.27.3-alpine` to a newer patched version
2. **Review findings:** Check the uploaded SARIF results in GitHub Security tab
3. **Suppress false positives:** Create a `.trivyignore` file:
   ```
   # Example: Suppress specific CVE if it's a false positive
   CVE-2024-12345
   ```
4. **Accept risk temporarily:** Change `exit-code: '1'` to `exit-code: '0'` in the workflow (not recommended for production)

### Build Failing on Hadolint

**Symptom:** Workflow fails at "Run Hadolint" step

**Cause:** Dockerfile doesn't follow best practices

**Common issues:**
- Missing version pins: `FROM nginx:alpine` should be `FROM nginx:1.27.3-alpine`
- Inefficient RUN commands (should combine with `&&`)
- Using `COPY` instead of `ADD` for URLs
- Missing `USER` instruction

**Solution:** Run Hadolint locally to see detailed warnings:

```bash
# Install Hadolint (macOS)
brew install hadolint

# Lint your Dockerfile
hadolint Dockerfile
```

## Adapting for Your Application

This static site is intentionally simple to clearly demonstrate the patterns. Here's how to adapt for real-world applications:

### Multi-Stage Builds

For compiled applications (Go, Rust, Java, Node.js with build steps):

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Runtime stage
FROM nginx:1.27.3-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
# ... rest of hardening steps
```

### Environment Variables

```dockerfile
# In Dockerfile
ENV NODE_ENV=production

# In .aptible.yml or via Aptible CLI
# aptible config:set --app myapp DATABASE_URL=... API_KEY=...
```

### Database Migrations

Update `.aptible.yml`:

```yaml
before_release:
  - bundle exec rake db:migrate  # Rails
  # - npx prisma migrate deploy  # Node.js + Prisma
  # - python manage.py migrate   # Django
```

### Custom Domains

```bash
# Add a custom domain to your app
aptible endpoints:https:create \
  --app nginx-hello \
  --default-domain \
  myapp.example.com

# Configure DNS CNAME record
# myapp.example.com → [endpoint hostname from Aptible]
```

### Scaling

```bash
# Scale container count
aptible scale --app nginx-hello web:2

# Scale container size
aptible scale --app nginx-hello --container-size 1024
```

## Next Steps

1. **Fork this repository** and customize it for your needs
2. **Enable GitHub Actions** and configure secrets for automated deployment
3. **Set up branch protection** to require passing scans before merging
4. **Add integration tests** to your CI pipeline
5. **Monitor your deployments** with Aptible metrics and logging
6. **Set up alerts** for security vulnerabilities in your dependencies

## Resources

- [Aptible Documentation](https://deploy-docs.aptible.com/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [nginx Security Best Practices](https://nginx.org/en/docs/http/ngx_http_core_module.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)

## License

This project is released into the public domain. Use it however you like!

---

**Questions or feedback?** Open an issue or submit a pull request. This guide is meant to help teams adopt security best practices – contributions welcome!
