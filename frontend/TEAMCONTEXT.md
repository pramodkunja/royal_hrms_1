# Team Context

**Name:** Safura Samreen
**Last Updated:** 24 June 2026 (Session 2)

I worked on the **Royal HRMS** frontend — a Next.js 16 (App Router) HR management system. Below is everything built in this session.

---

## Tech Stack

- **Framework:** Next.js 16.2.9 with App Router and Turbopack
- **Styling:** Tailwind CSS v2.2.19 (JIT mode) + custom CSS design system (Sahara theme)
- **Icons:** Tabler Icons webfont via CDN (`ti-*` classes)
- **HTTP:** Axios via `clientApi` (`lib/clientApi.ts`) — attaches Bearer token from localStorage automatically
- **Auth:** JWT stored in localStorage + user info in a cookie (`USER_COOKIE`)
- **Backend base URL:** `http://localhost:8000/api`

---

## What I Built

### 1. Dashboard Shell — Sidebar + Navbar (`components/dashboard/DashboardShell.tsx`)

- Sidebar with collapsible width (220 px → 56 px), logo, nav items with section labels, user card at the bottom
- **Permission-based navigation** (industry standard) — sidebar items are driven entirely by `user.permissions[]` returned at login. No role-to-nav mapping, no extra API calls after login.
- `lib/navConfig.ts` has a single master nav list; each item declares the permission string it needs (e.g. `"settings.view"`). `buildNav(permissions[])` filters it at render time.
- Top navbar: page title (derived from current path), search bar, dark mode toggle, notifications bell with unread dot, logout button
- Session passed as a prop from the server layout (`app/dashboard/layout.tsx`)

### 2. Settings Page (`app/dashboard/settings/page.tsx`)

- Settings landing page with category pills and card tiles
- "Roles & Permissions" card navigates to `/dashboard/settings/permissions`

### 3. Roles & Permissions Page (`app/dashboard/settings/permissions/`)

Full CRUD page wired to real API endpoints.

#### File structure (industry standard):
```
permissions/
  _data.ts                          ← types, helpers, preset definitions
  page.tsx                          ← orchestrator, all API calls live here
  _components/
    RoleFormFields.tsx              ← shared form body (used by both modals)
    AddRoleModal.tsx                ← POST /api/roles/
    EditRoleModal.tsx               ← PUT /api/roles/{id}/
```

#### Features:
- **Roles table** — shows display name, slug (read-only code tag), permission count, user count, action buttons
- **Add Role** — modal with role name + permission tree → `POST /api/roles/`
- **Edit Role** — pre-populated modal, slug shown as locked field → `PUT /api/roles/{id}/` (name and is_active preserved, only display_name and permissions editable)
- **Active/Inactive toggle** — icon button with CSS tooltip → `PATCH /api/roles/{id}/` with `{ is_active: bool }`, spinner shown during request
- **Permission Matrix** — rows = API modules, columns = roles; cells show "Full (N)" badge / individual action badges / "—"
- **Loading state** with spinner, error state with retry button

#### Quick Permission Presets (in both Add and Edit modals):
Four one-click preset chips that pre-fill the permission tree:

| Preset | Selects |
|--------|---------|
| Full Admin | All 46 permissions |
| View Only | Every `*.view` codename |
| Manager | View/approve across employees, attendance, leave, expenses, documents, recruitment, reports |
| Employee | Self-service view/create on leave, attendance, payroll, expenses, documents, announcements, referrals |

Active preset is detected live — chip highlights when current selection exactly matches it, un-highlights the moment any checkbox is manually changed. A counter below shows `X of 46 permissions selected`.

#### Module accordion tree:
- Per-module collapsible rows with indeterminate checkbox state (partial selection)
- Per-action checkboxes (view, create, edit, delete, export, approve)
- Module-level count badge (`3/6`) turns primary-colour when anything is selected

### 4. Role-Based Dashboard (`app/dashboard/page.tsx` + `_components/`)

Server component reads the session role and renders the matching layout:

