# Login Photo Verification — Admin handoff (mirror)

Canonical handoff for the Admin team lives in the Admin repo:

`../MGgo(DPD)-ADMIN/MGgo-Admin/docs/LOGIN_VERIFICATION_HANDOFF.md`

Summary for Driver App developers:

| Layer | Location |
|-------|----------|
| Image bytes | R2 `drivers/{driverId}/login_verification/{UTC-date}/{uuid}.{ext}` |
| Upload audit | `storage_uploads` via `/api/driver-uploads/*` |
| Domain audit | Supabase `driver_login_verifications` via RPC `driver_record_login_verification` (`p_object_key`, soft `p_liveness_passed` / `p_liveness_method`) |
| Local queue | SQLite `pending_login_verifications` (+ `liveness_passed` / `liveness_method`) until upload+RPC succeed |
| Liveness | On-device blink (`mlkit_blink`) before still capture; Home blocked until success |

**Not** stored in attendance tables. Admin viewer: `/drivers/[id]` → **Login Verification** tab (liveness badge) in `MGgo-Admin` (see Admin `docs/LOGIN_VERIFICATION_HANDOFF.md`).
