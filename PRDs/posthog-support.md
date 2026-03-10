# 🎫 PRD: PostHog Support for GrowthCues Core (Unified Version)

## 📖 Background & Context

To support clients using PostHog, `growthcues-core` must ingest data exported via [PostHog Batch Exports](https://posthog.com/docs/cdp/batch-exports). Unlike the Segment spec which uses multiple tables, PostHog delivers a single "Events" model where all behavioral, page, and identity data lives in one table with a nested JSON `properties` blob.

## 🎯 Objective

Implement a provider-agnostic staging layer that maps the PostHog "Events" model into the standardized GrowthCues schema (`event_id`, `user_id`, `account_id`, `event_name`, `event_at`) for both **Snowflake** and **BigQuery**.

---

## 🏗 Architecture & Design: The "Staging Adapter"

### 1. The Router Pattern

Downstream marts (e.g., `fct_sessions`) will be refactored to reference a generic router model rather than provider-specific tables.

- **New Router:** `models/staging/stg_tracks.sql`
- **Logic:** Uses `var('tracking_provider')` to switch between Segment and PostHog staging.

### 2. Provider-Specific Logic (PostHog Events Model)

- **Single Stream:** Identify, Track, and Pageview logic is filtered from the one PostHog `events` table.
- **Identity Handling:** We will map the PostHog `person_id` (or `distinct_id`) directly to our `user_id`. Since PostHog resolves identities server-side, we will conditionally bypass the `stg_identity_resolution` logic to save compute.
- **JSON Extraction:** We will implement cross-warehouse macros to handle the different JSON syntaxes:
- **BigQuery:** `JSON_EXTRACT_SCALAR(properties, '$.prop_name')`
- **Snowflake:** `properties:prop_name::string`

---

## 📝 Implementation Tasks

### Phase 1: Configuration & Routing

- [ ] **dbt_project.yml Updates:** Add PostHog variables:

```yaml
vars:
  tracking_provider: "segment" # Options: 'segment', 'posthog'
  posthog_group_type: "company" # Which group type represents the B2B Account
  posthog_events_table: "events"
```

- [ ] **Router Refactor:** Create `stg_tracks.sql` and `stg_pages.sql` as the primary refs for all marts.

### Phase 2: PostHog Staging Layer (Batch Export Spec)

- [ ] **JSON Macro:** Create `macros/get_json_property.sql` to abstract BigQuery and Snowflake JSON parsing.
- [ ] **stg_posthog_tracks.sql:** \* Filter: `event NOT IN ('$pageview', '$identify')`.
- Map `uuid` → `event_id`.
- Map `timestamp` → `event_at`.
- Extract `properties.$groups.<posthog_group_type>` → `account_id`.

- [ ] **stg_posthog_pages.sql:**
- Filter: `event = '$pageview'`.
- Extract `$current_url`, `$pathname`, and `$referrer` from `properties`.

### Phase 3: Integration Testing (Warehouse Specific)

- [ ] **PostHog Seed:** Create `integration_tests/seeds/posthog_events.csv` following the PostHog Batch Export schema (columns: `uuid`, `event`, `properties`, `distinct_id`, `timestamp`).
- [ ] **CI Matrix:** Update `.github/workflows/integration_tests.yml` to test the PostHog provider across Snowflake and BigQuery targets.

---

## 📋 Definition of Done

1. **Core Marts Unchanged:** `fct_account_metrics_daily` and `fct_product_metrics_daily` produce identical results regardless of whether the source is Segment or PostHog.
2. **Cross-Warehouse Support:** SQL successfully compiles and runs for both `JSON_EXTRACT_SCALAR` (BQ) and colon-notation (Snowflake).
3. **Account Attribution:** PostHog Group IDs are correctly mapped to `account_id` in the staging layer.

## 🚫 Out of Scope

- Support for PostHog tables other than the "Events" model (e.g., excluding Persons or Actions tables).
- Supporting database adapters other than Snowflake and BigQuery.