| Role | Dashboard |
|------|-----------|
| `hr_admin` | Greeting banner, Quick Actions, HR Action Queue, Today's Birthdays, Work Anniversaries, Recruitment Funnel, CSS Donut dept chart, Live Activity timeline |
| `system_admin` | Dark blue banner, Quick Actions, Module Health grid (operational/warn indicators), Dept headcount, Recent System Events, Active Sessions |
| `manager` | Green banner, Quick Actions, Pending Approvals (approve/reject buttons), Team Attendance Today, Upcoming Leaves |
| `employee` | Personal banner, Quick Actions, Attendance stats, Leave Balance progress bars, My Requests, Upcoming Events |

All dashboard views use static/mock data matching the HTML reference design (`royal-hrms-1.html`).

### 5. SMTP Settings (`app/dashboard/settings/smtp/`)

Full CRUD page for managing outgoing mail server configurations, wired to the real REST API.

#### File structure:
```
smtp/
  _data.ts                    ← types, converters, validation, endpoint helpers
  page.tsx                    ← dynamic card list, all API calls live here
  _components/
    SmtpModal.tsx             ← Add / Edit modal
```

#### Features:
- **Dynamic card grid** (2 per row) — one card per saved SMTP config, active config highlighted with a primary border
- **Add SMTP** — modal with Configuration Name (required, free-text label), host, port, TLS toggle, sender name, from email, username, password, BCC, priority, receiver email type
- **Edit** — same modal pre-populated; password field shows "leave blank to keep current"
- **Set Active** — `POST /api/settings/smtp/{id}/activate/` (no body), instantly marks card as active
- **Delete** — `DELETE /api/settings/smtp/{id}/` with confirmation dialog
- **Test Email** — modal asks for recipient + SMTP password (required by API), then `POST /api/settings/smtp/test/` with full config fields + `test_recipient`
- Active banner at top of page shows currently active config name + from_email

#### API shape (actual):
The `GET /api/settings/smtp/` response returns `data` as a **flat array** — each entry has a `name` field that is a user-defined label (e.g. "Gmail SMTP"), **not** "local"/"server". `is_active: true` marks the currently active one.

---

### 6. Email Templates (`app/dashboard/settings/email-templates/`)

Full CRUD page for transactional email templates, grouped by type, with a WYSIWYG editor.

#### File structure:
```
email-templates/
  _data.ts                    ← types, helpers, validation, API endpoints
  page.tsx                    ← grouped sections, all API calls live here
  _components/
    EditTemplateModal.tsx     ← WYSIWYG editor modal
```

#### Features:
- **Grouped display** — templates shown in sections by type: Document, Notification, Reminder, Wish (each with colored header)
- **Preview** — fetches `GET /api/settings/email-templates/{id}/preview/` and renders HTML in a modal
- **Edit** — WYSIWYG editor with toolbar (bold, italic, underline, strikethrough, lists, alignment, link/unlink, clear format), HTML source toggle, available-variable tag sidebar
- **Add** — requires Display Name (free-text, e.g. "Pay Slip") + Slug (auto-generated, e.g. `pay_slip`, must match `^[a-z][a-z0-9_]*$`), subject, body
- **Attachments bar** — fixed strip between editor and footer; "Attach files" button + horizontal chip list with file-type icons and image thumbnails; drag-and-drop supported
- `multipart/form-data` used when attachments are present; JSON otherwise

#### Template types (actual API):
`document` · `notification` · `reminder` · `wish`

#### API shape (actual):
`GET /api/settings/email-templates/` returns `data` as an object keyed by type — `{ document: [...], notification: [...], reminder: [...], wish: [...] }`. `flattenTemplates()` in `_data.ts` merges them into one array for filtering.

#### Slug rules (enforced client-side):
- Auto-generated from Display Name as user types
- Only `[a-z0-9_]` allowed; must start with a letter
- User can override the slug manually (auto-fill stops once manually edited)

---

## CSS Module Migration (Session 2)

All CSS module files were removed. Styles were migrated to Tailwind classes + inline `style={}` for CSS custom properties.

| Deleted file | Migrated to |
|---|---|
| `app/login/login.module.css` | Tailwind + inline styles in `app/login/page.tsx` |
| `app/dashboard/profile/profile.module.css` | Tailwind in `ProfileClient.tsx` + `ChangePasswordForm.tsx` |
| `app/dashboard/dashboard.module.css` | Was already unused — deleted |
| `app/dashboard/settings/settings.module.css` | Was already unused — deleted |
| `components/dashboard/DashboardShell.module.css` | Was already unused — deleted |

