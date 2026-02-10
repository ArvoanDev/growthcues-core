---
name: analyze-account-health
description: Summarizes B2B account health by analyzing usage patterns, engagement trends, risk signals, and expansion opportunities. Use for customer success reviews, renewal preparation, QBRs, or account prioritization.
---

# Analyze Account Health

Deep-dive into a B2B account's product usage to prepare for QBRs, assess renewal risk, identify expansion opportunities, or prioritize CS outreach.

## Instructions

### Step 0: Identify Account & Discover Schema

**Get the account identifier:**

- Company name, org ID, account ID, or account_id value
- Ask user if not provided

**Discover the data schema:**
Use `BigQuery:search_catalog` to find the GrowthCues Core tables (search for "account metrics" or "user metrics"). The main tables are:

- `fct_account_metrics_daily` - Account health scores and trends
- `fct_account_feature_usage_monthly` - Feature-level adoption
- `fct_user_metrics_daily` - User behavior and champions
- `dim_accounts` - Account master data

**Get table metadata:**
Use `BigQuery:get_table_info` on each table to read the column descriptions. The descriptions contain the semantic context (Definition, Context, Action tags) that explain what each metric means and how to interpret it.

---

### Step 1: Quick Health Triage

Query `fct_account_metrics_daily` for the account's recent metrics. Use the table metadata to identify:

- Pre-computed health signals (health_segment, health_score)
- Core engagement metrics (DAU, WAU, MAU, stickiness ratios)
- Trend indicators (volume changes, user momentum)
- Risk flags (dormant signals, usage drops)

Pull at least 30 days of data to show trends over time.

**Key signals to look for:**

- **health_segment** and **health_score** are pre-computed - use these as your primary classification
- Compare week-over-week trends in activity and volume metrics
- Flag accounts with usage contraction signals < 0.5 or stickiness < 0.20
- Note dormant risk flags

Use `BigQuery:ask_data_insights` or `BigQuery:execute_sql` depending on complexity.

---

### Step 2: User-Level Analysis

Query `fct_user_metrics_daily` to identify specific users within the account. The table metadata will guide you to:

- Champion identification metrics (usage ranks, activity levels)
- Admin/buyer signals (first user flags)
- Engagement depth indicators (feature sophistication, session patterns)
- Lifecycle status (active, dormant, churned, resurrected)

**User segments to identify:**

- **Champions**: Top-ranked users by usage volume, high activity frequency
- **Admins/Buyers**: First users in account (decision-makers for renewals)
- **Power Users**: High feature breadth, frequent daily usage
- **At-Risk**: Lifecycle status indicating dormancy, or active monthly but not weekly
- **Churned**: Users who have stopped using the product

Calculate license utilization: active monthly users vs total users in account.

Use `BigQuery:ask_data_insights` to get user segmentation or `BigQuery:execute_sql` for precise queries.

---

### Step 3: Feature Usage Analysis

Query `fct_account_feature_usage_monthly` to analyze feature-level adoption patterns. The table tracks:

- Which specific features (event_name) each account uses
- Volume and user counts per feature
- Feature penetration rates (% of account users using each feature)
- Month-over-month trends (pre-computed)
- First adoption dates

Pull at least 6 months of data to identify trends.

**Patterns to identify:**

- **Core Features**: High penetration rate (>50% of account users)
- **Expanding Features**: Positive month-over-month growth (>20%)
- **Declining Features**: Negative month-over-month change (<-20%)
- **Abandoned Features**: Previously used, now zero or very low volume
- **Low Penetration Opportunities**: <10% penetration on valuable features (training/upsell opportunity)
- **New Adoptions**: Recent first_used_month dates

**Analysis approach based on health:**

- **If At-Risk/Critical**: Focus on which core features are declining or abandoned
- **If Healthy**: Focus on advanced/premium features with low penetration (upsell signals)

Use `BigQuery:ask_data_insights` for pattern analysis or `BigQuery:execute_sql` for specific metrics.

---

### Step 4: Contextual Analysis (Optional)

**Note**: GrowthCues Core focuses on behavioral data. For a complete picture, supplement with:

- **CRM Data**: Contract value, renewal date, expansion history
- **Support Tickets**: Outstanding issues, CSAT scores
- **Qualitative Feedback**: NPS responses, customer interviews, survey data
- **Account Team Notes**: CSM observations, recent interactions

If you have access to these data sources in BigQuery or other systems, correlate them with the usage patterns:

- Do support tickets align with declining feature usage?
- Are expansion opportunities backed by positive sentiment?
- Do at-risk signals correlate with contract renewal timing?

Use `BigQuery:search_catalog` to discover if additional customer data tables exist in the warehouse.

---

### Step 5: Present Account Health Report

Structure output as follows:

# Account Health Report: [Account Name]

## Executive Summary

[2-3 sentences: Health score, key trend, primary recommendation]

## Health Score: [Health Segment from DB]

**Score**: [health_score]/100
**Classification**: [health_segment value]
[One sentence rationale with supporting metrics]

---

## Key Metrics

