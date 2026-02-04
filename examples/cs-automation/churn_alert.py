import os
from google.cloud import bigquery
import requests
import json

# 1. Setup Configuration
# We grab credentials from GitHub Secrets
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL")
PROJECT_ID = os.environ.get("GCP_PROJECT_ID")
SCHEMA_NAME = os.environ.get("SCHEMA_NAME", "growthcues_core")

# Initialize BigQuery Client
# Note: In a GitHub Action using 'google-github-actions/auth',
# the environment variable GOOGLE_APPLICATION_CREDENTIALS is set automatically.
client = bigquery.Client(project=PROJECT_ID)

print(f"Using GCP Project: {PROJECT_ID}")
print(f"Using BigQuery Schema: {SCHEMA_NAME}")

# 2. The Logic: Find "Silent Churn"
# We look for accounts where usage volume dropped by >50% week-over-week
# BUT only for accounts that are actually engaged (not noise)
query = f"""
    SELECT
        account_id,
        volume_change_ratio_7d,
        active_days_7d,
        wau,
        mau
    FROM `{PROJECT_ID}.{SCHEMA_NAME}.fct_account_metrics_daily`
    WHERE metric_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      AND volume_change_ratio_7d < 0.5        -- Usage dropped by >50%
      AND volume_change_ratio_7d > 0          -- But not completely silent (separate alert)
      AND is_active_monthly = 1               -- Account is still active (not already churned)
      AND wau >= 2                            -- Meaningful baseline: at least 2 weekly active users
    ORDER BY volume_change_ratio_7d ASC       -- Most severe drops first
    LIMIT 5
"""

print("Running Query to detect churn risks...")
print(query)


def send_slack_alert(accounts):
    if not accounts:
        print("No churn risks found today.")
        return

    # Build a fancy Slack Block Kit message
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "🚨 Silent Churn Risk Alert",
                "emoji": True,
            },
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "The following accounts have seen a **>50% drop** in usage volume this week:",
            },
        },
        {"type": "divider"},
    ]

    for row in accounts:
        vol_drop = round((1 - row["volume_change_ratio_7d"]) * 100)
        blocks.append(
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Account `{row['account_id']}`*\n📉 Usage dropped by *{vol_drop}%*\n🗓 Active Days: {row['active_days_7d']}/7\n👥 Weekly Active Users: {row['wau']}",
                },
            }
        )

    payload = {"blocks": blocks}
    if SLACK_WEBHOOK_URL:
        response = requests.post(
            SLACK_WEBHOOK_URL,
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"},
        )
        if response.status_code == 200:
            print(f"✅ Alert sent successfully! Status: {response.status_code}")
        else:
            print(f"❌ Failed to send alert. Status: {response.status_code}")
            print(f"Response: {response.text}")
            raise Exception(f"Slack webhook failed with status {response.status_code}")
    else:
        print("Dry Run (No Slack URL set):")
        print(json.dumps(payload, indent=2))


# 3. Execution
if __name__ == "__main__":
    try:
        query_job = client.query(query)
        results = [dict(row) for row in query_job]
        send_slack_alert(results)
    except Exception as e:
        print(f"Error running query or sending alert: {e}")
