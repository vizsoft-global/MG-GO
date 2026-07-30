# Login Photo Verification — Admin handoff (mirror)

Canonical handoff for the Admin team lives in the Admin repo:

`../MGgo(DPD)-ADMIN/MGgo-Admin/docs/LOGIN_VERIFICATION_HANDOFF.md`

Summary for Driver App developers:

| Layer | Location |
|-------|----------|
| Image bytes | R2 `drivers/{driverId}/login_verification/{UTC-date}/{uuid}.{ext}` |
| Upload audit | `storage_uploads` via `/api/driver-uploads/*` |
| Domain audit | Supabase `driver_login_verifications` via RPC `driver_record_login_verification` |
| Local queue | SQLite `pending_login_verifications` until upload+RPC succeed |

**Not** stored in attendance tables. Admin viewer: `/drivers/[id]` → **Login Verification** tab in `MGgo-Admin` (see Admin `docs/LOGIN_VERIFICATION_HANDOFF.md`).
