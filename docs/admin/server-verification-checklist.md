# Server verification checklist (driver app client assumptions)

The Flutter driver app relies on the following backend behaviors. Verify in Supabase / admin before production rollout.

## `driver_release_device_session`

- Must release **only** when `p_device_id` matches the driver's current `active_device_id`.
- A late sign-out on device A after device B took over must **not** clear device B's session.

## `driver_log_security_event`

- Must accept `p_event_type = zone_timeout_checkout` (severity `warning`).
- Context payload includes: `mode` (`idle` | `return_grace`), `window_seconds`, coordinates, `zone_status`, `outside_since`.

## Single-device session / `flush_grace_active`

- `driver_heartbeat` should return `flush_grace_active: true` for ~5 minutes after another device overrides login.
- Client now defers metadata-only kicks to heartbeat (no immediate sign-out without grace).
- `driver_finalize_reconciliation` should accept flushed pickup/completion rows during grace.

## Pickup / completion RPC idempotency

- `driver_complete_delivery` / `driver_cancel_delivery` should be safe to retry when the client lost the HTTP response (return a stable “already completed” style error the app treats as success).
- `driver_create_pickup` should reject duplicate active pickups with `active_pickup_exists`.

## Related docs

- [single-device-session-handoff.md](./single-device-session-handoff.md)
