# Unit Tests for GrowthCues Core

This directory contains unit tests for the GrowthCues Core dbt package. Unit tests are defined using dbt's native unit testing feature (available from dbt v1.8+) and are specified in the `schema.yml` files alongside model definitions.

## Overview

Unit tests validate transformation logic in isolation by providing mock input data and expected output. They run much faster than integration tests since they don't require full seed data.

### Test Coverage

**⚠️ Important Notes:**

- `stg_segment_tracks` is NOT covered by unit tests because it uses `adapter.get_columns_in_relation()` which is incompatible with the unit test framework. Use integration tests with seeds instead.
- `stg_segment_pages` is NOT covered by unit tests for the same reason as stg_segment_tracks. Use integration tests with seeds instead.
- `stg_identity_resolution` is NOT covered by unit tests because it uses `dbt.dateadd()` and `dbt.current_timestamp()` in WHERE clauses which aren't properly handled in unit test compilation. Use integration tests with seeds instead.

**Core Models** (`models/marts/core/schema.yml`):

- **Sessionization** (`fct_sessions`):
  - `test_sessions_basic_grouping` - Tests session timeout window logic (events within 30 min = same session, beyond = new session)
  - `test_sessions_exact_timeout_boundary` - Edge case: events exactly 30 minutes apart remain in the SAME session (logic is `> 30` not `>= 30`)
  - `test_sessions_multiple_users_isolated` - Ensures sessions are isolated by user_id
  - `test_sessions_with_pages_combined` - Tests that track events and page views are combined into sessions when `include_pages_in_sessions: true`
  - `test_sessions_pages_only` - Tests sessions created from page views alone (no track events)
  - `test_sessions_interleaved_events` - Tests proper ordering and session grouping when tracks and pages are interleaved

- **Dimension Tables**:
  - `test_dim_accounts_basic_aggregation` - Account-level metrics aggregation (excludes `current_active_seats` which depends on `current_timestamp()`)
  - `test_dim_users_basic_aggregation` - User-level metrics and account associations

## Running Unit Tests

### Run all unit tests

```bash
dbt test --select test_type:unit
```

### Run unit tests for a specific model

```bash
# Test sessionization
dbt test --select fct_sessions,test_type:unit

# Test dimension tables
dbt test --select dim_accounts,test_type:unit
dbt test --select dim_users,test_type:unit
```

### Run unit tests for marts layer

```bash
# All unit tests are currently in the marts layer
dbt test --select marts,test_type:unit
```

### Run a specific unit test by name

```bash
dbt test --select test_name:test_sessions_basic_grouping
```

## Test Structure

Unit tests are defined in `schema.yml` files using this structure:

```yaml
unit_tests:
  - name: test_name
    description: What this test validates
    model: model_name # The model being tested
    overrides: # Optional: override vars for this test
      vars:
        var_name: value
    given: # Mock input data
      - input: ref('upstream_model') or source('schema', 'table')
        rows:
          - { col1: val1, col2: val2 }
          - { col1: val3, col2: val4 }
    expect: # Expected output
      rows:
        - { output_col1: val1, output_col2: val2 }
```

## Writing New Unit Tests

### Best Practices

1. **Keep tests simple** - Focus on one concept per test
2. **Use minimal data** - Only include rows necessary to test the logic
3. **Test edge cases** - Boundary conditions, nulls, empty sets
4. **Name descriptively** - Test names should clearly indicate what's being tested
5. **Document intent** - Use descriptions to explain the test scenario

### Example: Testing a New Transformation

```yaml
unit_tests:
  - name: test_my_new_feature
    description: Tests that my feature correctly handles XYZ scenario
    model: my_model
    given:
      - input: ref('upstream_model')
        rows:
          # Describe the test scenario in comments
          - { user_id: "user_A", value: 100 }
          - { user_id: "user_B", value: 200 }
    expect:
      rows:
        - { user_id: "user_A", calculated_value: 150 }
        - { user_id: "user_B", calculated_value: 250 }
```

## What to Test

### Identity Stitching

- Last-touch attribution (most recent user_id wins)
- Handling of null values
- Multiple identities for same anonymous_id
- Edge cases: same timestamps, out-of-order data

### Sessionization

- Session timeout logic (events within timeout = same session)
- Session boundary detection (events beyond timeout = new session)
- User isolation (different users don't interfere)
- Single-event sessions (duration = 0)
- Account_id inheritance (from first event in session)

### Metrics Calculation

- DAU/WAU/MAU counting logic
- Stickiness ratios (DAU/MAU)
- Trend calculations (7d, 14d, 30d velocity)
- Account/user aggregations
- Edge cases: zero values, division by zero

### Dimension Tables

- First/last seen timestamps
- Lifetime vs current metrics (e.g., lifetime_unique_users vs current_active_seats)
- Account/user associations
- Counting distinct values correctly

## Continuous Integration

Unit tests should run in CI/CD pipelines before merging code:

```bash
# In your CI pipeline
dbt test --select test_type:unit --target ci
```

Unit tests are fast (< 1 second each) and don't require seed data, making them ideal for CI.

## Debugging Failed Tests

When a unit test fails:

1. **Review the test definition** - Check `given` and `expect` sections
2. **Run the test in isolation** - `dbt test --select test_name:test_name`
3. **Inspect compiled SQL** - Check `target/compiled/.../tests/` for the compiled test
4. **Check model logic** - Review the model SQL for the specific transformation being tested
5. **Add debug output** - Temporarily add `{{ log(var, info=True) }}` to model code

## Integration with Seed Tests

Unit tests complement but don't replace integration tests:

- **Unit tests** (these) - Fast, isolated, test specific logic
- **Seed tests** (`seeds/`) - Slower, end-to-end, test with realistic data
- **Data tests** (`schema.yml` tests) - Validate data quality constraints

All three types work together to ensure code quality.

## Resources

- [dbt Unit Testing Documentation](https://docs.getdbt.com/docs/build/unit-tests)
- [dbt Testing Best Practices](https://docs.getdbt.com/best-practices/how-we-test/testing-best-practices)
- [GrowthCues Core README](../README.md)
- [Seed Data Setup](../seeds/SEEDS_README.md)
