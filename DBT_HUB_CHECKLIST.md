# dbt Hub Submission Checklist

This document tracks the steps needed to submit GrowthCues Core to dbt Hub.

## ✅ Completed

- [x] **Source Abstraction**: `sources.yml` now uses variables instead of hardcoded values
- [x] **Variable Configuration**: All source references configurable via `dbt_project.yml`
- [x] **Integration Tests**: Complete test suite with seed data
- [x] **CI/CD Pipeline**: GitHub Actions workflow for automated testing
- [x] **Package Metadata**: `hub.yml` created with all required fields
- [x] **Documentation**: README updated with package installation instructions
- [x] **FAQ Section**: Added dbt Hub status and installation method guidance

## 🔄 In Progress

- [ ] **CI/CD Setup**: Configure GitHub Secrets for Snowflake/BigQuery testing
  - Required secrets:
    - `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`, `SNOWFLAKE_ROLE`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_WAREHOUSE`
    - `GCP_PROJECT_ID`, `GCP_SA_KEY`
  - Required variables:
    - `SNOWFLAKE_ACCOUNT` (set to enable Snowflake tests)
    - `GCP_PROJECT_ID` (set to enable BigQuery tests)

- [ ] **Test Execution**: Run integration tests locally to validate

  ```bash
  cd integration_tests
  dbt deps
  dbt seed
  dbt run
  dbt test
  ```

- [ ] **Version Tagging**: Create git tags for releases
  ```bash
  git tag -a v1.0.0 -m "Initial dbt Hub release"
  git push origin v1.0.0
  ```

## 📋 Next Steps

### 1. Set Up CI/CD Credentials

**For Snowflake Testing:**

1. Go to GitHub repository → Settings → Secrets and variables → Actions
2. Add repository secrets:
   - `SNOWFLAKE_ACCOUNT`: Your Snowflake account identifier
   - `SNOWFLAKE_USER`: Service account username
   - `SNOWFLAKE_PASSWORD`: Service account password
   - `SNOWFLAKE_ROLE`: Role with CREATE TABLE permissions
   - `SNOWFLAKE_DATABASE`: Database for testing
   - `SNOWFLAKE_WAREHOUSE`: Warehouse for compute
3. Add repository variable:
   - `SNOWFLAKE_ACCOUNT`: Same as secret (enables workflow)

**For BigQuery Testing:**

1. Create a Google Cloud service account with BigQuery permissions
2. Download the JSON keyfile
3. Add repository secrets:
   - `GCP_PROJECT_ID`: Your GCP project ID
   - `GCP_SA_KEY`: Full JSON keyfile contents
4. Add repository variable:
   - `GCP_PROJECT_ID`: Same as secret (enables workflow)

### 2. Test Locally

Before pushing, validate the integration tests work:

```bash
cd integration_tests
dbt deps
dbt seed --target snowflake  # or bigquery
dbt run --target snowflake
dbt test --target snowflake
```

### 3. Submit to dbt Hub

Once CI/CD is passing:

1. Go to https://hub.getdbt.com/
2. Click "Submit a Package"
3. Provide GitHub repository URL: `https://github.com/growthcues/growthcues-core`
4. dbt Hub will automatically detect `hub.yml`
5. Complete the submission form

### 4. Post-Submission

After acceptance:

1. Update README.md to reference dbt Hub listing
2. Add dbt Hub badge to README:
   ```markdown
   ![dbt Hub](https://img.shields.io/badge/dbt%20Hub-growthcues__core-orange)
   ```
3. Announce on social media/blog

## 📚 Resources

- [dbt Hub Submission Guide](https://docs.getdbt.com/docs/contribute-to-hub)
- [Package Development Best Practices](https://docs.getdbt.com/best-practices/how-we-structure/5-the-rest-of-the-project)
- [dbt-labs/dbt-utils](https://github.com/dbt-labs/dbt-utils) - Example package structure

## 🐛 Known Issues

None currently.

## 📝 Notes

- The package now works in both "package mode" (via `packages.yml`) and "template mode" (via git clone)
- All hardcoded values have been abstracted to variables
- Integration tests validate both Snowflake and BigQuery compatibility
- CI/CD will run automatically on all PRs and pushes to main
