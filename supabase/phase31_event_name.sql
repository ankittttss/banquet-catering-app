-- ============================================================================
-- phase31_event_name.sql
--
-- Adds an optional display name to events. The customer chooses an event name
-- when planning (e.g. "Aanya's Sangeet"); we now store it so it can be shown
-- on the customer's orders list and in operator inboxes instead of a generic
-- "Event" label.
--
-- Nullable so historical rows remain valid. Safe to re-run.
-- ============================================================================

alter table public.events
  add column if not exists name text;
