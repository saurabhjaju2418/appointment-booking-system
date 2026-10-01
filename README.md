<div align="center">

<img src="assets/project-banner.svg" alt="Animated Slotwise — Appointment Booking banner" width="900" />

# Slotwise — Appointment Booking

**Make a good time, at the right time.**

Next.js · Supabase · Resend · Vercel

![Project status](https://img.shields.io/badge/status-in%20progress-7a8b71)

</div>

## Product scope

Customer booking with service selection, timezone-aware availability, confirmation, and rescheduling.

## Architecture notes

Postgres exclusion constraints prevent overlapping reservations; server routes apply timezone-safe slot rules; Resend delivers confirmation and reminder events.

### Data model sketch

    services(id, duration_minutes, buffer_minutes) · availability_rules(id, resource_id, weekday, starts_at, ends_at) · bookings(id, slot, status, idempotency_key)

## Stack

Next.js · Supabase · Resend · Vercel

## Build sequence

1. Availability and service catalog
2. Atomic booking and reschedule
3. Email confirmation and reminders
4. Timezone and concurrency safeguards

## Current status

Public repository with an animated README. Product code is being built incrementally, one project at a time. This page records the planned product boundary and engineering milestones.

## License

MIT.
