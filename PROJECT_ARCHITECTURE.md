# HR Employee App — Project Architecture

This document explains how the Flutter app in this repository is put together: where the
API calls live, how the theme works, how screens and navigation are wired, how sign-in and
sessions work, and which files to open for common changes.

Everything here is based on the source code as it is today. Where something is **not**
implemented, it says so.

---

## Contents

1. [API Integration](#1-api-integration)
2. [Theme and UI Styling](#2-theme-and-ui-styling)
3. [Application Structure](#3-application-structure)
4. [Navigation and Screens](#4-navigation-and-screens)
5. [Authentication and Session Management](#5-authentication-and-session-management)
6. [State Management and Data Flow](#6-state-management-and-data-flow)
7. [System Messages and Error Handling](#7-system-messages-and-error-handling)
8. [Configuration and Environment](#8-configuration-and-environment)
9. [Backend Integration Map](#9-backend-integration-map)
10. [Safe Change Guide](#10-safe-change-guide)

---

## 1. API Integration

### 1.1 The three layers

All networking goes through three files:

| Layer | File | Class / member | Job |
|---|---|---|---|
| Configuration | `lib/config.dart` | `AppConfig` | Default base URL and the `/api/v1` prefix |
| HTTP transport | `lib/api/api_client.dart` | `ApiClient`, `ApiException` | Builds URLs, adds headers, sends requests, turns errors into `ApiException` |
| Endpoints | `lib/api/hr_api.dart` | `HrApi` | One method per backend endpoint; converts JSON into model classes |

Screens never call `ApiClient` directly. They call methods on `HrApi`, which they reach
through the session: `AppScope.read(context).api.<method>()` (see section 6).

### 1.2 HTTP library

The app uses the official [`http`](https://pub.dev/packages/http) package (`http: ^1.2.2`
in `pubspec.yaml`). There is no Dio, Retrofit, Chopper or generated client.

`ApiClient` keeps one `http.Client` (`_http`) for the life of the app and applies a
**20-second timeout** to every request (`_timeout`).

### 1.3 Base URL and the `/api/v1` prefix

- `AppConfig.apiPrefix` (`lib/config.dart`) is the constant `'/api/v1'`.
- `AppConfig.defaultBaseUrl` decides the server address when nothing else is set (details
  in [section 8](#8-configuration-and-environment)).
- `ApiClient._uri(path, query)` joins them as:

  ```
  <baseUrl without trailing slash> + /api/v1 + <path>
  ```

  So `client.get('/me/notifications')` becomes
  `http://<server>/api/v1/me/notifications`. Endpoint paths in `HrApi` therefore never
  include `/api/v1`.

### 1.4 How `--dart-define=API_BASE_URL=...` works

In `lib/config.dart`:

```dart
static const String _fromEnv = String.fromEnvironment('API_BASE_URL');
```

`String.fromEnvironment` reads a value baked in at **build time** by
`flutter run --dart-define=API_BASE_URL=http://host:port` (or `flutter build ...` with the
same flag). If the flag is not given, the value is an empty string.

`AppConfig.defaultBaseUrl` returns, in this order:

1. `API_BASE_URL` from `--dart-define`, if it is not empty;
2. otherwise `http://10.0.2.2:8080` on Android (the Android emulator's address for the
   host computer's `localhost`);
3. otherwise `http://localhost:8080`.

**Important:** this is only the *default*. A URL the user saved in the app wins over it
(see section 1.5).

### 1.5 Where the base URL actually used at runtime comes from

`Session.load()` in `lib/session.dart` creates the client like this:

```dart
ApiClient(baseUrl: prefs.getString(_kBaseUrl) ?? AppConfig.defaultBaseUrl)
```

- `_kBaseUrl` is the SharedPreferences key `'server.baseUrl'`.
- A value is saved there when the user changes the server on the **Login screen**
  (dns icon in the app bar → "Server address" dialog → `Session.setBaseUrl`).
- `Session.setBaseUrl('')` (an empty value) resets it to `AppConfig.defaultBaseUrl`.

So the order of priority on a device is:
**saved URL on the device → `--dart-define` value → platform default.**

If a phone already has a saved URL, rebuilding with a new `--dart-define` will not change
the server until the saved value is changed from the Login screen or the app data is
cleared.

### 1.6 Headers, methods and bodies

`ApiClient` (`lib/api/api_client.dart`) exposes three methods:

| Method | Signature | Body |
|---|---|---|
| GET | `get(String path, {Map<String, String>? query})` | none |
| POST | `post(String path, [Object? body])` | `jsonEncode(body)` |
| PUT | `put(String path, [Object? body])` | `jsonEncode(body)` |

There is **no DELETE or PATCH** method in the client.

Every request sends these headers (`ApiClient._headers`):

```
Accept: application/json
Content-Type: application/json
Authorization: Bearer <token>    // only when a token is set
```

Request bodies are built inside `HrApi`. Examples:

- `login` → `{'email': ..., 'password': ...}`
- `applyLeave` → `{'leaveTypeId', 'startDate', 'endDate', 'reason'?}`. Dates are sent as
  `yyyy-MM-dd` (`HrApi._wireDate`), and `reason` is left out when empty.
- `decideLeave` → `{'decision': 'APPROVED' | 'REJECTED', 'note'?}`

### 1.7 How the auth token is attached

- `ApiClient.token` holds the JWT in memory.
- `_headers` adds `Authorization: Bearer $token` whenever `token != null`.
- The token is set by `Session.login(...)` after a successful login, and by
  `Session.load()` when a saved, not-yet-expired token is found on the device.
- `Session.logout()` sets it back to `null`.

### 1.8 Responses and errors

`ApiClient._send(...)` handles every response:

1. **Network failure** (no connection, DNS error, etc.) → throws
   `ApiException('Could not reach the server. Check your internet connection and the server address.')`.
2. **Timeout** (20 s) → throws
   `ApiException('The server took too long to respond. Please try again.')`.
3. The body is decoded as UTF-8 and parsed as JSON. If parsing fails, the data is `null`.
4. **2xx** → returns the parsed JSON (`Map`, `List` or `null`).
5. **Anything else**:
   - If the status is **401** and a token was sent, it calls `onUnauthorized`, which
     `Session.load()` sets to `Session.logout` (see section 5.4).
   - It throws `ApiException` with:
     - the backend's `message` field, if the error body has a non-empty one (the comment
       says the backend's `GlobalExceptionHandler` always provides it);
     - otherwise a fallback from `_fallbackMessage(status)`: 401, 403, 404, or a generic
       "Something went wrong. Please try again."
   - `ApiException` also keeps `status` and the parsed error `body`.

`ApiException.toString()` returns only the message, so screens can show
`e.toString()` directly to the user.

In `HrApi`, list responses go through `_list(...)`, which expects a JSON array and maps
each item with a model's `fromJson`. Two endpoints also accept a Spring-style page object
(`{"content": [...]}`): `myLedTeams()` and `decidedApprovals()`.

### 1.9 Flow from a screen to the backend

Example: the Leave screen loads "My requests".

```
LeaveScreen._reload()                         lib/screens/leave_screen.dart
  └─ AppScope.read(context).api               lib/session.dart  (Session.api is an HrApi)
       └─ HrApi.myLeaveRequests()             lib/api/hr_api.dart
            └─ ApiClient.get('/me/leave-requests')     lib/api/api_client.dart
                 ├─ _uri → <baseUrl>/api/v1/me/leave-requests
                 ├─ _headers (adds Bearer token)
                 └─ http.Client.get(...)  ──►  backend
            ◄─ JSON list
       ◄─ List<LeaveRequest>  (via LeaveRequest.fromJson in lib/models.dart)
  └─ Future given to AsyncBody, which shows skeleton → list or ErrorState
```

### 1.10 Which API methods each screen uses

| Screen | File | `HrApi` methods used |
|---|---|---|
| Login | `lib/screens/login_screen.dart` | `login` (through `Session.login`) |
| Home | `lib/screens/dashboard_screen.dart` | `myAttendance`, `myQuotas`, `pendingApprovals`, `unreadCount`, `holidays`, plus `approvalAccess` and `myLedTeams` through `approverKind()` |
| Attendance | `lib/screens/attendance_screen.dart` | `myAttendance`, `holidays` |
| Leave (My requests, Balance) | `lib/screens/leave_screen.dart` | `myLeaveRequests`, `myQuotas` |
| Apply for leave | `lib/screens/apply_leave_screen.dart` | `myQuotas`, `applyLeave` |
| Approvals (Pending, Decided) | `lib/screens/approvals_screen.dart` | `pendingApprovals`, `decidedApprovals`, `decideLeave` |
| Notifications | `lib/screens/notifications_screen.dart` | `notifications`, `markRead`, `markAllRead`; when a notification is tapped, also `pendingApprovals`, `decidedApprovals` and `myLeaveRequests` |
| Holidays | `lib/screens/holidays_screen.dart` | `holidays` |
| Profile | `lib/screens/profile_screen.dart` | `approvalAccess`, `myLedTeams` (through `approverKind()`) |

---

## 2. Theme and UI Styling

### 2.1 Where the theme lives

| File | Contents |
|---|---|
| `lib/theme/app_theme.dart` | `buildAppTheme()`: builds the one `ThemeData` for the whole app |
| `lib/theme/brand.dart` | `Brand` (logo asset path and aspect ratio) and `AppColors` (all colour constants) |
| `lib/theme/tokens.dart` | `Space` (spacing scale) and `Radii` (corner radii) |

The theme is applied once in `lib/main.dart`:

```dart
MaterialApp(theme: buildAppTheme(), ...)
```

### 2.2 `ThemeData` and `ColorScheme`

`buildAppTheme()`:

1. Creates a Material 3 `ColorScheme.fromSeed(seedColor: AppColors.red)`.
2. Pins key roles with `.copyWith(...)`: `primary` (brand red), `onPrimary` (white),
   `primaryContainer` and `secondaryContainer` (light red tint), `error`, `surface`,
   `onSurface` (dark text), `onSurfaceVariant` (grey), the `surfaceContainer*` greys,
   `outline` and `outlineVariant`.
3. Builds `ThemeData(useMaterial3: true, colorScheme: scheme)`.
4. Returns `base.copyWith(...)` with these component themes:

| Component | Theme key | What it sets |
|---|---|---|
| Text | `textTheme` | Dark text colour; heavier weights for headline and title styles |
| Icons | `iconTheme` | Grey icons |
| App bar | `appBarTheme` | White background, dark text, no tint or elevation |
| Cards | `cardTheme` | White, radius 16, thin grey border, very light shadow |
| List tiles | `listTileTheme` | Grey icons, padding |
| Buttons | `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme` | Red colours, 48 dp minimum height, radius 12 |
| Inputs | `inputDecorationTheme` | Filled white, radius 12, grey border, red border on focus |
| Bottom navigation | `navigationBarTheme` (and `bottomNavigationBarTheme`) | Red selected icon and label, light red indicator, grey when unselected |
| Tabs | `tabBarTheme` | Red label and indicator |
| Chips | `chipTheme` | Light red when selected |
| Dialogs and sheets | `dialogTheme`, `bottomSheetTheme` | White, radius 24, sheet drag handle on |
| Snackbars | `snackBarTheme` | Dark background, white text |
| Switches, progress | `switchTheme`, `progressIndicatorTheme` | Red |

### 2.3 Brand colours and status colours

All colour constants are in `AppColors` (`lib/theme/brand.dart`):

- **Brand:** `red` (#EC1B21), `grey` (#828282), `white`.
- **Neutrals:** `text`, `surfaceGrey`, `border`, `redTint`, `onRedTint`.
- **Status:** `approved` (green), `pending` (orange), `rejected` (red), `neutral` (grey).

`statusColor(String? status)` in `lib/widgets/common.dart` maps backend status strings to
these colours:

- `APPROVED` and `PRESENT` → green
- `REJECTED` and `ABSENT` → red
- `PENDING` and `IN_PROGRESS` → orange
- everything else → grey

### 2.4 Light and dark themes

**Only a light theme exists.** `MaterialApp` sets `theme:` and no `darkTheme:`, so the app
looks the same when the phone is in dark mode.

### 2.5 How to change common styling

| To change… | Edit |
|---|---|
| Primary/brand colour | `AppColors.red` in `lib/theme/brand.dart` (used as the seed and as `primary`) |
| Any other colour | The matching `AppColors` constant, or the `copyWith` roles in `buildAppTheme()` |
| Typography | The `textTheme:` block in `buildAppTheme()` |
| Buttons | `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme` in `buildAppTheme()` |
| Input fields | `inputDecorationTheme` in `buildAppTheme()` |
| Cards | `cardTheme` in `buildAppTheme()` (all `AppCard`s and plain `Card`s follow it) |
| Spacing / radii | `Space` and `Radii` in `lib/theme/tokens.dart` |
| Logo file | `Brand.logoAsset` in `lib/theme/brand.dart` (currently `assets/images/mytm_logo.png`) |

A few screens set a colour on one widget on purpose, but always from `AppColors` or the
`ColorScheme`, never as a hex value. Examples: the green Approve button in
`approvals_screen.dart`, and the status-coloured icons on Home and Attendance.

### 2.6 Reusable UI components

| Widget / function | File | Purpose |
|---|---|---|
| `AppCard` | `lib/widgets/app_card.dart` | The standard card (optional tap and padding) |
| `IconBubble` | `lib/widgets/app_card.dart` | Icon on a soft coloured circle |
| `LoadingSkeleton`, `LoadingSkeleton.list`, `SkeletonBox` | `lib/widgets/loading_skeleton.dart` | Pulsing loading placeholders |
| `InitialsAvatar` | `lib/widgets/initials_avatar.dart` | Round avatar with initials from a name or email |
| `DateBadge` | `lib/widgets/date_badge.dart` | Day number plus a weekday or month caption |
| `BrandLogo` | `lib/widgets/brand_logo.dart` | MYTM logo; shows "MYTM" text if the file is missing |
| `HomeHeader` | `lib/widgets/home_header.dart` | Home screen header (logo, bell, greeting, name) |
| `showTextInputDialog()` | `lib/widgets/text_input_dialog.dart` | One-field input dialog (approve/reject note, server address) |
| `showSnack()` | `lib/widgets/common.dart` | Shows a SnackBar (normal or error) |
| `StatusChip` | `lib/widgets/common.dart` | Coloured status pill |
| `EmptyState` | `lib/widgets/common.dart` | Empty-list icon and message |
| `ErrorState` | `lib/widgets/common.dart` | Error message with a "Try again" button |
| `AsyncBody<T>` | `lib/widgets/common.dart` | Shows a skeleton, then `ErrorState` or content for a `Future` |
| `SectionHeader` | `lib/widgets/common.dart` | Section title with an optional trailing widget |
| `InfoRow` | `lib/widgets/common.dart` | Label/value row; stacks the two when text is scaled up |

`lib/widgets/common.dart` also re-exports `app_card.dart`, `date_badge.dart`,
`initials_avatar.dart` and `loading_skeleton.dart`, so screens usually import only
`common.dart`.

Two shared pieces live in a screen file:

- `LeaveRequestCard` and `showLeaveDetails()` (the leave detail bottom sheet) are in
  `lib/screens/leave_screen.dart`. Both the Leave screen and the Approvals screen use them.
- `ApproverKind` and `approverKind()` are in `lib/screens/approvals_screen.dart`. Profile,
  Home and Notifications use them.

---

## 3. Application Structure

### 3.1 `lib/main.dart` — entry point and start-up

1. `main()` calls `WidgetsFlutterBinding.ensureInitialized()`.
2. `await Session.load()` reads SharedPreferences, creates `ApiClient` and `HrApi`, and
   restores a saved login if the token has not expired.
3. `runApp(EmployeeApp(session: session))`.

`EmployeeApp`:

- wraps the app in `AppScope` (an `InheritedNotifier<Session>`), so any widget can reach
  the session;
- builds `MaterialApp` with `buildAppTheme()` and a `navigatorKey`;
- sets `home:` to a `ListenableBuilder` on the session: `HomeShell` when signed in,
  `LoginScreen` when not;
- listens to the session; on sign-out it pops every pushed route
  (`popUntil(route.isFirst)`), so the login screen is not hidden behind other screens.

### 3.2 Folder structure

```
lib/
├── main.dart                 App entry point, MaterialApp, sign-in/out switching
├── config.dart               AppConfig: default base URL, /api/v1 prefix
├── session.dart              Session (sign-in state, token, base URL) and AppScope
├── models.dart               JSON model classes and parsing helpers
├── api/
│   ├── api_client.dart       ApiClient (HTTP, headers, errors) and ApiException
│   └── hr_api.dart           HrApi: one method per backend endpoint
├── screens/                  One file per screen (plus shared leave and approval helpers)
├── theme/
│   ├── app_theme.dart        buildAppTheme()
│   ├── brand.dart            Brand (logo) and AppColors
│   └── tokens.dart           Space and Radii
├── utils/
│   └── format.dart           Date, time, hours and text formatting helpers
└── widgets/                  Reusable widgets (see section 2.6)
assets/images/mytm_logo.png   Logo, declared in pubspec.yaml
test/                         models_test.dart, widget_test.dart
android/, ios/, web/          Platform projects
```

### 3.3 How the code is organised

- **Screens** (`lib/screens/`): `StatefulWidget`s that start their own API calls and keep
  the resulting `Future` in state.
- **Widgets** (`lib/widgets/`): stateless or small stateful UI pieces with no API calls.
- **Models** (`lib/models.dart`): plain classes with `fromJson` factories:
  - `CurrentUser`, `AuthResult`
  - `Attendance`, `Holiday`
  - `LeaveQuota`, `RequestQuota`
  - `LeaveRequest`, `LeaveWorkflow`, `WorkflowHistoryEntry`
  - `AppNotification`

  The file also has the `Json` typedef and the parsing helpers `parseDateTime`, `toInt`,
  `toDouble` and `toStr`. `parseDateTime` accepts both ISO strings and
  `[y, m, d, h, min, s]` arrays.
- **Services**: there is one service, `HrApi`, on top of `ApiClient`. There is no
  repository layer and no dependency-injection package.
- **Utilities** (`lib/utils/format.dart`):
  - `fmtDate`, `fmtShortDate`, `fmtTime`, `fmtDateTime`
  - `fmtMonth`, `fmtMonthShort`, `fmtWeekdayShort`
  - `fmtHours`, `fmtDateRange`
  - `isSameDay`, `humanize`

---

## 4. Navigation and Screens

### 4.1 Screens

| Screen | Class | File | Reached from |
|---|---|---|---|
| Login | `LoginScreen` | `login_screen.dart` | `MaterialApp.home` when signed out |
| Main shell with bottom bar | `HomeShell` | `home_shell.dart` | `MaterialApp.home` when signed in |
| Home | `DashboardScreen` | `dashboard_screen.dart` | Tab 0 |
| Attendance | `AttendanceScreen` | `attendance_screen.dart` | Tab 1; also the Home "Today" card |
| Leave (My requests, Balance) | `LeaveScreen` | `leave_screen.dart` | Tab 2; also Home "View all"; pushed from a notification |
| Profile | `ProfileScreen` | `profile_screen.dart` | Tab 3 |
| Apply for leave | `ApplyLeaveScreen` | `apply_leave_screen.dart` | Pushed from Home quick action or the Leave "Apply" button |
| Approvals (Pending, Decided) | `ApprovalsScreen` | `approvals_screen.dart` | Pushed from Profile, the Home card, or a notification |
| Notifications | `NotificationsScreen` | `notifications_screen.dart` | Pushed from the Home bell or Profile |
| Public holidays | `HolidaysScreen` | `holidays_screen.dart` | Pushed from Home quick action or Profile |
| Leave details | `showLeaveDetails()` (bottom sheet) | `leave_screen.dart` | Tapping a leave card; a notification for the user's own leave |

### 4.2 How navigation works

- **No named routes and no router package.** There is no `routes:`, `onGenerateRoute`,
  go_router or auto_route.
- **Sign-in switching** is done by `MaterialApp.home` rebuilding on `Session` changes (see
  section 3.1).
- **Bottom navigation**: `HomeShell` keeps `_index` and shows `pages[_index]` with a
  Material 3 `NavigationBar`. Pages are rebuilt every time the tab changes, so every tab
  reloads its data when opened. `Tabs.attendance` (1) and `Tabs.leave` (2) are the indexes
  Home uses to switch tabs through its `onOpenTab` callback.
- **Pushed screens**:
  `Navigator.of(context).push(MaterialPageRoute(builder: (_) => Screen()))`, with the
  default platform page transition. Some callers wait for the result:
  - Home's `_open` refreshes Home after the pushed screen closes.
  - `LeaveScreen._apply` refreshes when `ApplyLeaveScreen` pops `true`.
- **Dialogs**:
  - `showDialog` for the Sign out confirmation (`profile_screen.dart`).
  - `showTextInputDialog` for the approve/reject note and the server address.
  - `showDateRangePicker` for leave dates.
- **Bottom sheet**: `showModalBottomSheet` with a `DraggableScrollableSheet` in
  `showLeaveDetails()`.
- **Deep links from notifications** (`NotificationsScreen._openLeave`) choose a screen from
  the notification text (`notificationKind()`) and push `ApprovalsScreen` (with
  `initialTab` and `highlightId`) or `LeaveScreen` plus the detail sheet. These are
  **in-app links only**: there are no Android intent filters and no deep-link package, so
  links from outside the app are not handled.

### 4.3 Adding a new screen

1. Create `lib/screens/<name>_screen.dart` with a `StatefulWidget`, following an existing
   screen (for example, `holidays_screen.dart` is short).
2. Load data with `AppScope.read(context).api.<method>()` in `initState`, and show it with
   `AsyncBody`.
3. Connect it in one of three ways:
   - **Pushed screen:** call `Navigator.of(context).push(MaterialPageRoute(...))` from a
     button or tile, for example a new `_SettingsTile` in `profile_screen.dart` or a
     `_QuickAction` on Home.
   - **New bottom tab:** add the page to `pages` and a `NavigationDestination` in
     `home_shell.dart`, and update the `Tabs` constants if Home needs to jump to it.

---

## 5. Authentication and Session Management

### 5.1 Login flow

1. `LoginScreen._submit()` validates the form (email required and must contain `@`;
   password required).
2. It calls `AppScope.read(context).login(email, password)`, which is `Session.login`.
3. `Session.login` calls `HrApi.login` → `POST /api/v1/auth/login` with
   `{email, password}`. The email is trimmed.
4. The response is parsed by `AuthResult.fromJson`, which expects `token` and `user`
   (`id`, `email`, `role`, `roleName`, `permissions`).
5. The token is put on `ApiClient.token`, and the token and user are saved to
   SharedPreferences.
6. `notifyListeners()` makes `MaterialApp.home` switch to `HomeShell`.
7. If anything fails, the error text appears in a red box above the Sign in button
   (`_ErrorBanner`).

Password set and reset are **not** in the app. The login screen tells new users to use the
link in their welcome email, and Profile says to contact HR.

### 5.2 Where tokens and user data are stored

`shared_preferences`, through `Session` (`lib/session.dart`):

| Key | Value |
|---|---|
| `auth.token` | The JWT |
| `auth.user` | `CurrentUser.toJson()` as a JSON string |
| `server.baseUrl` | The server address chosen on the Login screen |

SharedPreferences is plain on-device storage. It is **not encrypted**; the app does not use
`flutter_secure_storage`.

### 5.3 Authenticated requests

After login, or after a session is restored, `ApiClient.token` is set and every request
carries `Authorization: Bearer <token>` (section 1.7). The backend finds the user from the
token; for example, `applyLeave` does not send an employee id.

### 5.4 Logout, token expiry and 401 handling

- **Manual logout**: Profile → "Sign out" → confirmation dialog → `Session.logout()`. This
  clears the in-memory token and user, removes `auth.token` and `auth.user`, and notifies
  listeners. There is **no logout API call**; the comment in `session.dart` says the
  backend has no logout or refresh endpoint.
- **Expiry at start-up**: `Session.load()` decodes the JWT payload (`_isExpired`) and
  checks the `exp` claim. An expired or unreadable token is cleared, and the user sees the
  login screen. A token without `exp` is treated as valid.
- **401 during use**: `ApiClient._send` calls `onUnauthorized`, which is `Session.logout`,
  when a request sent with a token returns 401. The user is signed out and returned to the
  login screen.
- **No token refresh** is implemented.
- `logout()` does not clear `server.baseUrl`, so the chosen server is kept.

### 5.5 Roles and approval access

`approverKind(Session)` in `approvals_screen.dart` decides whether the user sees an
approvals entry, and with which title:

| Result | Condition | Title |
|---|---|---|
| `superAdmin` | `role` or `roleName`, normalised, is `SUPERADMIN`. No API call is made. | "Admin approvals" |
| `hr` | `role` is `HR`, `ADMIN` or `SUPER_ADMIN`, and `GET /me/leave-approval-access` returns `{"available": true}` | "HR approvals" |
| `teamLead` | `GET /me/led-teams` returns a non-empty list | "Team approvals" |
| `null` | None of the above, or a call failed | No entry shown |

This result is computed again each time Profile, Home or Notifications needs it; it is
not cached.

---

## 6. State Management and Data Flow

### 6.1 Approach

There is **no state-management package** (no Provider, Riverpod, Bloc or GetX). The app
uses plain Flutter:

- **App-wide state:** `Session` is a `ChangeNotifier`, shared through `AppScope`
  (`InheritedNotifier`).
  - `AppScope.of(context)` reads the session and rebuilds the widget when it changes.
  - `AppScope.read(context)` reads it without rebuilding; use this in `initState` and in
    callbacks.
- **Screen state:** each screen is a `StatefulWidget` that keeps a `Future<...>` (for
  example `_future`, `_requests`, `_pending`) and calls `setState` to replace it.

### 6.2 Data flow

1. A screen calls an `HrApi` method and stores the returned `Future`.
2. `AsyncBody<T>` (`lib/widgets/common.dart`) wraps a `FutureBuilder`:
   - while waiting: the screen's `skeleton`, or `LoadingSkeleton.list()`;
   - on error: `ErrorState(message: error.toString(), onRetry: ...)`;
   - on success: `builder(context, data)`, faded in once over 200 ms.
3. Data goes down to child widgets through constructors (for example `LeaveRequestCard`
   gets a `LeaveRequest`). Screens do not share loaded data with each other; each one
   fetches its own.
4. Results come back up through `Navigator` pop values (for example `ApplyLeaveScreen`
   pops `true`) and callbacks (for example Home's `onOpenTab`).

### 6.3 Loading, error and refresh

| Mechanism | Where |
|---|---|
| Skeleton loaders | `AsyncBody(skeleton: ...)` on every list screen; Home uses `_HomeSkeleton` |
| Error with retry | `ErrorState` through `AsyncBody` |
| Empty lists | `EmptyState` with a message for each screen |
| Pull-to-refresh | `RefreshIndicator` on Home, Attendance, Leave tabs, Approvals tabs, Notifications |
| Refresh after an action | Approvals refreshes both tabs after a decision; Notifications refreshes after marking read; Home refreshes after a pushed screen closes; Leave refreshes after a new request |
| Partial failures on Home | `DashboardScreen._load` runs each call separately with `catchError`; only the attendance error is shown ("Could not load attendance") and the others are logged with `debugPrint` |

---

## 7. System Messages and Error Handling

### 7.1 Where messages come from

| Type | Where |
|---|---|
| SnackBars | `showSnack(context, message, {error})` in `lib/widgets/common.dart`; it hides any current SnackBar first, and `error: true` uses the error colour |
| Success SnackBars | "Leave request submitted…" (`apply_leave_screen.dart`); "Leave approved." / "Leave rejected." (`approvals_screen.dart`) |
| Error SnackBars | API errors on apply, approve/reject and mark read; deep-link messages in `notifications_screen.dart` |
| Inline errors | Login failure (`_ErrorBanner` in `login_screen.dart`); load failures (`ErrorState`) |
| Validation messages | `validator:` on form fields: login (email/password), apply leave (type, dates), reject dialog ("Please tell the employee why") |
| Dialogs | Sign out confirmation (`profile_screen.dart`), `showTextInputDialog` |
| Warnings | "No balance left" (`apply_leave_screen.dart`); over-balance warning on approval cards and the detail sheet (`leave_screen.dart`) |
| Toasts | **Not used.** There is no toast package. |

### 7.2 How backend errors reach the user

1. The backend returns a non-2xx response with a JSON body containing `message`.
2. `ApiClient._send` throws `ApiException(message)` (or a fallback message, section 1.8).
3. The screen either:
   - lets the error reach `AsyncBody`, which shows `ErrorState` with the message; or
   - catches it and calls `showSnack(context, e.toString(), error: true)`.

   Approvals also catches `ApiException` on its own: a 409 response may mean the backend
   already rejected the request.
4. `approvals_screen.dart` `_friendly()` logs the real error and replaces non-API errors
   (for example an unexpected JSON shape) with "Could not load … Please try again."

### 7.3 Centralised utilities

- `ApiException` and `_fallbackMessage`: `lib/api/api_client.dart`
- `showSnack`, `ErrorState`, `EmptyState`, `AsyncBody`: `lib/widgets/common.dart`

There is **no localisation setup** (no `intl` ARB files or `AppLocalizations`). All
user-facing text is hardcoded in English in the Dart files.

---

## 8. Configuration and Environment

### 8.1 `--dart-define` values

| Name | Read in | Used for |
|---|---|---|
| `API_BASE_URL` | `lib/config.dart` (`String.fromEnvironment`) | Default server address |

No other `--dart-define`, `.env` file or flavor setup is used.

### 8.2 Development vs production

There are **no separate build flavors or environment files**. The server is chosen by:

1. the URL saved on the device from the Login screen;
2. otherwise `--dart-define=API_BASE_URL=...` given at build time;
3. otherwise `http://10.0.2.2:8080` on Android, or `http://localhost:8080` elsewhere.

The deployed server's address is **not** hardcoded in the source. To point a build at it,
pass it with `--dart-define`, or enter it in the Login screen's Server address dialog.

### 8.3 Android networking settings

- `android/app/src/main/AndroidManifest.xml`:
  - `<uses-permission android:name="android.permission.INTERNET"/>`
  - `android:usesCleartextTraffic="true"` on `<application>`, which allows plain `http://`
    servers.
- There is no `network_security_config.xml` (`android/app/src/main/res/xml/` does not
  exist).
- `android/app/build.gradle`: `applicationId` and `namespace` are
  `com.example.hr_employee_app`. The SDK versions come from Flutter. Java and Kotlin
  target 17.

### 8.4 Dependencies (`pubspec.yaml`)

- `http`
- `intl`
- `shared_preferences`
- dev only: `flutter_test`, `flutter_lints`

Assets: `assets/images/`.

No secrets, API keys or credentials are stored in the repository code.

---

## 9. Backend Integration Map

All paths below are relative to `<baseUrl>/api/v1`. Every row was checked against
`lib/api/hr_api.dart` and the screens that call it.

| Feature or screen | Flutter screen/file | API service/file | API endpoint(s) | HTTP method | Purpose |
|---|---|---|---|---|---|
| Login | `screens/login_screen.dart` → `session.dart` | `HrApi.login` (`api/hr_api.dart`) | `/auth/login` | POST | Exchange email and password for a JWT and user |
| Home — today and month stats | `screens/dashboard_screen.dart` | `HrApi.myAttendance` | `/me/attendance-records` | GET | Full attendance history; today and this month are picked out on the device |
| Home — leave balance | `screens/dashboard_screen.dart` | `HrApi.myQuotas` | `/me/leave-quotas/year/{year}` | GET | Current year's leave balances |
| Home — approvals card | `screens/dashboard_screen.dart` | `HrApi.pendingApprovals` | `/leave-requests/pending` | GET | Count of requests waiting for the user (approvers only) |
| Home — notification badge | `screens/dashboard_screen.dart` | `HrApi.unreadCount` | `/me/notifications/unread-count` | GET | Unread count (`unread` field) |
| Home — upcoming holidays | `screens/dashboard_screen.dart` | `HrApi.holidays` | `/holidays` | GET | Holiday list, filtered on the device |
| Approver detection (Home, Profile, Notifications) | `approverKind()` in `screens/approvals_screen.dart` | `HrApi.approvalAccess` | `/me/leave-approval-access` | GET | `{"available": true/false}` |
| Approver detection | `approverKind()` in `screens/approvals_screen.dart` | `HrApi.myLedTeams` | `/me/led-teams` | GET | Teams the user leads (list or `{content: [...]}`) |
| Attendance | `screens/attendance_screen.dart` | `HrApi.myAttendance`, `HrApi.holidays` | `/me/attendance-records`, `/holidays` | GET | Month-by-month attendance with holidays marked |
| Leave — My requests | `screens/leave_screen.dart` | `HrApi.myLeaveRequests` | `/me/leave-requests` | GET | The user's own leave requests |
| Leave — Balance | `screens/leave_screen.dart` | `HrApi.myQuotas` | `/me/leave-quotas/year/{year}` | GET | Leave balances for the year |
| Apply for leave — types | `screens/apply_leave_screen.dart` | `HrApi.myQuotas` | `/me/leave-quotas/year/{year}` | GET | Leave types the user can request (from their quotas) |
| Apply for leave — submit | `screens/apply_leave_screen.dart` | `HrApi.applyLeave` | `/leave-requests` | POST | Create a leave request |
| Approvals — Pending | `screens/approvals_screen.dart` | `HrApi.pendingApprovals` | `/leave-requests/pending` | GET | Requests waiting for the user's decision |
| Approvals — Decided | `screens/approvals_screen.dart` | `HrApi.decidedApprovals` | `/leave-requests/decided` | GET | Requests the user has decided (first page only; no page or size is sent) |
| Approvals — Approve/Reject | `screens/approvals_screen.dart` | `HrApi.decideLeave` | `/leave-requests/{id}/decision` | POST | Approve or reject, with an optional note |
| Notifications — list | `screens/notifications_screen.dart` | `HrApi.notifications` | `/me/notifications` | GET | The user's notifications |
| Notifications — mark one read | `screens/notifications_screen.dart` | `HrApi.markRead` | `/notifications/{id}/read` | PUT | Mark a notification read |
| Notifications — mark all read | `screens/notifications_screen.dart` | `HrApi.markAllRead` | `/me/notifications/read-all` | PUT | Mark all notifications read |
| Notifications — open a leave | `screens/notifications_screen.dart` | `HrApi.pendingApprovals`, `decidedApprovals`, `myLeaveRequests` | `/leave-requests/pending`, `/leave-requests/decided`, `/me/leave-requests` | GET | Find the notification's request in the user's lists (the HR-only `/leave-requests/{id}` is not called) |
| Holidays | `screens/holidays_screen.dart` | `HrApi.holidays` | `/holidays` | GET | Current year's public holidays |
| Profile | `screens/profile_screen.dart` | — (through `approverKind()`) | `/me/leave-approval-access`, `/me/led-teams` | GET | Decide whether to show the approvals entry |
| Logout | `screens/profile_screen.dart` → `session.dart` | none | none | — | Local only; no backend call |

**Not found in the code:** check-in or check-out, password reset, token refresh, a logout
endpoint, account or profile details (`/me/account`), and any DELETE or PATCH requests.

---

## 10. Safe Change Guide

These are the files to look at first. Nothing here has been changed.

### Change the API base URL

- `lib/config.dart` — `AppConfig.defaultBaseUrl` (the defaults) and `apiPrefix`.
- Or, without code changes: `flutter run --dart-define=API_BASE_URL=http://host:port`.
- Remember that a URL saved on the device (`server.baseUrl` in `lib/session.dart`, set
  from the Login screen) wins over both.
- For `http://` servers on Android, `android:usesCleartextTraffic` in
  `android/app/src/main/AndroidManifest.xml` must stay `true`.

### Change the theme or brand colours

- `lib/theme/brand.dart` — `AppColors` and `Brand.logoAsset`.
- `lib/theme/app_theme.dart` — `buildAppTheme()` for component styles and typography.
- `lib/theme/tokens.dart` — spacing and radii.
- `lib/widgets/common.dart` — `statusColor()` for status colours.

### Modify a screen's UI

- The screen's own file in `lib/screens/` (see the table in section 4.1).
- The shared widgets it uses in `lib/widgets/`.
- Leave and approval cards and the detail sheet: `LeaveRequestCard` and
  `showLeaveDetails()` in `lib/screens/leave_screen.dart`. Changes there affect both the
  Leave and Approvals screens.

### Add a new API integration

1. If a new response shape is needed, add a model with `fromJson` in `lib/models.dart`.
2. Add a method to `HrApi` in `lib/api/hr_api.dart` that calls `client.get/post/put` with
   a path **without** `/api/v1`.
3. If a new HTTP method is needed (for example DELETE), add it to `ApiClient` in
   `lib/api/api_client.dart` the same way as `put`.
4. Call it from a screen through `AppScope.read(context).api.<method>()`, and show it with
   `AsyncBody`.

### Change authentication behaviour

- `lib/session.dart` — `Session.login`, `logout`, `load`, `_isExpired`, and the storage
  keys.
- `lib/api/api_client.dart` — the `Authorization` header (`_headers`) and the 401 handling
  in `_send`.
- `lib/api/hr_api.dart` — `HrApi.login` and the request body.
- `lib/models.dart` — `AuthResult` and `CurrentUser`.
- `lib/screens/login_screen.dart` — login form and validation.
- `lib/main.dart` — signed-in/signed-out switching and popping routes on logout.

### Update system messages

- `lib/api/api_client.dart` — network, timeout and HTTP-status fallback messages.
- `lib/widgets/common.dart` — `showSnack` look; `ErrorState` and `EmptyState` layout.
- The string in the screen file that shows it. Search `lib/screens/` for `showSnack(`,
  `validator:` and `EmptyState(`.
- **Do not edit** the phrases `'requested'`, `'was approved'` and `'was rejected'` in
  `notificationKind()` (`lib/screens/notifications_screen.dart`). They are not shown to
  users; they match backend notification text so that tapping a notification opens the
  right screen.

### Add a new screen

- Create a file in `lib/screens/`, and link to it from:
  - a pushed route, for example in `profile_screen.dart` or `dashboard_screen.dart`; or
  - a new tab in `lib/screens/home_shell.dart` (`pages`, `NavigationDestination`,
    `Tabs`).
- Use `AsyncBody`, `AppCard`, `SectionHeader`, `EmptyState` and the other widgets from
  `lib/widgets/common.dart` so it matches the rest of the app.
