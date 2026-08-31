# HandyGo Admin Read-Only API

This is the approved machine-to-machine surface for Anzal's operations integration. It is separate from normal Admin JWT access and is restricted to an explicit GET allowlist.

> **READ ONLY — no create/update/delete permissions.**

## Connection details

- Production base URL: `https://handygo-production-jqi9i.ondigitalocean.app/api/v1/admin-readonly`
- Authentication: dedicated expiring machine API key
- Header: `Authorization: Bearer <ADMIN_READONLY_API_KEY>`
- Content type: JSON
- Default rate limit: 120 authenticated requests per minute per credential; excess requests return HTTP 429

Do not use an Admin user's access/refresh JWT, a database login, or any DigitalOcean/Postgres credential. The raw API key must live only in the approved secret manager and Anzal's approved client configuration. Source code and Git contain only configuration placeholders.

## Required scopes

| Scope                    | Approved GET resources                      |
| ------------------------ | ------------------------------------------- |
| `admin.stats.read`       | Dashboard counters                          |
| `admin.bookings.read`    | Booking list and booking detail             |
| `admin.settlements.read` | Settlement cases and commission collections |
| `admin.workers.read`     | Sanitized worker list and detail            |
| `admin.clients.read`     | Sanitized client list and detail            |
| `admin.complaints.read`  | Sanitized complaint list and detail         |

There is no notification scope because the current notification API is user-owned rather than an Admin/Ops read surface. OTP diagnostics, worker/client agreements, CNIC/selfie/document downloads, and every mutation are excluded.

## Available endpoints

All routes below accept GET only. Existing query DTO validation and the maximum `pageSize` of 100 remain in effect.

| Endpoint                         | Scope                    |
| -------------------------------- | ------------------------ |
| `GET /stats`                     | `admin.stats.read`       |
| `GET /bookings`                  | `admin.bookings.read`    |
| `GET /bookings/{bookingId}`      | `admin.bookings.read`    |
| `GET /settlement-cases`          | `admin.settlements.read` |
| `GET /settlement-cases/{caseId}` | `admin.settlements.read` |
| `GET /commission-collections`    | `admin.settlements.read` |
| `GET /workers`                   | `admin.workers.read`     |
| `GET /workers/{workerProfileId}` | `admin.workers.read`     |
| `GET /clients`                   | `admin.clients.read`     |
| `GET /clients/{clientProfileId}` | `admin.clients.read`     |
| `GET /complaints`                | `admin.complaints.read`  |
| `GET /complaints/{complaintId}`  | `admin.complaints.read`  |

Examples of supported filters include `page`, `pageSize`, `status`, and the filters already accepted by each corresponding Admin list DTO. A credential receives HTTP 403 when its configured scopes do not include the endpoint's required scope.

## Example request

```bash
curl --request GET \
  'https://handygo-production-jqi9i.ondigitalocean.app/api/v1/admin-readonly/bookings?page=1&pageSize=20&status=COMPLETED' \
  --header 'Authorization: Bearer <ADMIN_READONLY_API_KEY>' \
  --header 'Accept: application/json'
```

Example response shape:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "<booking-id>",
        "clientProfileId": "<client-profile-id>",
        "workerProfileId": "<worker-profile-id>",
        "category": { "id": "<category-id>", "name": "Plumbing" },
        "status": "COMPLETED",
        "lane": "STANDARD",
        "finalPrice": 5000,
        "paymentStatus": "COMPLETED",
        "commissionStatus": "PAID",
        "settlements": []
      }
    ],
    "total": 1,
    "page": 1,
    "pageSize": 20
  },
  "message": ""
}
```

Authentication failures return HTTP 401, missing scopes return HTTP 403, and rate-limit excess returns HTTP 429. Standard HandyGo error responses remain:

```json
{
  "success": false,
  "error": "Unauthorized",
  "message": "Invalid read-only API credential",
  "statusCode": 401,
  "timestamp": "<iso-timestamp>",
  "path": "/api/v1/admin-readonly/bookings"
}
```

## Data protection

Responses are reconstructed from explicit field allowlists. They do not expose password hashes, refresh/access tokens, FCM tokens, OTPs, phone numbers, email addresses, avatars, CNIC values/images, selfies, worker documents, storage URLs/keys, residential or booking addresses, latitude/longitude, customer descriptions, complaint free text, settlement notes, contact notes, actor phone numbers, raw event metadata, or notification records.

Every authenticated request is logged with the credential client ID, HTTP method, path, source IP, and duration. Authorization headers, raw keys, query values, and response data are not logged by this layer.

## Issue, rotate, expire, and revoke

An authorized backend operator performs credential setup; Anzal must never receive deployment access.

1. Generate a cryptographically random key of at least 32 bytes outside the repository.
2. Put the raw key in the approved secret manager and provide it to Anzal through the approved secure channel.
3. Compute the lowercase SHA-256 hex digest of the raw key. Store only that digest as `ADMIN_READONLY_API_KEY_SHA256` in the backend deployment environment.
4. Set `ADMIN_READONLY_CLIENT_ID=anzal-ops`.
5. Set `ADMIN_READONLY_SCOPES` to the approved comma-separated subset, for example `admin.stats.read,admin.bookings.read,admin.settlements.read,admin.complaints.read`.
6. Set an ISO-8601 UTC expiry such as `ADMIN_READONLY_EXPIRES_AT=<approved-expiry>`.
7. Optionally set `ADMIN_READONLY_RATE_LIMIT_PER_MINUTE`; the safe default is 120.
8. Deploy/restart the backend, then verify one allowed GET and one disallowed scope before releasing the raw key.

To rotate, generate a new key, replace the digest and secret-manager value, deploy, and then delete the old secret. To revoke immediately, unset or replace `ADMIN_READONLY_API_KEY_SHA256` and deploy/restart. Expired credentials are rejected automatically even if the digest remains configured.

## Existing Admin API audit

The existing code already has read handlers for Admin stats; workers, pending workers, worker detail and private documents/agreements; clients and agreements; OTP activity; bookings; settlement cases; commission collections; and support complaints. Those controllers use `JwtAuthGuard` plus `RolesGuard(Role.ADMIN)`. The same normal Admin JWT can also reach PATCH/POST mutations, so it is not approved as Anzal's reusable machine credential.

No pre-existing scoped service token, read-only API key, API gateway policy, or internal proxy pattern was found. The `/admin-readonly` controller therefore reuses the authoritative read service methods while providing separate authentication, explicit scopes, field sanitization, auditing, and rate limiting. It does not change booking transitions, settlement calculations, commissions, matching, payment, chat, or notification behavior.
