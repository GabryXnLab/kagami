-- 0001 — I dati personali di ogni lettore e gli inviti a un Kagami Server.
--
-- readers: una riga per lettore, il file di backup dell'app dentro `data`
--   ({payload (base64), revision, device}); la vede e la scrive solo chi la possiede.
-- server_invites: chi ha aperto il proprio server a un altro account; legge e toglie chi manda o
--   chi riceve, scrive solo chi manda, e serve l'email verificata.

CREATE TABLE public.readers (
  id text PRIMARY KEY,
  owner uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users ON DELETE CASCADE,
  data jsonb NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.readers ENABLE ROW LEVEL SECURITY;
CREATE POLICY readers_owner ON public.readers TO authenticated
  USING (owner = auth.uid()) WITH CHECK (owner = auth.uid());

-- L'email verificata di chi chiama, minuscola, o NULL. SECURITY DEFINER perché `authenticated`
-- non legge auth.users; search_path vuoto perché una funzione così non deve fidarsi di chi la chiama.
CREATE FUNCTION public.kagami_me() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT lower(u.email) FROM auth.users u WHERE u.id = auth.uid() AND u.email_confirmed_at IS NOT NULL
$$;
REVOKE ALL ON FUNCTION public.kagami_me() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.kagami_me() TO authenticated;

CREATE TABLE public.server_invites (
  id text PRIMARY KEY,
  to_email text NOT NULL CHECK (to_email = lower(to_email)),
  from_email text NOT NULL,
  from_name text,
  url text NOT NULL CHECK (length(url) < 512),
  server_name text NOT NULL CHECK (length(server_name) < 128),
  at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX server_invites_to_idx ON public.server_invites (to_email);
ALTER TABLE public.server_invites ENABLE ROW LEVEL SECURITY;
CREATE POLICY server_invites_read ON public.server_invites FOR SELECT TO authenticated
  USING (to_email = public.kagami_me() OR from_email = public.kagami_me());
CREATE POLICY server_invites_delete ON public.server_invites FOR DELETE TO authenticated
  USING (to_email = public.kagami_me() OR from_email = public.kagami_me());
CREATE POLICY server_invites_create ON public.server_invites FOR INSERT TO authenticated
  WITH CHECK (from_email = public.kagami_me());
CREATE POLICY server_invites_update ON public.server_invites FOR UPDATE TO authenticated
  USING (from_email = public.kagami_me()) WITH CHECK (from_email = public.kagami_me());

REVOKE ALL ON public.readers, public.server_invites FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.readers, public.server_invites TO authenticated;
GRANT ALL ON public.readers, public.server_invites TO service_role;
