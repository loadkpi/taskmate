---
key:
summary: Add rate limiting to public API endpoints
issue_type: Task
status:
priority: Medium
labels:
  - backend
  - security
components:
sync_state: new_local
---

## Goal

Protect public API endpoints from abuse by adding per-IP rate limiting.

## What to do

- Add `rack-attack` gem for middleware-level rate limiting
- Configure limits: 100 requests/minute per IP for public endpoints
- Return `429 Too Many Requests` with `Retry-After` header when exceeded
- Log rate limit hits for monitoring

## Notes

- Exempt authenticated users from rate limiting (or use higher limits)
- Ensure health check endpoint is excluded
