# Security Policy

## Reporting Security Issues

This is a reference implementation and demonstration repository. If you discover a security vulnerability, please:

1. **Do NOT** open a public issue
2. Email the repository maintainers privately
3. Include a description of the vulnerability and steps to reproduce

We'll respond as quickly as possible and credit you in the fix (if desired).

## Security Best Practices

This repository demonstrates security best practices for container deployments:

### Container Security
- ✅ Pinned base image versions (no `latest` tags)
- ✅ Non-root user execution
- ✅ Minimal attack surface (Alpine Linux)
- ✅ Read-only filesystem compatible

### nginx Security
- ✅ Security headers (CSP, X-Frame-Options, X-Content-Type-Options, etc.)
- ✅ Version hiding
- ✅ Hidden file access denied
- ✅ Unprivileged port (8080)

### CI/CD Security
- ✅ Automated vulnerability scanning with Trivy
- ✅ Dockerfile linting with Hadolint
- ✅ Scan results uploaded to GitHub Security
- ✅ Builds fail on CRITICAL/HIGH vulnerabilities
- ✅ Images only published after passing scans

## Known Limitations

### Supply Chain Security

The deployment workflow downloads the Aptible CLI from S3:
```yaml
wget -O aptible-package https://omnibus-aptible-toolbelt.s3.amazonaws.com/...
```

**Risk:** No cryptographic integrity verification of the downloaded package.

**Mitigations in place:**
- HTTPS transport (prevents MITM attacks)
- Official Aptible repository URL
- Runs in ephemeral GitHub Actions runner

**Further hardening options:**
1. Add SHA256 checksum verification if Aptible publishes checksums
2. Use a pre-verified Docker image with Aptible CLI pre-installed
3. Cache the CLI in a verified, version-controlled location

For production deployments, consider implementing one of these hardening options.

## Dependency Updates

### Base Image Updates

When Trivy reports vulnerabilities in the nginx base image:

1. Check for newer nginx Alpine versions: https://hub.docker.com/_/nginx/tags?name=alpine
2. Update the `FROM` line in `Dockerfile`
3. Test locally before deploying
4. Create a PR and verify CI passes

### GitHub Actions Updates

This repository uses GitHub Actions with version tags (e.g., `@v4`, `@v3`). For maximum security, consider pinning to commit SHAs:

```yaml
# Version tag (current - easier to maintain)
uses: actions/checkout@v4

# Commit SHA (more secure - prevents tag poisoning)
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
```

### npm/Application Dependencies

If adapting this for real applications with dependencies:
- Enable Dependabot for automated dependency updates
- Use `npm audit` or `yarn audit` in CI
- Review and update dependencies regularly

## Security Headers Reference

This repository implements the following security headers:

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Frame-Options` | `SAMEORIGIN` | Prevents clickjacking |
| `X-Content-Type-Options` | `nosniff` | Prevents MIME sniffing |
| `X-XSS-Protection` | `1; mode=block` | Enables XSS filtering (legacy) |
| `Content-Security-Policy` | Restrictive policy | Limits resource origins |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limits referer leakage |

For production applications, customize the CSP policy to match your specific needs.

## Audit History

- **2026-03-05**: Initial security review - No critical issues found
  - Verified no hardcoded secrets
  - Confirmed proper secrets management via GitHub Secrets
  - Validated Docker security hardening
  - Documented minor supply chain risk (Aptible CLI download)

## Contact

For security concerns, contact the repository maintainers.

For Aptible-specific security issues, contact Aptible support: https://www.aptible.com/support
