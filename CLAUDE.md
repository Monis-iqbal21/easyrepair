# EasyRepair — Claude Code Context

## 🎨 Design System

**Never write a colour into a widget. There is exactly one place colours are
decided:** `easyrepair_app/lib/core/theme/app_semantic_colors.dart`.

```dart
final c = context.semanticColors;
Container(
  color: c.surface,
  child: Text('…', style: TextStyle(color: c.textPrimary)),
)
```

`Color(0xFF…)`, `Colors.white`, `Colors.black`, `const _kAccent = …` at the top
of a page — none of these belong in a widget. `AppTheme` builds its
`ColorScheme` *from* the same palette, so Material's own defaults (buttons,
inputs, switches, dividers, snackbars, progress indicators) land on the same
values. If a theme already decides a colour, do not restate it on the widget.

### The tokens

`background` · `surface` · `surfaceSubtle` · `textPrimary` · `textSecondary` ·
`onPrimary` · `onPrimaryMuted` · `border` · `controlBorder` · `primary` ·
`primaryPressed` · `softTeal` · `urgent` · `urgentSoft` · `success` ·
`successSoft` · `warning` · `warningSurface` · `error`

Each has a light and a dark value under one name, so a widget never branches on
brightness. `urgent` is the attention accent and is deliberately **not** `error`
— urgent is not a failure.

**Need a colour that has no token?** Stop. Add it to `app_semantic_colors.dart`
in *both* palettes under one name, then use the name. Never derive one with
`withValues(alpha: …)` — a colour comes from the palette or it does not exist.

### Brand

HandyGo's brand colour is **teal `#11645D`**. The orange `#DB6234` that used to
be documented here was EasyRepair's, is not in the Ustaad prototype at all, and
is being removed screen by screen — do not reintroduce it.

### Shape

The design source of truth is the Ustaad prototype at
`06 Handover to Monis/05 Design & UI/prototype/` (outside this repo).

- **No shadows inside a screen.** A card is `surface` + `radius 16` + a 1px
  `c.border` hairline. Nothing else.
- Radius: card **16** · button **14** · chip, pill and avatar **999**.
- Type: nothing heavier than **w700**. Smallest meaningful text **12.5px**, body
  **14px**, card titles **16–18px**. These users read outdoors, often in
  sunlight — 10px labels are not acceptable.
- Minimum heights: primary button **52** · tappable row **56** · nav item and
  filter chip **44**.
- Uppercase labels are for `en` only. Urdu has no letter case, and `ur_Latn` in
  caps reads as shouting.

### Fonts

The prototype is drawn in **Figtree**; the app currently ships no custom font at
all (`fontFamily` appears zero times in `lib/`, and `pubspec.yaml` has no
`fonts:`). Until that is decided, **no screen can fully match the prototype**,
however correct its colour and spacing are. Say so when reporting a screen done.


## Project Overview
EasyRepair is an on-demand home repair & maintenance platform. Clients post service requests and nearby Workers (technicians, plumbers, electricians, etc.) accept and fulfill them.

**Current Phase:** Flutter mobile app (Client + Worker) + NestJS backend only.  
Web/Admin panel (Next.js) is deferred to Phase 2 — do not scaffold or reference it.

---

## Monorepo Structure
```
easyrepair/
├── easyrepair_app/   # Flutter app (shared codebase, client + worker flavors)
└── backend/          # NestJS API server
```

---

## Tech Stack

### Mobile (Flutter)
- **Language:** Dart
- **State Management:** Riverpod
- **Navigation:** GoRouter
- **HTTP Client:** Dio (with JWT interceptor + auto refresh)
- **WebSocket:** Socket.IO client
- **Local Storage:**
  - flutter_secure_storage → tokens
  - shared_preferences → settings
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Maps:** google_maps_flutter
- **Location:**
  - geolocator (foreground)
  - background tracking solution (to be finalized after testing)
- **Image Handling:** image_picker + flutter_image_compress
- **Dependency Injection:** GetIt (ONLY for global singletons)
- **Architecture:** Feature-first + Clean Architecture
- **Flavors:** client / worker (via `--dart-define=FLAVOR=client|worker`)

---

### Backend (NestJS)
- **Language:** TypeScript
- **Framework:** NestJS
- **ORM / DB Access:**
  - Prisma → standard models
  - Raw SQL → PostGIS queries (`$queryRaw`)
- **Database:** PostgreSQL with PostGIS
- **Cache & Queues:** Redis (ioredis + BullMQ)
- **WebSocket:** Socket.IO via `@nestjs/websockets`
- **Authentication:**
  - JWT (access: 15m, refresh: 30d)
  - OTP via SMS
- **Push Notifications:** Firebase Admin SDK
- **File Storage:** S3-compatible (AWS S3 / Cloudflare R2)
- **Validation:** class-validator + class-transformer
- **Config:** @nestjs/config (.env)

---

### Hosting (MVP)
- **Backend + DB + Redis:** Railway
- **Database Note:** Must use a PostgreSQL instance with PostGIS support (Railway PostGIS template or compatible provider)
- **Flutter Apps:** Play Store / App Store

---

## User Roles
| Role | Description |
|------|-------------|
| CLIENT | Books repair services |
| WORKER | Accepts and fulfills bookings |
| ADMIN | Phase 2 only (do not implement now) |

---

# ==============================
# FLUTTER APP RULES
# ==============================

## Flavor Detection
```dart
const flavor = String.fromEnvironment('FLAVOR'); // 'client' or 'worker'
```
- NEVER hardcode role
- Always control UI/features via flavor

## Architecture (MANDATORY)

