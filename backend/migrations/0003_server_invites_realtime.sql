-- 0003 — Gli inviti arrivano mentre l'app è aperta: `server_invites` entra nella pubblicazione che
-- il realtime di Supabase ascolta. Un backend che non ce l'ha resta com'è, e l'app rilegge gli
-- inviti all'avvio e tornando in primo piano.

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.server_invites;
  END IF;
END $$;
