-- 0007 — Le funzioni di Kagami le esegue solo chi deve (F8.2, T6). Su Supabase e su Hestia ogni
-- funzione nuova di public nasce concessa ad anon e authenticated (privilegi predefiniti), e il
-- `REVOKE ... FROM PUBLIC` delle migrazioni di prima non toglie quelle concessioni: anon poteva
-- chiamare via RPC kagami_me, kagami_sees, kagami_accepts. Qui si tolgono per nome, non con
-- `ALL FUNCTIONS IN SCHEMA`, perché lo schema può ospitare altro.
--
-- authenticated tiene le funzioni che le regole e i CHECK chiamano (una regola gira coi permessi di chi
-- legge); perde quelle dei trigger, che un trigger esegue comunque. rls-test.sql lo controlla per ogni
-- funzione di public, anche le prossime.

REVOKE EXECUTE ON FUNCTION public.kagami_me(), public.kagami_touch(),
  public.kagami_pairs_ok(jsonb, int, text, int, text, numeric), public.kagami_numbers_ok(jsonb, text[], numeric),
  public.kagami_days_ok(jsonb, int), public.kagami_blocked(uuid, uuid), public.kagami_sees(uuid),
  public.kagami_accepts(uuid), public.kagami_quota(), public.kagami_comment_author_name(), public.kagami_count(),
  public.kagami_unfollow_blocked() FROM anon;
REVOKE EXECUTE ON FUNCTION public.kagami_touch(), public.kagami_quota(), public.kagami_comment_author_name(),
  public.kagami_count(), public.kagami_unfollow_blocked() FROM authenticated;
-- Le tre dei CHECK erano rimaste anche a PUBLIC: le chiama solo chi scrive, cioè authenticated.
REVOKE EXECUTE ON FUNCTION public.kagami_pairs_ok(jsonb, int, text, int, text, numeric),
  public.kagami_numbers_ok(jsonb, text[], numeric), public.kagami_days_ok(jsonb, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.kagami_pairs_ok(jsonb, int, text, int, text, numeric),
  public.kagami_numbers_ok(jsonb, text[], numeric), public.kagami_days_ok(jsonb, int) TO authenticated, service_role;
