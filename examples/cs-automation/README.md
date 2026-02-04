# ⚡️ Tutorial: Automating "Silent Churn" Alerts

This repository includes a production-ready template for **Headless Churn Monitoring**.  
Instead of buying a SaaS tool to watch your dashboards, you can use **GitHub Actions** (Free Tier) to poll your BigQuery warehouse every morning.

**The Logic:**

1. It queries fct_account_metrics_daily.
2. It identifies accounts where volume_change_ratio_7d \< 0.5 (Usage dropped by \>50% week-over-week).
3. It sends a high-priority alert to Slack with the account details.

## 1. Prerequisites

### A. Slack Webhook

1. Go to [Incoming Webhooks](https://api.slack.com/messaging/webhooks) in your Slack workspace.
2. Create a new App (e.g., "GrowthCues Bot").
3. Add a Webhook to a specific channel (e.g., \#customer-success or \#risk-alerts).
4. Copy the **Webhook URL**.

### B. Google Cloud Service Account

1. Go to **IAM & Admin** \> **Service Accounts** in Google Cloud.
2. Create a new account with the following roles:
   - BigQuery Job User
   - BigQuery Data Viewer
3. Create and download a **JSON Key** for this account.

## 2. Configure GitHub Secrets

To run securely, GitHub needs access to your keys.

1. Navigate to your repository on GitHub.
2. Go to **Settings** \-\> **Secrets and variables** \-\> **Actions**.
3. Click **New repository secret** for each of the following:

| Name              | Value                                                       |
| :---------------- | :---------------------------------------------------------- |
| SLACK_WEBHOOK_URL | The URL you copied from Slack.                              |
| GCP_PROJECT_ID    | Your Google Cloud Project ID (string).                      |
| GCP_SA_KEY        | The **entire content** of the JSON key file you downloaded. |

## 3. Activate the Automation

By default, the automation code lives in the examples/ folder so it doesn't run before you are ready. To turn it on:

1. **Copy the workflow file** to the active workflows directory:  
   mkdir \-p .github/workflows  
   cp examples/automation/churn_guard.yml .github/workflows/

2. **Commit and Push** the changes to GitHub.

## 4. Test It Out

You don't have to wait for the daily schedule (8:00 AM UTC) to test it.

1. Go to the **Actions** tab in your GitHub repository.
2. Select **Daily Churn Guard** from the left sidebar.
3. Click the **Run workflow** dropdown \-\> **Run workflow**.
4. Wait \~30 seconds for the container to spin up and query BigQuery.
5. Check your Slack channel\! 🚨

## **5\. Customizing the Logic**

The logic is Python-based and fully customizable.

**To change the sensitivity:**

Edit examples/cs-automation/churn_alert.py:

```python
# Only alert if usage drops by 70%
AND volume_change_ratio_7d < 0.3
```

You can adjust the threshold to whatever makes sense for your business.

**To change the schedule:**

Edit .github/workflows/churn_guard.yml:

# Run at 9:00 AM EST (14:00 UTC)

```yaml
- cron: "0 14 * * *"
```

You can customize it to run hourly, daily, weekly, etc.