> **Tailwind v2 note:** `text-white/75` opacity modifier syntax does NOT work in v2.2.19 (v3 only). Use inline `style={{ color: "rgba(255,255,255,0.75)" }}` instead.

---

## API Endpoints Used

| Method | Endpoint | Used for |
|--------|----------|----------|
| `POST` | `/api/login/` | Login — returns `user.permissions[]` used for all sidebar/route access |
| `POST` | `/api/roles/` | Create new role |
| `PUT` | `/api/roles/{id}/` | Full update role (edit modal) |
| `PATCH` | `/api/roles/{id}/` | Toggle is_active only |
| `GET` | `/api/permissions/` | Load all 46 permissions grouped by module |
| `POST` | `/api/logout/` | Logout and clear auth |
| `GET` | `/api/settings/smtp/` | List all SMTP configs (flat array) |
| `POST` | `/api/settings/smtp/` | Create SMTP config |
| `PUT` | `/api/settings/smtp/{id}/` | Full update SMTP config |
| `DELETE` | `/api/settings/smtp/{id}/` | Delete SMTP config |
| `POST` | `/api/settings/smtp/{id}/activate/` | Set config as active (no body) |
| `POST` | `/api/settings/smtp/test/` | Send test email (full SMTP fields + `test_recipient`) |
| `GET` | `/api/settings/email-templates/` | List templates grouped by type |
| `POST` | `/api/settings/email-templates/` | Create template (`multipart/form-data`) |
| `PUT` | `/api/settings/email-templates/{id}/` | Update template |
| `GET` | `/api/settings/email-templates/{id}/preview/` | Rendered HTML preview |

> **Note:** `GET /api/roles/` is no longer called after login. Sidebar visibility is driven entirely by `user.permissions[]` from the login response.

---

## Key Files Changed / Created

| File | What |
|------|------|
| `tailwind.config.js` | Created — v2 JIT config |
| `postcss.config.mjs` | Updated — standard tailwindcss + autoprefixer |
| `app/globals.css` | Added Tailwind directives + all design system utility classes |
| `lib/navConfig.ts` | Rewritten — single master nav list with per-item `permission` field; `buildNav(permissions[])` replaces role trees |
| `lib/auth.ts` | Added `permissions: string[]` to `UserInfo` |
| `lib/session.ts` | Added `permissions: string[]` to `SessionPayload` |
| `app/login/page.tsx` | Reads `user.permissions` from login response, saves to cookie/localStorage |
| `components/dashboard/DashboardShell.tsx` | Removed `/roles/` fetch; uses `buildNav(session.permissions)` directly |
| `app/dashboard/page.tsx` | Local `resolveRole` for dashboard widget selection; no navConfig import |
| `proxy.ts` | Added permission-based route protection — direct URL access blocked if user lacks permission |
| `app/dashboard/_components/HRDashboard.tsx` | New |
| `app/dashboard/_components/AdminDashboard.tsx` | New |
| `app/dashboard/_components/ManagerDashboard.tsx` | New |
| `app/dashboard/_components/EmployeeDashboard.tsx` | New |
| `app/dashboard/settings/page.tsx` | Updated — "Roles & Permissions" card + routing |
| `app/dashboard/settings/permissions/_data.ts` | Full rewrite — real API types + presets |
| `app/dashboard/settings/permissions/page.tsx` | Full rewrite — API integration + edit flow |
| `app/dashboard/settings/permissions/_components/RoleFormFields.tsx` | New — shared form body |
| `app/dashboard/settings/permissions/_components/AddRoleModal.tsx` | Rewritten — uses RoleFormFields |
| `app/dashboard/settings/permissions/_components/EditRoleModal.tsx` | New |
| `app/dashboard/settings/smtp/_data.ts` | New — SMTP types, endpoint helpers (`smtpDetail(id)`, `smtpActivate(id)`), form/payload converters |
| `app/dashboard/settings/smtp/page.tsx` | New — dynamic card list, CRUD + activate + delete + test |
| `app/dashboard/settings/smtp/_components/SmtpModal.tsx` | New — Add/Edit modal with name + all SMTP fields |
| `app/dashboard/settings/email-templates/_data.ts` | New — template types (doc/notification/reminder/wish), `flattenTemplates()`, `toSlug()`, form/validation |
| `app/dashboard/settings/email-templates/page.tsx` | New — grouped sections, preview modal, create/update with multipart |
| `app/dashboard/settings/email-templates/_components/EditTemplateModal.tsx` | New — WYSIWYG editor, HTML source toggle, variable tag sidebar, attachment bar |

