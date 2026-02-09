# Contributing to GrowthCues Core

Thank you for your interest in contributing to GrowthCues Core! This guide will help you get started.

## Development Setup

### Prerequisites

- Python 3.10+
- dbt-snowflake or dbt-bigquery
- Access to Snowflake or BigQuery for testing

### Local Development

1. **Clone the repository**:

   ```bash
   git clone https://github.com/growthcues/growthcues-core.git
   cd growthcues-core
   ```

2. **Install dependencies**:

   ```bash
   # For Snowflake
   pip install dbt-snowflake

   # For BigQuery
   pip install dbt-bigquery
   ```

3. **Configure your profile**:
   Create `~/.dbt/profiles.yml` (see README for examples)

4. **Install package dependencies**:
   ```bash
   dbt deps
   ```

## Testing Your Changes

### Run Integration Tests

Integration tests validate that the package works on both Snowflake and BigQuery:

```bash
cd integration_tests
dbt deps
dbt seed
dbt run
dbt test
```

### Test as a Package

To test the package installation flow:

1. Create a test dbt project in a separate directory
2. Add to `packages.yml`:
   ```yaml
   packages:
     - local: /path/to/growthcues-core
   ```
3. Run:
   ```bash
   dbt deps
   dbt run --models growthcues_core
   ```

## Making Changes

### Code Guidelines

- **Keep sources abstract**: Use variables, not hardcoded values
- **Document variables**: Add clear comments in `dbt_project.yml`
- **Follow dbt best practices**: See [dbt's style guide](https://docs.getdbt.com/best-practices/how-we-style/0-how-we-style-our-dbt-projects)
- **Add tests**: Update integration tests for new features

### Variable Configuration

All source references must use variables:

```yaml
# Good ✅
database: "{{ var('segment_database', target.database) }}"

# Bad ❌
database: "RAW_DATA"
```

### Commit Messages

Use clear, descriptive commit messages:

```
feat: Add new account health metric
fix: Correct session timeout calculation
docs: Update installation instructions
test: Add integration test for identity stitching
```

## Pull Request Process

1. **Create a feature branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** and test thoroughly

3. **Update documentation**:
   - Update README.md if user-facing changes
   - Update METRICS.md for new metrics
   - Update schema.yml for new models/columns

4. **Run integration tests**:

   ```bash
   cd integration_tests
   dbt test
   ```

5. **Commit and push**:

   ```bash
   git add .
   git commit -m "feat: Your descriptive message"
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request** on GitHub

## What Gets Tested

Our CI/CD pipeline automatically tests:

- ✅ All models compile without errors
- ✅ Integration tests pass on Snowflake
- ✅ Integration tests pass on BigQuery
- ✅ Schema tests validate data quality

## Project Structure

```
growthcues-core/
├── models/
│   ├── staging/          # Source data staging
│   │   ├── sources.yml   # Source definitions (use variables!)
│   │   └── stg_*.sql     # Staging models
│   └── marts/
│       ├── core/         # Core metrics models
│       │   ├── dim_*.sql # Dimension tables
│       │   ├── fct_*.sql # Fact tables
│       │   └── schema.yml # Model documentation
│       └── intermediate/ # Intermediate transformations
├── integration_tests/    # Package validation tests
│   ├── seeds/           # Test data
│   └── dbt_project.yml  # Test configuration
├── .github/
│   └── workflows/       # CI/CD pipelines
├── hub.yml              # dbt Hub metadata
└── README.md            # User documentation
```

## Common Issues

**"Source not found" errors**:

- Ensure you're using variables in `sources.yml`
- Check that variables have appropriate defaults

**Integration tests failing**:

- Verify seed data covers edge cases
- Check that models handle NULL values properly

**BigQuery-specific issues**:

- Use `target.type` conditionals for platform-specific SQL
- Test both Snowflake and BigQuery if making SQL changes

## Release Process

1. **Update version** in `hub.yml`
2. **Update CHANGELOG** (if exists) or create release notes
3. **Tag the release**:
   ```bash
   git tag -a v1.1.0 -m "Release v1.1.0: Description"
   git push origin v1.1.0
   ```
4. **Submit to dbt Hub** (maintainers only)

## Questions?

- Open an issue on GitHub
- Check existing issues for similar questions
- Review the README.md and documentation

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to GrowthCues Core! 🚀
