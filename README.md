# HR Employee App (Flutter)

Employee self-service app for the HR Attendance System backend in this repo.
Admin/HR features are intentionally not included.

## Features

| Screen | Backend endpoint(s) |
|---|---|
| Login | `POST /api/v1/auth/login` |
| Set password (from HR's reset link) | `POST /api/v1/auth/reset-password` |
| Home: today's punch, month stats, leave balance, upcoming holidays | `/attendance/me`, `/leave-quotas/me/year/{y}`, `/holidays`, `/notifications/me/unread-count`, `/leave-requests/pending` |
| My attendance (month by month) | `GET /attendance/me` |
| Leave balance | `GET /leave-quotas/me/year/{y}` |
| Apply for leave | `POST /leave-requests` |
| My leave requests + approval progress | `GET /leave-requests/me` |
| Team approvals (team leads) | `GET /leave-requests/pending`, `POST /leave-requests/{id}/decision` |
| Notifications | `/notifications/me`, `PUT /notifications/{id}/read`, `PUT /notifications/me/read-all` |
| Public holidays | `GET /holidays` |

## Run

```bash
cd employee_app
flutter pub get
flutter run
```

### Server address

Defaults: `http://10.0.2.2:8080` on the Android emulator, `http://localhost:8080` everywhere else.

- On a real phone, use your computer's LAN IP (e.g. `http://192.168.1.10:8080`). Phone and
  computer must be on the same Wi-Fi.
- Change it in the app (server icon on the login screen), or at build time:
  `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080`

The backend must be running (`./mvnw spring-boot:run` from the repo root).

## Notes

- The leave-type dropdown is built from the employee's own leave quotas, because
  `/leave-types` is back-office only. A leave type with no quota assigned to the employee
  will not appear.
- There is no self check-in: attendance is recorded by HR or the biometric import.
- Plain `http://` is allowed in `AndroidManifest.xml` (`usesCleartextTraffic`) and
  `ios/Runner/Info.plist` (`NSAllowsArbitraryLoads`) for local development. Switch to HTTPS
  and remove those before a production release.
