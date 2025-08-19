# Libra AI - API Configuration Guide

This comprehensive guide explains how to obtain and configure all the required and optional APIs for the Libra AI platform.

## 📋 Table of Contents

- [Required APIs](#required-apis)
- [Optional APIs](#optional-apis)
- [Database Configuration](#database-configuration)
- [Authentication Setup](#authentication-setup)
- [AI Providers Configuration](#ai-providers-configuration)
- [Payment Integration](#payment-integration)
- [Email Services](#email-services)
- [Sandbox Providers](#sandbox-providers)
- [Security Services](#security-services)
- [Analytics & Monitoring](#analytics--monitoring)
- [Environment Variables Summary](#environment-variables-summary)

---

## 🔑 Required APIs

These APIs are essential for the platform to function properly.

### 1. Cloudflare Services

Libra AI is built for Cloudflare Workers and requires several Cloudflare services.

#### **Cloudflare Account Setup**
1. Sign up at [Cloudflare](https://cloudflare.com)
2. Get your Account ID from the dashboard sidebar
3. Create an API Token:
   - Go to **My Profile** → **API Tokens**
   - Click **Create Token** → **Custom Token**
   - Permissions needed:
     - `Zone:Zone Settings:Edit`
     - `Zone:Zone:Read`
     - `Account:Cloudflare Workers:Edit`
     - `Account:Account Settings:Read`
     - `Account:D1:Edit`

```env
CLOUDFLARE_ACCOUNT_ID=your_cloudflare_account_id
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token
CLOUDFLARE_ZONE_ID=your_zone_id_if_using_custom_domain
```

#### **Cloudflare D1 Database**
1. Create a D1 database in Cloudflare Dashboard
2. Copy the Database ID

```env
DATABASE_ID=your_d1_database_id
```

### 2. PostgreSQL Database (Neon)

For business data storage, Libra uses PostgreSQL via Neon.

#### **Neon Setup**
1. Sign up at [Neon](https://neon.tech)
2. Create a new database
3. Copy the connection string

```env
POSTGRES_URL=postgresql://user:password@host:5432/database?sslmode=require
```

### 3. GitHub OAuth Application

Required for user authentication and GitHub integration.

#### **GitHub OAuth App Setup**
1. Go to GitHub → **Settings** → **Developer settings** → **OAuth Apps**
2. Click **New OAuth App**
3. Fill in the details:
   - **Application name**: `Libra AI`
   - **Homepage URL**: `https://your-domain.com`
   - **Authorization callback URL**: `https://your-domain.com/api/auth/github/callback`
4. Copy the Client ID and generate a Client Secret

```env
BETTER_GITHUB_CLIENT_ID=your_github_client_id
BETTER_GITHUB_CLIENT_SECRET=your_github_client_secret
```

### 4. Better Auth Secret

Generate a secure secret for JWT tokens.

```bash
# Generate a secure 32-character secret
openssl rand -base64 32
```

```env
BETTER_AUTH_SECRET=your_32_character_secret_key
```

### 5. Anthropic API (Claude)

Primary AI provider for code generation.

#### **Anthropic API Setup**
1. Sign up at [Anthropic Console](https://console.anthropic.com)
2. Create an API key
3. Add credits to your account

```env
ANTHROPIC_API_KEY=your_anthropic_api_key
```

---

## 🔧 Optional APIs

These APIs enhance functionality but are not required for basic operation.

### AI Providers

#### **OpenAI API**
1. Sign up at [OpenAI Platform](https://platform.openai.com)
2. Create an API key
3. Add billing information

```env
OPENAI_API_KEY=sk-your_openai_api_key
```

#### **Azure OpenAI**
1. Create an Azure account
2. Set up Azure OpenAI service
3. Deploy models and get endpoint details

```env
AZURE_API_KEY=your_azure_api_key
AZURE_BASE_URL=https://your-resource.openai.azure.com
AZURE_DEPLOYMENT_NAME=your_deployment_name
AZURE_RESOURCE_NAME=your_resource_name
```

#### **xAI (Grok)**
1. Sign up at [xAI Console](https://console.x.ai)
2. Create an API key

```env
XAI_API_KEY=xai-your_api_key
```

#### **Google Gemini**
1. Go to [Google AI Studio](https://aistudio.google.com)
2. Create an API key

```env
GEMINI_API_KEY=your_gemini_api_key
```

#### **DeepSeek**
1. Sign up at [DeepSeek Platform](https://platform.deepseek.com)
2. Create an API key

```env
DEEPSEEK_API_KEY=sk-your_deepseek_api_key
```

#### **OpenRouter**
Access to multiple AI models through a single API.

1. Sign up at [OpenRouter](https://openrouter.ai)
2. Create an API key

```env
OPENROUTER_API_KEY=sk-or-v1-your_openrouter_key
```

#### **Databricks**
For enterprise AI model access.

1. Set up Databricks workspace
2. Create a personal access token

```env
DATABRICKS_TOKEN=your_databricks_token
DATABRICKS_BASE_URL=https://your-workspace.databricks.com
```

---

## 💳 Payment Integration

### Stripe Setup

For subscription management and billing.

#### **Stripe Configuration**
1. Sign up at [Stripe Dashboard](https://dashboard.stripe.com)
2. Get your API keys from **Developers** → **API keys**
3. Set up webhook endpoint for subscription events:
   - URL: `https://your-domain.com/api/webhooks/stripe`
   - Events: `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`

```env
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
```

#### **Stripe Product Setup**
Create subscription plans in Stripe Dashboard:

1. **Libra Pro**
   - Monthly subscription
   - Price ID: `price_pro_monthly`
   - Features: 1000 AI calls, 5 seats, 10 projects

2. **Libra Max**
   - Monthly subscription  
   - Price ID: `price_max_monthly`
   - Features: 5000 AI calls, 20 seats, 50 projects

---

## 📧 Email Services

### Resend Setup

For transactional emails (OTP, notifications).

#### **Resend Configuration**
1. Sign up at [Resend](https://resend.com)
2. Verify your sending domain
3. Create an API key

```env
RESEND_API_KEY=re_your_resend_api_key
RESEND_FROM=noreply@your-domain.com
```

---

## 🏗️ Sandbox Providers

For code execution environments.

### E2B Setup

Primary sandbox provider for code execution.

#### **E2B Configuration**
1. Sign up at [E2B](https://e2b.dev)
2. Create an API key
3. Set up templates in E2B dashboard

```env
E2B_API_KEY=your_e2b_api_key
E2B_TIMEOUT=30000
E2B_RETRIES=3
```

### Daytona Setup (Alternative)

Alternative sandbox provider.

#### **Daytona Configuration**
1. Sign up at [Daytona](https://daytona.io)
2. Get API credentials

```env
DAYTONA_API_KEY=your_daytona_api_key
DAYTONA_API_URL=https://api.daytona.io
DAYTONA_TIMEOUT=45000
DAYTONA_RETRIES=3
```

#### **Sandbox Provider Selection**
```env
NEXT_PUBLIC_SANDBOX_DEFAULT_PROVIDER=e2b
NEXT_PUBLIC_SANDBOX_BUILDER_DEFAULT_PROVIDER=e2b
```

---

## 🔒 Security Services

### Cloudflare Turnstile

For bot protection and CAPTCHA.

#### **Turnstile Setup**
1. Go to Cloudflare Dashboard → **Turnstile**
2. Create a new site
3. Get Site Key and Secret Key

```env
TURNSTILE_SECRET_KEY=your_turnstile_secret_key
NEXT_PUBLIC_TURNSTILE_SITE_KEY=your_turnstile_site_key
```

---

## 📊 Analytics & Monitoring

### PostHog Analytics

For user behavior tracking and analytics.

#### **PostHog Setup**
1. Sign up at [PostHog](https://posthog.com)
2. Create a project
3. Get your Project API Key

```env
NEXT_PUBLIC_POSTHOG_KEY=phc_your_posthog_key
NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com
```

### Google Analytics (Optional)

For additional web analytics.

#### **Google Analytics Setup**
1. Create a Google Analytics 4 property
2. Get your Measurement ID

```env
NEXT_PUBLIC_GA_ID=G-your_measurement_id
```

---

## 🛠️ Database Configuration

### Required Database Setup

#### **PostgreSQL (Neon) - Business Data**
- User projects
- Organization data
- Usage quotas
- File structures

#### **SQLite (Cloudflare D1) - Authentication Data**
- User accounts
- Sessions
- Stripe subscriptions
- Organization memberships

### Database Migration

After setting up your databases, run migrations:

```bash
# Run PostgreSQL migrations
bun run migrate

# D1 migrations are handled automatically by better-auth
```

---

## 🌐 Application URLs

Configure your application URLs for proper routing:

```env
NEXT_PUBLIC_APP_URL=https://your-domain.com
NEXT_PUBLIC_CDN_URL=https://cdn.your-domain.com
NEXT_PUBLIC_DEPLOY_URL=https://deploy.your-domain.com
NEXT_PUBLIC_SCREENSHOT_URL=https://screenshot.your-domain.com
```

---

## 📝 Environment Variables Summary

### Required Variables

```env
# Database
POSTGRES_URL=postgresql://user:password@host:5432/database
DATABASE_ID=your_d1_database_id

# Authentication
BETTER_AUTH_SECRET=your_32_character_secret
BETTER_GITHUB_CLIENT_ID=your_github_client_id
BETTER_GITHUB_CLIENT_SECRET=your_github_client_secret

# AI Provider (at least one required)
ANTHROPIC_API_KEY=your_anthropic_api_key

# Cloudflare
CLOUDFLARE_ACCOUNT_ID=your_account_id
CLOUDFLARE_API_TOKEN=your_api_token

# Security
TURNSTILE_SECRET_KEY=your_turnstile_secret
NEXT_PUBLIC_TURNSTILE_SITE_KEY=your_turnstile_site_key

# Application URLs
NEXT_PUBLIC_APP_URL=https://your-domain.com
NEXT_PUBLIC_CDN_URL=https://cdn.your-domain.com
NEXT_PUBLIC_DEPLOY_URL=https://deploy.your-domain.com
```

### Optional Variables

```env
# Additional AI Providers
OPENAI_API_KEY=sk-your_openai_key
AZURE_API_KEY=your_azure_key
AZURE_BASE_URL=https://your-resource.openai.azure.com
XAI_API_KEY=xai-your_key
GEMINI_API_KEY=your_gemini_key
DEEPSEEK_API_KEY=sk-your_deepseek_key
OPENROUTER_API_KEY=sk-or-v1-your_key
DATABRICKS_TOKEN=your_databricks_token
DATABRICKS_BASE_URL=https://your-workspace.databricks.com

# Payment Processing
STRIPE_SECRET_KEY=sk_test_your_stripe_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Email Services
RESEND_API_KEY=re_your_resend_key
RESEND_FROM=noreply@your-domain.com

# Sandbox Providers
E2B_API_KEY=your_e2b_key
DAYTONA_API_KEY=your_daytona_key
DAYTONA_API_URL=https://api.daytona.io

# Analytics
NEXT_PUBLIC_POSTHOG_KEY=phc_your_posthog_key
NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com
NEXT_PUBLIC_GA_ID=G-your_measurement_id

# Feature Flags
REASONING_ENABLED=true
ENHANCED_PROMPT=true
NEXT_PUBLIC_SCAN=1
```

---

## 🚀 Quick Start Checklist

1. **✅ Set up Cloudflare account and services**
   - Account ID and API Token
   - D1 Database
   - Turnstile (optional)

2. **✅ Create PostgreSQL database (Neon)**
   - Database connection string

3. **✅ Configure GitHub OAuth**
   - OAuth application
   - Client ID and Secret

4. **✅ Generate Better Auth secret**
   - 32-character secure key

5. **✅ Set up AI provider**
   - At minimum: Anthropic API key
   - Optional: OpenAI, Azure, xAI, etc.

6. **✅ Configure payment processing (optional)**
   - Stripe account and webhooks

7. **✅ Set up email service (optional)**
   - Resend API key

8. **✅ Configure sandbox provider (optional)**
   - E2B or Daytona API key

9. **✅ Set up analytics (optional)**
   - PostHog project key

10. **✅ Run database migrations**
    ```bash
    bun run migrate
    ```

---

## 🔗 Useful Links

- [Libra AI Documentation](https://docs.libra.sh)
- [Cloudflare Workers](https://workers.cloudflare.com)
- [Neon PostgreSQL](https://neon.tech)
- [Better Auth](https://better-auth.com)
- [Anthropic Console](https://console.anthropic.com)
- [Stripe Dashboard](https://dashboard.stripe.com)
- [E2B Platform](https://e2b.dev)
- [Resend](https://resend.com)
- [PostHog](https://posthog.com)

---

## 💡 Tips

1. **Start with minimum required APIs** and add optional services as needed
2. **Use test/development keys** during development
3. **Set up webhooks properly** for Stripe integration
4. **Monitor API usage** to avoid unexpected charges
5. **Keep API keys secure** and never commit them to version control
6. **Use environment-specific configurations** for development vs production

---

## 🆘 Support

If you encounter issues with API setup:

1. Check the [Libra AI Documentation](https://docs.libra.sh)
2. Review the service-specific documentation linked above
3. Join our [Discord Community](https://discord.gg/libra-ai)
4. Open an issue on [GitHub](https://github.com/libra-ai/libra)

---

**Last Updated**: January 2025  
**Version**: 1.0  
**Maintainers**: Libra AI Team
