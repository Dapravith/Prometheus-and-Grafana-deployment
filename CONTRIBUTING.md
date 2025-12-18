# Contributing to Observability Stack

Thank you for your interest in contributing to this project! We welcome contributions from the community.

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check if the issue already exists in the GitHub issue tracker
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (K8s version, cloud provider, etc.)
   - Relevant logs or screenshots

### Submitting Changes

1. **Fork the repository**
   ```bash
   git clone https://github.com/Dapravith/Prometheus-and-Grafana-deployment.git
   cd Prometheus-and-Grafana-deployment
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow existing code style and conventions
   - Add tests if applicable
   - Update documentation if needed

4. **Validate your changes**
   ```bash
   # Validate YAML syntax
   make validate
   
   # Test deployments (if possible)
   make deploy
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add: description of your changes"
   ```
   
   Use conventional commit messages:
   - `Add:` for new features
   - `Fix:` for bug fixes
   - `Update:` for updates to existing features
   - `Docs:` for documentation changes
   - `Refactor:` for code refactoring

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Go to the original repository on GitHub
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill in the PR template with:
     - Description of changes
     - Related issues
     - Testing performed
     - Screenshots (if applicable)

## Development Guidelines

### Code Style

- **YAML Files**: 2 spaces for indentation
- **Terraform**: Follow HashiCorp style guide
- **Ansible**: Follow Ansible best practices
- **Comments**: Add comments for complex logic

### Kubernetes Manifests

- Always include resource limits
- Use meaningful labels
- Add health checks (liveness/readiness probes)
- Follow the rolling update strategy for zero-downtime

### Security

- Never commit secrets or sensitive data
- Use Kubernetes secrets for sensitive configuration
- Follow least privilege principle
- Keep dependencies up to date

### Testing

Before submitting a PR:

1. **Validate YAML syntax**
   ```bash
   make validate
   ```

2. **Test locally** (if possible)
   ```bash
   # On minikube or kind
   make deploy
   make status
   ```

3. **Test rollback**
   ```bash
   make ansible-rollback
   ```

4. **Check logs**
   ```bash
   make logs-prometheus
   make logs-grafana
   # etc.
   ```

### Documentation

When adding new features:

- Update README.md with usage instructions
- Add examples if applicable
- Update ARCHITECTURE.md if changing architecture
- Update DEPLOYMENT.md for deployment changes

## Project Structure

```
.
├── terraform/          # Infrastructure as Code
├── kubernetes/         # K8s manifests
├── ansible/           # Automation playbooks
├── examples/          # Example applications
└── docs/             # Additional documentation
```

## Component Updates

When updating component versions:

1. Test the new version in a development environment
2. Update the image tag in deployment files
3. Update documentation with any breaking changes
4. Update the CHANGELOG.md

## Review Process

All contributions go through:

1. **Automated checks** (if CI/CD is set up)
2. **Code review** by maintainers
3. **Testing** in a staging environment (if available)
4. **Approval** by at least one maintainer

## Questions?

If you have questions:

- Open a GitHub Discussion
- Comment on a related issue
- Reach out to maintainers

## Code of Conduct

Please be respectful and professional in all interactions. We aim to create a welcoming environment for all contributors.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing! 🎉
