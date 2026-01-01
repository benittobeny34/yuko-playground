# Loyalty – Production Deployment Plan

This document outlines the **step-by-step production deployment plan** for enabling the **Loyalty module** with Shopify and Facebook integrations. Follow the steps **in order** to avoid misconfiguration issues.

---

## Prerequisites

Before starting, ensure:

* Production backend and frontend environments are ready
* Access to production `.env` files (backend & frontend)
* Shopify App credentials are created and approved
* Database access with permission to run seeders

---

## Step 1: Update Shopify & Facebook Environment Keys (Backend)

Update the **backend `.env` file** with the following production values:

```env
SHOPIFY_API_KEY=
SHOPIFY_API_SECRET=
SHOPIFY_API_CLIENT_ID=
SHOPIFY_API_REDIRECT_URI=shopify/callback
SHOPIFY_APP_HANDLE=

SHOPIFY_YUKO_THEME_APP_ID=

FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=
```

### Notes

* `SHOPIFY_API_REDIRECT_URI` should match the redirect URL configured in the Shopify Partner Dashboard
* `SHOPIFY_APP_HANDLE` must match the app handle used in Shopify
* Ensure all secrets are **production credentials**, not staging or development values

---

## Step 2: Run Integration Apps Seeder

Run the following command on the **production backend server**:

```bash
php artisan db:seed --class=IntegrationAppsSeeder --force
```

### What this does

* Registers required integration apps (Shopify, Facebook, etc.) in the database
* Ensures the Loyalty module can detect enabled integrations

⚠️ The `--force` flag is required in production.

---

## Step 3: Update Shopify Environment Keys (Frontend)

Update the **frontend environment variables** (usually `.env.production` or platform-specific env config):

```env
SHOPIFY_API_KEY=
VITE_SHOPIFY_API_KEY=
```

### Notes

* Both values should be the **same Shopify API key**
* `VITE_SHOPIFY_API_KEY` is required for client-side access
* Rebuild the frontend after updating these values

---

## Step 4: Verify Shopify Production App Configuration

Check and validate the following file in the frontend project:

```text
shopify.app.production.toml
```

### Verify the following:

* App name and handle are correct
* Redirect URLs match backend configuration
* Embedded app and scopes are correctly defined
* Production API key is referenced

Example checks:

* OAuth redirect URLs
* App proxy (if used)
* Webhook configuration

---

## Post-Deployment Checklist

After completing all steps:

* ✅ Backend server restarted
* ✅ Frontend rebuilt and redeployed
* ✅ Shopify app loads correctly inside admin
* ✅ OAuth flow completes successfully
* ✅ Loyalty features visible and functional
* ✅ No missing integration errors in logs

---

## Rollback Notes (Optional)

If issues occur:

* Revert `.env` changes
* Disable the Shopify app from Partner Dashboard
* Roll back frontend deployment

---

## Ownership & Maintenance

* **Backend**: Laravel (env + seeder)
* **Frontend**: React / Vite (env + Shopify config)
* **Integrations**: Shopify & Facebook

---

*Last updated: Production rollout – Loyalty module*