Each feature MUST follow:
```
features/
└── feature_name/
    ├── data/
    │   ├── datasources/
    │   ├── models/
    │   └── repositories/
    ├── domain/
    │   ├── entities/
    │   ├── repositories/
    │   └── usecases/
    └── presentation/
        ├── pages/
        ├── widgets/
        └── providers/
```

## Dio Rules
- Base URL from `AppConfig.apiBaseUrl`
- Use interceptors:
  - `AuthInterceptor` → attach token + refresh
  - `ErrorInterceptor` → convert errors → Failure
- NEVER use `http` package

## WebSocket Rules
- Single `SocketService` (GetIt singleton)
- Connect on login
- Disconnect on logout
- Auto reconnect with exponential backoff
- Event constants must be stored in:
```
core/constants/socket_events.dart
```

## Navigation (GoRouter)
- Role-based redirect guards
- Rules:
  - Unauthenticated → `/auth/login`
  - Worker not verified → `/worker/verification-pending`
  - Support deep links from FCM

## Error Handling
- Use `Either<Failure, T>` (fpdart)
- NEVER throw raw exceptions from repositories
- UI behavior:
  - Form errors → inline
  - API errors → SnackBar
  - Critical → full error screen

## Storage Rules
- Tokens → `flutter_secure_storage` ONLY
- Settings → `shared_preferences`
- NEVER store tokens in `shared_preferences`

---

# ==============================
# BACKEND RULES
# ==============================

## Module Structure
```
modules/feature/
├── feature.module.ts
├── feature.controller.ts
├── feature.service.ts
├── feature.gateway.ts       # if needed
├── dto/
├── entities/
└── feature.repository.ts    # Prisma only here
```

## Prisma Rules
- NEVER call Prisma directly in services
- Always go through repository
- Use transactions for multi-table operations
- PostGIS → use `$queryRaw`

## Auth Rules
- `JwtAuthGuard` for protected routes
- Role-based:
  - `@Roles('CLIENT')`
  - `@Roles('WORKER')`
- Booking-specific:
  - `BookingOwnerGuard`

## API Response Format

**Success**
```json
{ "success": true, "data": {}, "message": "" }
```

**Error**
```json
{
  "success": false,
  "error": "string",
  "message": "string",
  "statusCode": 0,
  "timestamp": "string",
  "path": "string"
}
```

## WebSocket Gateways
| Gateway | Namespace | Purpose |
|---|---|---|
| BookingGateway | `/bookings` | job requests + status |
| ChatGateway | `/chat` | messaging |
| WorkerGateway | `/workers` | location + online |

- Auth via: `socket.handshake.auth.token`
- Room patterns:
```
booking:{bookingId}
user:{userId}
```

## Redis Patterns
```
worker:location:{workerId} → { lat, lng }  TTL: 30s
worker:online:{workerId}   → "1"           TTL: 30s
otp:{phone}                → { code }      TTL: 5m
booking:request:{id}       → { workerId }  TTL: 60s
```

## BullMQ Queues
| Queue | Purpose |
|---|---|
| notifications | FCM push |
| otp | SMS sending |
| payouts | payments |

- Processors: `modules/{feature}/{feature}.processor.ts`

---

# ==============================
# DATABASE RULES
# ==============================

## Booking Status Flow
```
PENDING → ACCEPTED → EN_ROUTE → IN_PROGRESS → COMPLETED
PENDING → REJECTED
PENDING → CANCELLED
ACCEPTED → CANCELLED
IN_PROGRESS → CANCELLED
```
- Validate transitions in service
- Invalid → throw error
- Always emit:
  - WebSocket event
  - FCM push (queued)

## PostGIS Worker Matching
```sql
SELECT wp.*, ST_Distance(wp.location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) AS distance_meters
FROM worker_profiles wp
WHERE wp.is_online = TRUE
  AND wp.status = 'ACTIVE'
  AND ST_DWithin(wp.location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
ORDER BY distance_meters ASC;
```
- `$1` → lng
- `$2` → lat
- `$3` → radius (meters)

---

# ==============================
# JOB ASSIGNMENT FLOW
# ==============================

1. Client creates booking → `PENDING`
2. Find nearby workers (PostGIS)
3. Send request to first worker
4. Set Redis TTL (60s)
5. If accepted → stop
6. Else → next worker
7. If none → notify client

---

# ==============================
# ENV CONFIG
# ==============================

## Backend `.env`
```env
PORT=3000
DATABASE_URL=
REDIS_URL=
JWT_SECRET=
JWT_ACCESS_EXPIRES=15m
JWT_REFRESH_EXPIRES=30d
FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=
SMS_API_KEY=
STORAGE_PROVIDER=s3
AWS_BUCKET=
AWS_REGION=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
```

> Commission is **not** an env var. It is a fixed **18% of labour actually
> received** — never parts, never the inspection fee — and lives only in
> `PLATFORM_COMMISSION_RATE` (`backend/src/common/utils/commission.util.ts`).
> The old `PLATFORM_FEE_PERCENT=10` was dead config and has been removed.

## Flutter (dart-define)
```
API_BASE_URL=
WS_URL=
FLAVOR=client
GOOGLE_MAPS_API_KEY=
```

---

# ==============================
# WHAT NOT TO DO
# ==============================

- ❌ Do NOT scaffold Next.js (Phase 2)
- ❌ Do NOT build ADMIN flow now
- ❌ Do NOT use `http` package
- ❌ Do NOT call Prisma in services
- ❌ Do NOT hardcode URLs
- ❌ Do NOT store tokens in `shared_preferences`
- ❌ Do NOT send FCM synchronously
- ❌ Do NOT allow invalid booking transitions
