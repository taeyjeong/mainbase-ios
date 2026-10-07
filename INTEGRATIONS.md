# MainBase: API Integrations by Project Area

> **Prompt:** wait ok, look at everything and tell me what APIs can be connected. i mean an admin being able to connect their own API btw. from github, figma, slack, trello, airtable, list all the recommendations for all 5 nodes

---

The 5 nodes are the areas on the Projects2 wheel ([Projects2View.swift](MainBase/Views/Projects/Projects2View.swift)): **Design, Develop, Marketing, Operations, Growth**, each with 3 sub-areas. Below are the services an admin could connect with their own account, grouped by those sub-areas.

**Auth** says how the admin connects:
- **OAuth:** they tap "Connect" and sign in.
- **Key:** they paste an API key or personal token.

⭐ marks the one to build first in each area.

## 🎨 Design (Branding · UI/UX · Research)

| Sub-area | API | What it does in MainBase | Auth |
|---|---|---|---|
| UI/UX | ⭐ **Figma** | Attach frames to tasks, show thumbnails, sync comments, push alerts when a new version is published | OAuth / Key |
| Branding | **Canva Connect** | Export designs into the project photo gallery, open "Edit in Canva" from a task | OAuth |
| Branding | **Adobe Creative Cloud Libraries** | Pull brand colors, logos and assets into a project | OAuth |
| UI/UX | **Miro** | Whiteboards and flows; it also accepts writes, so diagrams could be pushed to a board | OAuth |
| Research | **Typeform / SurveyMonkey** | Survey responses as project data | OAuth / Key |
| Research | **Dovetail** | User-research insights and highlights | Key |

## 🔨 Develop (Frontend · Backend · QA)

| Sub-area | API | What it does in MainBase | Auth |
|---|---|---|---|
| All | ⭐ **GitHub** (as a GitHub App) | Link repos to projects, show PRs and issues, mark a task done when its PR merges, push alerts for CI results | OAuth |
| All | **GitLab / Bitbucket** | Same as GitHub, for teams that use them | OAuth |
| All | **Linear / Jira** | Two-way sync between their issues and MainBase tasks and subtasks | OAuth / Key |
| Frontend | **Vercel / Netlify** | Deploy status and preview links on a project | OAuth / Key |
| Backend | **Supabase / Render / Railway** | Service health and deploy status | Key |
| QA | **Sentry** | Crash and error counts per project, with alerts | Key |
| QA | **App Store Connect** | TestFlight builds and review status | Key (.p8) |

## 📣 Marketing (Content · Social · Campaigns)

| Sub-area | API | What it does in MainBase | Auth |
|---|---|---|---|
| Campaigns | ⭐ **HubSpot** | Contacts, deals and campaign stats (the workflow diagram already uses it) | OAuth |
| Campaigns | **Mailchimp / Klaviyo** | Email campaign results: opens, clicks, list growth | OAuth / Key |
| Campaigns | **Google Ads / Meta Marketing** | Ad spend, which could feed the project budget | OAuth (needs approval) |
| Content | **Notion / Google Docs** | Link content drafts to tasks | OAuth |
| Content | **WordPress / Webflow** | Publishing status of posts and pages | OAuth / Key |
| Social | **Meta Graph (Instagram/Facebook)** / **LinkedIn** | Post performance | OAuth (app review required) |
| Content | **Airtable** | Content calendar as a synced base | OAuth / Key |

## ⚙️ Operations (Finance · People · Logistics)

| Sub-area | API | What it does in MainBase | Auth |
|---|---|---|---|
| Finance | ⭐ **QuickBooks Online / Xero** | Sync project budgets and expenses, export wage logs and payouts | OAuth |
| Finance | **Stripe** | Revenue and payments per project | OAuth (Connect) / Key |
| People | **Gusto / BambooHR / Deel** | Employees, pay rates and time-off, synced with the wage log and schedule | OAuth / Key |
| People | **Google Calendar / Outlook** | Shifts and time-off on calendars | OAuth |
| Logistics | **Airtable** | Inventory and vendor tables | OAuth / Key |
| Logistics | **Trello / Asana** | Ops boards synced with MainBase tasks | OAuth / Key |
| Logistics | **Shippo / EasyPost** | Shipment tracking | Key |

## 📈 Growth (Training · Mentoring · Analytics)

| Sub-area | API | What it does in MainBase | Auth |
|---|---|---|---|
| Analytics | ⭐ **Google Analytics 4 Data API** | Traffic and conversion charts per project | OAuth |
| Analytics | **Mixpanel / Amplitude / PostHog** | Product metrics | Key |
| Training | **Loom / YouTube** | Training videos attached to onboarding tasks | OAuth / Key |
| Training | **Notion** | Training wiki and SOPs | OAuth |
| Mentoring | **Calendly / Zoom** | 1:1 and mentoring sessions on the schedule | OAuth |
| Mentoring | **Google Calendar** | Mentoring sessions on the schedule | OAuth |

## 🔗 Across all 5 areas

- **Slack** ⭐: mirror MainBase notifications (clock events, task done, chat) into channels, plus a `/mainbase` command. Probably the most useful single integration.
- **Google Drive / Dropbox:** attach files to any project.
- **Discord or Microsoft Teams:** the same role as Slack, for teams that don't use it.

## How "admin connects their own" fits the stack

1. Add an **Integrations** screen under Admin Tools listing the providers above.
2. **OAuth providers:** open the sign-in page in the app (`ASWebAuthenticationSession`). A Cloud Function then exchanges the code for tokens and refreshes them later. The client secret must never ship in the app.
3. **Key providers:** the admin pastes the key and a Cloud Function saves it.
4. **Where secrets live:** store tokens and keys in a Firestore collection the rules deny to all clients, or in Secret Manager. Clients only see `{provider, connected, accountName}`.
5. **Events in:** webhooks from GitHub, Figma, Slack, HubSpot, Stripe and others hit `onRequest` functions. Those write to Firestore, and the existing `sendUserNotificationPush` handles the alerts.
6. **Linking to projects:** a `projects/{id}/links` subcollection (provider, external ID, area, sub-area) attaches items to projects and areas without changing the schema for each provider.

**Suggested build order:** Slack → GitHub → Figma → QuickBooks → GA4. Together they cover all 5 areas with the most-used tools.

> This list was written from general knowledge, not a check of each provider's current docs. Approval requirements (Meta, LinkedIn, Google Ads, Gusto) and pricing change often, so confirm before building.