| Metric               | Current | Trend   | Status |
| -------------------- | ------- | ------- | ------ |
| MAU                  | X       | ↑↓→ Y%  | 🟢🟡🔴 |
| DAU/MAU (Stickiness) | X%      | ↑↓→ Ypp | 🟢🟡🔴 |
| Active Days (7d)     | X       | ↑↓→     | 🟢🟡🔴 |
| Features Adopted     | X       | ↑↓→ Y   | 🟢🟡🔴 |
| User Momentum (7d)   | +/- X   | ↑↓→     | 🟢🟡🔴 |

---

## 🚨 Risk Factors (if any)

1. **[Issue]** - [Impact]
   - Usage data: [specific metric/trend from queries]
   - Behavior pattern: [what the data shows]
   - _Action: [Specific recommendation]_

## ✅ Positive Signals

1. **[What's working]** - [Evidence from usage metrics]

---

## 👥 User Intelligence

### Champions (Leverage for advocacy)

- **[User ID]** (Rank #[X]): [Monthly events], [Active days], [Feature sophistication] - _Action: [e.g., Case study candidate, reference call]_

### Power Users

- **[User ID]**: [Activity summary] - _Action: [Enablement opportunity, beta tester]_

### At Risk (Engage)

- **[User ID]**: Last active [X days ago], lifecycle: [status] - _Action: [Re-engagement strategy]_

### Admin/Buyer

- **[User ID]** (is*admin_proxy): [Activity level] - \_Action: [Renewal discussion contact]*

### Inactive (>30 days)

- [Count] users ([X]% of total) - _Risk: Unused licenses, potential downsell_

---

## 📊 Feature Adoption Analysis

### High Adoption (Core Value)

| Feature      | Users | Penetration | Trend |
| ------------ | ----- | ----------- | ----- |
| [event_name] | X     | Y%          | ↑↓→   |

### Growing Features (Expansion Signal)

| Feature      | MoM Change | Current Users |
| ------------ | ---------- | ------------- |
| [event_name] | +X%        | Y users       |

### Declining Features (Risk Signal)

| Feature      | MoM Change | Current Users | Prior Peak |
| ------------ | ---------- | ------------- | ---------- |
| [event_name] | -X%        | Y users       | Z users    |

### Low Penetration (Upsell/Training Opportunity)

| Feature      | Users | Penetration | Opportunity                  |
| ------------ | ----- | ----------- | ---------------------------- |
| [event_name] | X     | <10%        | [Training/Upsell/Enablement] |

### Abandoned Features (Investigate)

- [Feature]: Last used [X months ago], previously [Y users]

---

## 🎯 Recommendations

### 🔥 This Week (Critical Actions)

1. [Specific action with user name/ID and expected outcome]
2. [e.g., "Contact user_123 (admin) about declining login usage - dropped 60% in 7 days"]

### 📅 This Month (Strategic Initiatives)

1. [Medium-term action with business context]
2. [e.g., "Enable feature_advanced_analytics - only 8% adoption but solves their stated need"]

### 💰 Expansion Opportunities

1. [Upsell signal with usage evidence]
2. [e.g., "User growth +40% WoW, hitting seat limit - expansion conversation ready"]

---

## 📎 Report Details

- **Account ID**: [account_id]
- **Analysis Date**: [CURRENT_DATE]
- **Data Timeframe**: Last 60-90 days
- **Data Source**: GrowthCues Core (BigQuery)
- **Confidence**: [High/Medium/Low based on data volume and recency]

---

## Best Practices

- **Always name users** - CS needs who to contact, not aggregates. Use user_id values.
- **Start with metadata discovery** - Use `BigQuery:get_table_info` to understand available metrics before querying
- **Leverage pre-computed signals** - Start with health_segment and health_score, then drill into supporting metrics
- **Generate SQL from schema** - Use column descriptions to understand what to query and how to interpret results
- **Connect metrics to actions** - Every declining metric should have a recommended intervention
- **Be specific in recommendations** - "Contact user_123 (admin) about Feature X abandonment" not "improve engagement"
- **Show trends, not snapshots** - Direction matters more than point-in-time. Use month-over-month and week-over-week changes
- **Column descriptions are your guide** - They contain [Definition], [Context], and [Action] tags explaining interpretation
- **Flag data gaps** - Note low data volume, missing recent data, or accounts with sparse activity
- **Prioritize by impact** - Focus on changes affecting champions, admins, or multiple users
- **Validate health segment** - If health_segment seems wrong, explain why based on underlying metrics
- **Use semantic tools when appropriate** - `ask_data_insights` for exploration, `execute_sql` for precision

## Common Patterns

**Churn Risks:**

- health_segment = 'Critical - Dormant' or 'Critical - Usage Drop'
- Low volume change ratios indicating usage contraction
- Champion or admin users with dormant/churned lifecycle status
- Multiple core features showing significant negative month-over-month trends
- Dormant risk flags activated

**Expansion Signals:**

- Positive user momentum (net new users week-over-week)
- health_segment = 'Healthy' with high health_score
- Top-ranked users adopting advanced/premium features
- Low feature penetration on valuable features that solve their problems
- High stickiness ratios combined with growing user counts

**Engagement Recovery (At-Risk → Healthy):**

- Improving volume change ratios (approaching or exceeding 1.0)
- Increasing active days and stickiness metrics
- New feature adoptions in recent months
- Previously dormant users returning (check lifecycle status transitions)