---

## Demo Credentials

| Email | Password | Role |
|-------|----------|------|
| hradmin@royal.com | Hrms@1234 | hr_admin |
| sysadmin@royal.com | Hrms@1234 | system_admin |
| manager@royal.com | Hrms@1234 | manager |
| employee@royal.com | Hrms@1234 | employee |

---

## Notes for Next Developer

- The `session` object (`lib/session.ts`) contains `userId`, `email`, `name`, `role`, `permissions[]` — stored in a cookie after login
- `clientApi` (`lib/clientApi.ts`) automatically attaches the Bearer token from `localStorage["royal_token"]`
- All API responses follow the envelope `{ status, message, data }` — always check `res.data.data` for the payload
- The design system variables (`--primary`, `--on-bg`, `--outline-v`, etc.) are defined in `app/globals.css` and referenced in Tailwind via arbitrary values like `bg-[var(--primary)]`
- Dashboard pages are **server components** — they call `getSession()` directly. Sub-components that need interactivity are `"use client"` with `useState`/`useEffect`
- **Sidebar visibility + route protection both use `user.permissions[]`** — if you add a new page, add it to both `lib/navConfig.ts` (master nav) and `proxy.ts` (`ROUTE_PERMISSIONS` map)
- `proxy.ts` (not `middleware.ts`) is this project's Next.js edge proxy — the framework uses a custom convention

---

## Session 2 Notes (24 June 2026)

- **Hydration warning fix** — `fdprocessedid` browser-extension attributes injected into DOM elements cause React hydration mismatches. Fix: add `suppressHydrationWarning` to every `<button>` and `<input>` in DashboardShell. Adding it only to `<html>`/`<body>` in `layout.tsx` is not enough.
- **SMTP API is a flat array** — `GET /api/settings/smtp/` returns `data: [...]`, not `{ local: {}, server: {} }`. Each entry's `name` is a user-defined label. Activate is by entry `id`, not by type string.
- **Email template API is grouped by type** — `GET /api/settings/email-templates/` returns `data: { document: [...], notification: [...], reminder: [...], wish: [...] }`. Use `flattenTemplates()` to get a flat array.
- **Template `name` is a slug** — must match `^[a-z][a-z0-9_]*$`. A separate `display_name` field (human-readable) is also required on create. The modal auto-generates the slug from the display name.
- **Tailwind v2 does not support opacity modifiers** — `text-white/75` is a v3 feature. Use inline `style={{ color: "rgba(...)" }}` or CSS variables.

---

## Announcements Page — Rithwika (24 June 2026)

### `app/dashboard/announcements/page.tsx`

Full static announcements page (all styling pure Tailwind, no CSS modules). Colors: primary `#1e4e8c`, pinned accent `#c99a2e`.

- Page header + "+ Post Announcement" button
- 4 stat cards (Total Posts, Pinned, Reactions, Views) — recalculate live
- Filter tabs: All · General · Policy · Events · Celebrations
- Post cards with gold left-border for pinned; avatar initials, badges, counts, edit button
- Modal for add/edit with fields: Title, Category, Visibility, Branch, Body, Pin, Email notification
- **Currently fully static** — wire up to `/api/announcements/` when backend is ready

### Sidebar Dual-Active Bug Fix (`DashboardShell.tsx`)

`/dashboard/announcements`.startsWith(`/dashboard/`) was also activating the Dashboard nav item. Fix:
```ts
const isActive = pathname === item.path ||
  (item.path !== "/dashboard" && pathname.startsWith(item.path + "/"));
```


25/06/2026
Developed Employee Management screens
Created Employee Profile screen
Implemented Add Employee screen for Admin Panel
Designed employee information form and validation
Added employee data creation functionality
Developed employee profile view and update features
Integrated employee details with admin access controls
Improved employee management workflow in HRMS
Implemented responsive UI for employee screens
Tested employee creation and profile functionalities