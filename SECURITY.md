# Security Policy

## Supported Versions

We actively support and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

The Purl team takes security seriously. If you discover a security vulnerability, please follow these steps:

### 1. Do NOT Create a Public Issue

Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.

### 2. Report Privately

Send a detailed report to **andrew@ecosyste.ms** with:

- **Subject**: `[SECURITY] Purl Ruby - [Brief Description]`
- **Description** of the vulnerability
- **Steps to reproduce** the issue
- **Potential impact** assessment
- **Suggested fix** (if you have one)
- **Your contact information** for follow-up

### 3. What to Include

Please provide as much information as possible:

```
- Affected versions
- Attack vectors
- Proof of concept (if safe to share)
- Environmental details (Ruby version, OS, etc.)
- Any relevant configuration details
```

## Response Process

### Initial Response

- **24-48 hours**: We will acknowledge receipt of your report
- **Initial assessment**: Within 1 week of acknowledgment
- **Status updates**: Weekly until resolution

### Investigation

We will:
1. **Confirm** the vulnerability exists
2. **Assess** the severity and impact
3. **Develop** a fix and mitigation strategy
4. **Test** the fix thoroughly
5. **Coordinate** disclosure timeline

### Resolution

- **High/Critical**: Immediate fix and release
- **Medium**: Fix within 30 days
- **Low**: Fix in next regular release cycle

## Security Considerations

### Input Validation

The Purl library processes Package URL strings and performs:

- **Scheme validation**: Ensures proper `pkg:` prefix
- **Component parsing**: Validates type, namespace, name, version
- **URI encoding**: Handles percent-encoded characters
- **Qualifier parsing**: Processes key-value parameters

### Potential Risk Areas

Areas that warrant security attention:

1. **URL Parsing**: Malformed URLs could cause parsing errors
2. **Regular Expressions**: Complex patterns may be vulnerable to ReDoS
3. **JSON Processing**: Configuration files require safe parsing
4. **Network Requests**: Registry URL generation involves external URLs

### Safe Usage Practices

When using Purl in applications:

- **Validate input**: Don't trust user-provided PURL strings
- **Handle errors**: Properly catch and handle parsing exceptions
- **Sanitize output**: Be careful when displaying parsed components
- **Rate limiting**: If parsing many PURLs, implement appropriate limits

## Disclosure Policy

### Coordinated Disclosure

We follow coordinated disclosure principles:

1. **Private reporting** allows us to fix issues before public disclosure
2. **Reasonable timeline** for fixes (typically 90 days maximum)
3. **Credit and recognition** for responsible reporters
4. **Public disclosure** after fixes are available

### Public Disclosure

After a fix is released:

1. **Security advisory** published on GitHub
2. **CVE requested** if applicable
3. **Release notes** include security information
4. **Community notification** through appropriate channels

## Security Updates

### Notification Channels

Security updates are announced through:

- **GitHub Security Advisories**
- **RubyGems security alerts**
- **Release notes and CHANGELOG**
- **Project README updates**

### Update Recommendations

To stay secure:

- **Monitor** our security advisories
- **Update regularly** to the latest version
- **Review** release notes for security fixes
- **Subscribe** to GitHub notifications for this repository

## Bug Bounty

Currently, we do not offer a formal bug bounty program. However, we deeply appreciate security researchers who help improve the project's security posture.

### Recognition

Contributors who responsibly disclose security issues will be:

- **Credited** in security advisories (with permission)
- **Mentioned** in release notes
- **Recognized** in project documentation
- **Thanked** publicly (unless anonymity is requested)

## Contact Information

**Security Contact**: andrew@ecosyste.ms

**PGP Key**: Available upon request for encrypted communications

**Response Time**: We aim to acknowledge security reports within 24-48 hours

## Additional Resources

- [PURL Specification Security Considerations](https://github.com/package-url/purl-spec)
- [Ruby Security Best Practices](https://guides.rubyonrails.org/security.html)
- [OWASP Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)

---

Thank you for helping keep Purl and its users safe!