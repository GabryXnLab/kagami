-- Le regole di backend/schema.sql, provate: ogni violazione solleva un'eccezione e ferma psql.
-- Gira in una transazione sola che alla fine si annulla, quindi non lascia niente: su un Postgres
-- usa e getta con backend/test.sh, o su un backend vero con lo schema già applicato
-- (`psql "$DATABASE_URL" -f backend/rls-test.sql`, da un ruolo che può scrivere in auth.users).
\set ON_ERROR_STOP 1
BEGIN;

-- Guardie di struttura (F8.2, T6): ciò che una tabella, una vista o una funzione nuova deve avere
-- prima ancora di avere un caso suo. Su Supabase e su Hestia ogni oggetto nuovo di public nasce
-- concesso ad anon (local-shim.sql lo imita): lo schema lo toglie da sé, e qui si vede se l'ha fatto.
-- Le funzioni SECURITY DEFINER sono poche e rivedute una per una: una nuova entra in questi elenchi
-- solo dopo averla letta. Gli aiuti del test stanno in pg_temp, fuori da public.
CREATE FUNCTION pg_temp.rls_structure() RETURNS SETOF text LANGUAGE sql AS $$
  SELECT format('%s senza RLS', c.oid::regclass) FROM pg_class c
    WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p') AND NOT c.relrowsecurity
  UNION ALL
  SELECT format('regola %s su %s vale per %s', p.policyname, p.tablename, p.roles) FROM pg_policies p
    WHERE p.schemaname = 'public' AND p.roles && ARRAY['anon', 'public']::name[]
  UNION ALL
  SELECT format('anon ha permessi su %s', c.oid::regclass) FROM pg_class c
    WHERE c.relnamespace = 'public'::regnamespace AND (
      (c.relkind IN ('r', 'p', 'v', 'm', 'f') AND (
        has_table_privilege('anon', c.oid, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
        OR has_any_column_privilege('anon', c.oid, 'SELECT, INSERT, UPDATE, REFERENCES')))
      OR (c.relkind = 'S' AND has_sequence_privilege('anon', c.oid, 'USAGE, SELECT, UPDATE')))
  UNION ALL
  -- L'unica concessa ad anon: il server, che ha solo la chiave anon, chiede di chi è un biglietto (F8.6).
  SELECT format('anon esegue %s', p.oid::regprocedure) FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace AND has_function_privilege('anon', p.oid, 'EXECUTE')
      AND p.oid <> ALL (ARRAY['public.kagami_ticket_who(text, text)'::regprocedure,
        'public.kagami_ticket_who(text, text, text)'::regprocedure])
  UNION ALL
  SELECT format('funzione definer non rivista: %s', p.oid::regprocedure) FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace AND p.prosecdef AND p.proname <> ALL (ARRAY['kagami_me', 'kagami_blocked',
      'kagami_sees', 'kagami_accepts', 'kagami_quota', 'kagami_comment_author_name', 'kagami_count', 'kagami_unfollow_blocked',
      'kagami_ticket', 'kagami_ticket_who', 'kagami_follower_name', 'kagami_server_origin'])
  UNION ALL
  SELECT format('%s senza search_path vuoto', p.oid::regprocedure) FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace AND p.prosecdef
      AND NOT coalesce(p.proconfig @> ARRAY['search_path=""'], false)
  UNION ALL
  -- Le funzioni dei trigger non si chiamano a mano: authenticated chiama solo quelle delle regole.
  SELECT format('authenticated esegue %s', p.oid::regprocedure) FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace AND p.prosecdef AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
      AND p.proname <> ALL (ARRAY['kagami_me', 'kagami_blocked', 'kagami_sees', 'kagami_accepts', 'kagami_ticket',
        'kagami_server_origin'])
  UNION ALL
  SELECT format('vista %s senza security_invoker', c.oid::regclass) FROM pg_class c
    WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'v'
      AND NOT coalesce(c.reloptions @> ARRAY['security_invoker=true'], false)
  UNION ALL
  SELECT format('vista materializzata %s: non passa dalle regole', c.oid::regclass) FROM pg_class c
    WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'm'
$$;
DO $$
DECLARE problems text;
BEGIN
  SELECT string_agg(problem, '; ') INTO problems FROM pg_temp.rls_structure() problem;
  IF problems IS NOT NULL THEN RAISE EXCEPTION 'struttura: %', problems; END IF;
END $$;

-- Le guardie vedono davvero: ogni sonda, in una sottotransazione che si annulla, deve farne scattare una.
CREATE FUNCTION pg_temp.rls_structure_sees(setup text, expected text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE seen text;
BEGIN
  BEGIN
    EXECUTE setup;
    SELECT coalesce(bool_or(problem LIKE expected), false)::text INTO seen FROM pg_temp.rls_structure() problem;
    RAISE EXCEPTION USING ERRCODE = 'no_data_found', MESSAGE = seen;
  EXCEPTION WHEN no_data_found THEN seen := SQLERRM;
  END;
  IF seen <> 'true' THEN RAISE EXCEPTION 'la guardia non vede «%» dopo: %', expected, setup; END IF;
END $$;
SELECT pg_temp.rls_structure_sees('CREATE TABLE public.sonda (x int); REVOKE ALL ON public.sonda FROM anon',
  'sonda senza RLS');
SELECT pg_temp.rls_structure_sees('CREATE POLICY sonda ON public.readers USING (true)', 'regola sonda su readers%');
SELECT pg_temp.rls_structure_sees('CREATE POLICY sonda ON public.readers TO anon USING (true)', 'regola sonda su readers%');
SELECT pg_temp.rls_structure_sees('GRANT SELECT (id) ON public.readers TO anon', 'anon ha permessi su readers');
SELECT pg_temp.rls_structure_sees('GRANT SELECT ON public.readers TO PUBLIC', 'anon ha permessi su readers');
SELECT pg_temp.rls_structure_sees('GRANT EXECUTE ON FUNCTION public.kagami_me() TO anon', 'anon esegue kagami_me()');
SELECT pg_temp.rls_structure_sees('GRANT EXECUTE ON FUNCTION public.kagami_ticket(text) TO anon', 'anon esegue kagami_ticket(text)');
SELECT pg_temp.rls_structure_sees('GRANT EXECUTE ON FUNCTION public.kagami_ticket_who(text, text) TO authenticated',
  'authenticated esegue kagami_ticket_who(text,text)');
SELECT pg_temp.rls_structure_sees('GRANT EXECUTE ON FUNCTION public.kagami_ticket_who(text, text, text) TO authenticated',
  'authenticated esegue kagami_ticket_who(text,text,text)');
SELECT pg_temp.rls_structure_sees('GRANT EXECUTE ON FUNCTION public.kagami_server_origin(text, text) TO anon',
  'anon esegue kagami_server_origin(text,text)');
SELECT pg_temp.rls_structure_sees($q$CREATE FUNCTION public.sonda() RETURNS int LANGUAGE sql SECURITY DEFINER
  SET search_path = '' AS 'SELECT 1'$q$, 'funzione definer non rivista: sonda()');
SELECT pg_temp.rls_structure_sees('ALTER FUNCTION public.kagami_me() RESET search_path', 'kagami_me() senza search_path vuoto');
SELECT pg_temp.rls_structure_sees('GRANT EXECUTE ON FUNCTION public.kagami_quota() TO authenticated',
  'authenticated esegue kagami_quota()');
SELECT pg_temp.rls_structure_sees('CREATE VIEW public.sonda AS SELECT 1 AS x; REVOKE ALL ON public.sonda FROM anon',
  'vista sonda senza security_invoker');
SELECT pg_temp.rls_structure_sees('CREATE MATERIALIZED VIEW public.sonda AS SELECT 1 AS x', 'vista materializzata sonda%');

INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data) VALUES
  ('00000000-0000-4000-8000-0000000000a1', 'Alice@example.com', now(), '{"providers": ["google"]}'),
  ('00000000-0000-4000-8000-0000000000b0', 'bob@example.com', now(), '{"providers": ["google"]}'),
  ('00000000-0000-4000-8000-0000000000d0', 'dario@example.com', now(), '{"providers": ["google"]}');
INSERT INTO public.readers (id, owner, data, updated_at) VALUES
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', '{"revision": "1"}', '2000-01-01'),
  ('00000000-0000-4000-8000-0000000000b0', '00000000-0000-4000-8000-0000000000b0', '{}', '2000-01-01');
-- Gli id degli inviti sono i primi 32 caratteri di sha256("<da>|<a>|<indirizzo>") (0014).
CREATE FUNCTION public.rls_iid(from_email text, to_email text, url text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT substr(encode(sha256(convert_to(from_email || '|' || to_email || '|' || url, 'UTF8')), 'hex'), 1, 32)
$$;
INSERT INTO public.server_invites (id, to_email, from_email, url, server_name) VALUES
  (rls_iid('alice@example.com', 'bob@example.com', 'https://kagami.example.com'), 'bob@example.com', 'alice@example.com', 'https://kagami.example.com', 'Alice'),
  (rls_iid('alice@example.com', 'carla@example.com', 'https://kagami.example.com'), 'carla@example.com', 'alice@example.com', 'https://kagami.example.com', 'Alice');
-- Gli id di drive_shares sono i primi 32 caratteri di sha256("<da>|<a>|<cartella>"): li controlla la tabella.
INSERT INTO public.drive_shares (id, to_email, from_email, from_uid, from_name, folder_id, folder_name, permission_id, expires_at) VALUES
  ('f42188cff73586c2b9189aaaa391be9d', 'bob@example.com', 'alice@example.com', '00000000-0000-4000-8000-0000000000a1', 'Alice', 'F1', 'Manga', 'P-bob', now() + interval '7 days'),
  ('07963953f9554bc9d9375dde94f95929', 'carla@example.com', 'alice@example.com', '00000000-0000-4000-8000-0000000000a1', 'Alice', 'F1', 'Manga', 'P-carla', NULL);

DO $$ BEGIN
  IF (SELECT min(updated_at) FROM public.readers) < now() - interval '1 day' THEN
    RAISE EXCEPTION 'la data di readers l''ha decisa chi scrive';
  END IF;
END $$;

-- Senza accesso: nessuna tabella.
SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM 1 FROM public.readers;
    RAISE EXCEPTION 'anon legge readers';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM 1 FROM public.server_invites;
    RAISE EXCEPTION 'anon legge gli inviti';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM 1 FROM public.drive_shares;
    RAISE EXCEPTION 'anon legge le condivisioni';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

-- Alice, che ha mandato i due inviti (e la cui email in auth.users ha una maiuscola).
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-8000-0000000000a1", "role": "authenticated"}', true);
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.readers;
  IF n <> 1 THEN RAISE EXCEPTION 'alice vede % righe di readers', n; END IF;
  SELECT count(*) INTO n FROM public.server_invites;
  IF n <> 2 THEN RAISE EXCEPTION 'alice (mittente) vede % inviti invece di 2', n; END IF;
  UPDATE public.readers SET data = '{"revision": "2"}' WHERE id = '00000000-0000-4000-8000-0000000000a1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'alice non scrive la sua riga'; END IF;
  UPDATE public.readers SET data = '{}' WHERE id = '00000000-0000-4000-8000-0000000000b0';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'alice ha scritto la riga di bob'; END IF;
  SELECT count(*) INTO n FROM public.drive_shares;
  IF n <> 2 THEN RAISE EXCEPTION 'alice (chi condivide) vede % condivisioni invece di 2', n; END IF;
  -- Il rinnovo: chi condivide sposta la scadenza.
  UPDATE public.drive_shares SET expires_at = now() + interval '30 days' WHERE id = 'f42188cff73586c2b9189aaaa391be9d';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'chi condivide non rinnova'; END IF;
  -- Di serie la riga è «solo streaming»; chi condivide concede e toglie il permesso di scaricare.
  IF (SELECT download FROM public.drive_shares WHERE id = 'f42188cff73586c2b9189aaaa391be9d') THEN
    RAISE EXCEPTION 'una condivisione nasce col permesso di scaricare';
  END IF;
  UPDATE public.drive_shares SET download = true WHERE id = 'f42188cff73586c2b9189aaaa391be9d';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 OR NOT (SELECT download FROM public.drive_shares WHERE id = 'f42188cff73586c2b9189aaaa391be9d') THEN
    RAISE EXCEPTION 'chi condivide non concede il permesso di scaricare';
  END IF;
  UPDATE public.drive_shares SET download = false WHERE id = 'f42188cff73586c2b9189aaaa391be9d';
  IF (SELECT download FROM public.drive_shares WHERE id = 'f42188cff73586c2b9189aaaa391be9d') THEN
    RAISE EXCEPTION 'chi condivide non toglie il permesso di scaricare';
  END IF;
  BEGIN
    UPDATE public.drive_shares SET download = NULL WHERE id = 'f42188cff73586c2b9189aaaa391be9d';
    RAISE EXCEPTION 'download nullo accettato';
  EXCEPTION WHEN not_null_violation THEN NULL;
  END;
  -- La riga non si sposta su un altro destinatario tenendo l'id.
  BEGIN
    UPDATE public.drive_shares SET to_email = 'dario@example.com' WHERE id = 'f42188cff73586c2b9189aaaa391be9d';
    RAISE EXCEPTION 'una condivisione ha cambiato destinatario senza cambiare id';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;
RESET ROLE;

-- Bob, che ne ha ricevuto uno.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-8000-0000000000b0", "role": "authenticated"}', true);
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.readers;
  IF n <> 1 THEN RAISE EXCEPTION 'bob vede % righe di readers', n; END IF;
  BEGIN
    INSERT INTO public.readers (id, owner) VALUES ('falsa', '00000000-0000-4000-8000-0000000000a1');
    RAISE EXCEPTION 'bob ha scritto una riga a nome di alice';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  SELECT count(*) INTO n FROM public.server_invites;
  IF n <> 1 THEN RAISE EXCEPTION 'bob (destinatario) vede % inviti invece di 1', n; END IF;
  BEGIN
    INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
      VALUES ('falso', 'carla@example.com', 'alice@example.com', 'https://x.example.com', 'x');
    RAISE EXCEPTION 'bob ha scritto un invito a nome di alice';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE public.server_invites SET url = 'https://dirottato.example.com' WHERE id = rls_iid('alice@example.com', 'bob@example.com', 'https://kagami.example.com');
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'il destinatario ha modificato l''invito'; END IF;
  INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
    VALUES (rls_iid('bob@example.com', 'alice@example.com', 'https://kagami.example.org'), 'alice@example.com', 'bob@example.com', 'https://kagami.example.org', 'Bob');
  DELETE FROM public.server_invites WHERE id = rls_iid('alice@example.com', 'bob@example.com', 'https://kagami.example.com');
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'il destinatario non toglie l''invito'; END IF;
  SELECT count(*) INTO n FROM public.drive_shares;
  IF n <> 1 THEN RAISE EXCEPTION 'bob (chi riceve) vede % condivisioni invece di 1', n; END IF;
  UPDATE public.drive_shares SET expires_at = NULL WHERE id = 'f42188cff73586c2b9189aaaa391be9d';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'chi riceve si è tolto la scadenza'; END IF;
  -- Né si dà il permesso di scaricare (T21): la colonna è di chi condivide.
  UPDATE public.drive_shares SET download = true WHERE id = 'f42188cff73586c2b9189aaaa391be9d';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'chi riceve si è dato il permesso di scaricare'; END IF;
  UPDATE public.drive_shares SET download = true;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'chi riceve ha cambiato il permesso di scaricare di % righe', n; END IF;
  -- Chi riceve non toglie la riga: è lì che sta il termine del permesso di Drive.
  DELETE FROM public.drive_shares WHERE id = 'f42188cff73586c2b9189aaaa391be9d';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'chi riceve ha tolto la condivisione'; END IF;
  BEGIN
    INSERT INTO public.drive_shares (id, to_email, from_email, folder_id, folder_name, permission_id)
      VALUES (substr(encode(sha256(convert_to('alice@example.com|dario@example.com|F1', 'UTF8')), 'hex'), 1, 32),
        'dario@example.com', 'alice@example.com', 'F1', 'Manga', 'P-x');
    RAISE EXCEPTION 'bob ha scritto una condivisione a nome di alice';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Né occupa l'id di una condivisione che alice non ha ancora scritto (alice → dario).
  BEGIN
    INSERT INTO public.drive_shares (id, to_email, from_email, folder_id, folder_name, permission_id)
      VALUES (substr(encode(sha256(convert_to('alice@example.com|dario@example.com|F1', 'UTF8')), 'hex'), 1, 32),
        'dario@example.com', 'bob@example.com', 'F1', 'Manga', 'P-x');
    RAISE EXCEPTION 'bob ha occupato l''id di una condivisione di alice';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- Né dichiara l'utente di un altro in una riga sua.
  BEGIN
    INSERT INTO public.drive_shares (id, to_email, from_email, from_uid, folder_id, folder_name, permission_id)
      VALUES ('f15a574d3a726f36e465f7e139100d7e', 'carla@example.com', 'bob@example.com',
        '00000000-0000-4000-8000-0000000000a1', 'F2', 'Letture', 'P-carla');
    RAISE EXCEPTION 'bob ha scritto una condivisione con l''utente di alice';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Le sue le scrive e le toglie, e l'utente lo mette il backend.
  INSERT INTO public.drive_shares (id, to_email, from_email, folder_id, folder_name, permission_id)
    VALUES ('add890ecf6bbcd7449f5e9b291769a33', 'alice@example.com', 'bob@example.com', 'F2', 'Letture', 'P-alice'),
      ('f15a574d3a726f36e465f7e139100d7e', 'carla@example.com', 'bob@example.com', 'F2', 'Letture', 'P-carla');
  DELETE FROM public.drive_shares WHERE id = 'f15a574d3a726f36e465f7e139100d7e';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'chi condivide non toglie la sua condivisione'; END IF;
  IF (SELECT from_uid FROM public.drive_shares WHERE id = 'add890ecf6bbcd7449f5e9b291769a33')
      <> '00000000-0000-4000-8000-0000000000b0' THEN
    RAISE EXCEPTION 'l''utente di chi condivide non è quello che ha scritto';
  END IF;
END $$;
RESET ROLE;

-- Dario, un terzo: delle condivisioni fra gli altri non vede e non tocca niente.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-8000-0000000000d0", "role": "authenticated"}', true);
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.drive_shares;
  IF n <> 0 THEN RAISE EXCEPTION 'un terzo vede % condivisioni', n; END IF;
  DELETE FROM public.drive_shares;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'un terzo ha tolto % condivisioni', n; END IF;
END $$;
RESET ROLE;

-- Senza email verificata gli inviti e le condivisioni non esistono: né letti né scritti.
UPDATE auth.users SET email_confirmed_at = NULL WHERE id = '00000000-0000-4000-8000-0000000000b0';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-8000-0000000000b0", "role": "authenticated"}', true);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.server_invites) <> 0 THEN RAISE EXCEPTION 'bob non verificato vede inviti'; END IF;
  IF (SELECT count(*) FROM public.drive_shares) <> 0 THEN RAISE EXCEPTION 'bob non verificato vede condivisioni'; END IF;
  BEGIN
    INSERT INTO public.drive_shares (id, to_email, from_email, folder_id, folder_name, permission_id)
      VALUES ('f15a574d3a726f36e465f7e139100d7e', 'carla@example.com', 'bob@example.com', 'F2', 'Letture', 'P-carla');
    RAISE EXCEPTION 'bob non verificato ha scritto una condivisione';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
      VALUES (rls_iid('bob@example.com', 'carla@example.com', 'https://kagami.example.org'), 'carla@example.com', 'bob@example.com', 'https://kagami.example.org', 'Bob');
    RAISE EXCEPTION 'bob non verificato ha scritto un invito';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

-- Il social (0005, docs/social.md). Qualche aiuto, che se ne va col ROLLBACK: chi è chi, chi agisce,
-- e le attese. rls_expect esegue un'istruzione e vuole quel codice d'errore; rls_rows dice quante
-- righe ha toccato; rls_is confronta.
RESET ROLE;
UPDATE auth.users SET email_confirmed_at = now() WHERE id = '00000000-0000-4000-8000-0000000000b0';
INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data) VALUES
  ('00000000-0000-4000-8000-0000000000c0', 'carla@example.com', now(), '{"providers": ["google"]}'),
  ('00000000-0000-4000-8000-0000000000e0', 'eva@example.com', now(), '{"providers": ["google"]}'),
  ('00000000-0000-4000-8000-0000000000f0', 'fede@example.com', now(), '{"providers": ["google"]}');
-- Cinquecento lettori in più, per il limite delle persone seguite.
INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data)
  SELECT ('00000000-0000-4000-9000-' || lpad(i::text, 12, '0'))::uuid, 'folla' || i || '@example.com', now(), '{"providers": ["google"]}'
  FROM generate_series(1, 500) i;
INSERT INTO public.profiles (id, name, week_id, month_id)
  SELECT ('00000000-0000-4000-9000-' || lpad(i::text, 12, '0'))::uuid, 'folla ' || i, '2026-W46', '2026-11'
  FROM generate_series(1, 500) i;

CREATE FUNCTION public.rls_u(who text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
  SELECT ('00000000-0000-4000-8000-0000000000' || CASE who
    WHEN 'alice' THEN 'a1' WHEN 'bob' THEN 'b0' WHEN 'carla' THEN 'c0' WHEN 'dario' THEN 'd0'
    WHEN 'eva' THEN 'e0' WHEN 'fede' THEN 'f0' END)::uuid
$$;
CREATE FUNCTION public.rls_as(who text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims', CASE WHEN who IS NULL THEN '' ELSE
    json_build_object('sub', public.rls_u(who), 'role', 'authenticated')::text END, true);
  SELECT set_config('role', CASE WHEN who IS NULL THEN 'none' ELSE 'authenticated' END, true);
$$;
CREATE FUNCTION public.rls_expect(statement text, code text, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = code THEN RETURN; END IF;
    RAISE EXCEPTION '%: atteso %, avuto % (%)', label, code, SQLSTATE, SQLERRM;
  END;
  RAISE EXCEPTION '%: è passato', label;
END $$;
CREATE FUNCTION public.rls_rows(statement text) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE n bigint;
BEGIN
  EXECUTE statement;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;
CREATE FUNCTION public.rls_is(actual bigint, expected bigint, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF actual IS DISTINCT FROM expected THEN RAISE EXCEPTION '%: % invece di %', label, actual, expected; END IF;
END $$;
CREATE FUNCTION public.rls_post(body text) RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT id FROM public.posts WHERE posts.body = rls_post.body
$$;
CREATE FUNCTION public.rls_comment(body text) RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT id FROM public.comments WHERE comments.body = rls_comment.body
$$;

-- anon non legge e non scrive niente del social.
SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM 1 FROM public.profiles;
    RAISE EXCEPTION 'anon legge i profili';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

-- Ognuno scrive il suo profilo e un post; nessuno scrive quello di un altro.
-- alice: tutti la vedono, nessuno le scrive. bob: chi segue lui. carla: a vicenda. dario: tutti.
SELECT rls_as('alice');
INSERT INTO public.profiles (id, name, audience, messages, week_id, month_id, totals, streak)
  VALUES (rls_u('alice'), 'Alice', 'everyone', 'nobody', '2026-W46', '2026-11', '{"chapters": 120}', '{"current": 3, "longest": 9}');
INSERT INTO public.posts (author, body) VALUES (rls_u('alice'), 'di alice');
SELECT rls_expect($q$INSERT INTO public.profiles (id, name, week_id, month_id) VALUES (rls_u('bob'), 'Finto', '2026-W46', '2026-11')$q$,
  '42501', 'alice ha scritto il profilo di bob');
SELECT rls_is((SELECT total_chapters FROM public.profiles WHERE id = rls_u('alice')), 120, 'colonna generata total_chapters');
SELECT rls_is((SELECT streak_current FROM public.profiles WHERE id = rls_u('alice')), 3, 'colonna generata streak_current');
SELECT rls_expect($q$UPDATE public.profiles SET updated_at = '2000-01-01'$q$, '42501', 'updated_at scritto dall''app');
SELECT rls_as('bob');
INSERT INTO public.profiles (id, name, audience, messages, week_id, month_id)
  VALUES (rls_u('bob'), 'Bob', 'following', 'following', '2026-W46', '2026-11');
INSERT INTO public.posts (author, body) VALUES (rls_u('bob'), 'di bob');
SELECT rls_as('carla');
INSERT INTO public.profiles (id, name, audience, messages, week_id, month_id)
  VALUES (rls_u('carla'), 'Carla', 'mutual', 'mutual', '2026-W46', '2026-11');
INSERT INTO public.posts (author, body) VALUES (rls_u('carla'), 'di carla');
SELECT rls_as('dario');
INSERT INTO public.profiles (id, name, audience, messages, week_id, month_id)
  VALUES (rls_u('dario'), 'Dario', 'everyone', 'everyone', '2026-W46', '2026-11');
INSERT INTO public.posts (author, body) VALUES (rls_u('dario'), 'di dario');
SELECT rls_as('fede');
INSERT INTO public.profiles (id, name, week_id, month_id) VALUES (rls_u('fede'), 'Fede', '2026-W46', '2026-11');
SELECT rls_as('bob');
SELECT rls_is(rls_rows($q$UPDATE public.profiles SET name = 'Rubato' WHERE id = rls_u('alice')$q$), 0, 'bob ha cambiato il profilo di alice');
SELECT rls_is(rls_rows($q$DELETE FROM public.profiles WHERE id = rls_u('alice')$q$), 0, 'bob ha tolto il profilo di alice');

-- Chi non ha un profilo non legge nessuna tabella del social, e senza profilo non scrive.
SELECT rls_as('eva');
SELECT rls_is((SELECT count(*) FROM public.profiles), 0, 'eva senza profilo vede profili');
SELECT rls_is((SELECT count(*) FROM public.posts), 0, 'eva senza profilo vede post');
SELECT rls_is((SELECT count(*) FROM public.following_posts), 0, 'eva senza profilo vede il seguito');
SELECT rls_is((SELECT count(*) FROM public.follows), 0, 'eva senza profilo vede legami');
SELECT rls_is((SELECT count(*) FROM public.blocks), 0, 'eva senza profilo vede blocchi');
SELECT rls_is((SELECT count(*) FROM public.comments), 0, 'eva senza profilo vede commenti');
SELECT rls_is((SELECT count(*) FROM public.likes), 0, 'eva senza profilo vede mi piace');
SELECT rls_is((SELECT count(*) FROM public.messages), 0, 'eva senza profilo vede messaggi');
SELECT rls_expect($q$SELECT 1 FROM public.reports$q$, '42501', 'eva legge le segnalazioni');
SELECT rls_expect($q$INSERT INTO public.blocks (blocker, blocked) VALUES (rls_u('eva'), rls_u('alice'))$q$, '42501', 'eva senza profilo blocca');
SELECT rls_expect($q$INSERT INTO public.reports (reporter, target, target_user, reason) VALUES (rls_u('eva'), 'user', rls_u('alice'), 'spam')$q$,
  '42501', 'eva senza profilo segnala');
SELECT rls_expect($q$INSERT INTO public.posts (author, body) VALUES (rls_u('eva'), 'ciao')$q$, '23503', 'eva senza profilo pubblica');

-- Il profilo senza email verificata non nasce.
RESET ROLE;
UPDATE auth.users SET email_confirmed_at = NULL WHERE id = rls_u('eva');
SELECT rls_as('eva');
SELECT rls_expect($q$INSERT INTO public.profiles (id, name, week_id, month_id) VALUES (rls_u('eva'), 'Eva', '2026-W46', '2026-11')$q$,
  '42501', 'profilo senza email verificata');

-- everyone: lo vede chiunque abbia il profilo.
SELECT rls_as('bob');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('alice')), 1, 'bob non vede alice (everyone)');
SELECT rls_is((SELECT count(*) FROM public.posts WHERE author = rls_u('alice')), 1, 'bob non vede il post di alice');

-- following: serve che il proprietario segua chi guarda; il verso opposto non basta.
SELECT rls_as('alice');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('bob')), 0, 'alice vede bob senza legami');
INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('alice'), rls_u('bob'), 'Alice');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('bob')), 0, 'alice vede bob seguendolo lei (following)');
SELECT rls_as('bob');
SELECT rls_is((SELECT count(*) FROM public.follows WHERE follower = rls_u('alice') AND follower_name = 'Alice'), 1,
  'bob non sa che alice lo segue');
INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('bob'), rls_u('alice'), 'Falso Nome');
SELECT rls_is((SELECT count(*) FROM public.follows WHERE follower = rls_u('bob') AND followee = rls_u('alice') AND follower_name = 'Bob'), 1, 'bob firma il legame con un altro nome');
UPDATE public.follows SET follower_name = 'Altro Nome' WHERE follower = rls_u('bob') AND followee = rls_u('alice');
SELECT rls_is((SELECT count(*) FROM public.follows WHERE follower = rls_u('bob') AND followee = rls_u('alice') AND follower_name = 'Bob'), 1, 'bob rinomina il legame a mano');
SELECT rls_as('alice');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('bob')), 1, 'alice non vede bob che la segue (following)');
SELECT rls_is((SELECT count(*) FROM public.posts WHERE author = rls_u('bob')), 1, 'alice non vede il post di bob');
SELECT rls_is((SELECT count(*) FROM public.following_posts), 1, 'il seguito di alice non è il post di bob');
SELECT rls_as('dario');
SELECT rls_is((SELECT count(*) FROM public.follows), 0, 'dario vede i legami degli altri');

-- mutual: servono i due versi; ognuno da solo non basta.
SELECT rls_as('carla');
INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('carla'), rls_u('dario'), 'Carla');
SELECT rls_as('dario');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('carla')), 0, 'dario vede carla seguito solo da lei (mutual)');
SELECT rls_as('alice');
INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('alice'), rls_u('carla'), 'Alice');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('carla')), 0, 'alice vede carla seguendola solo lei (mutual)');
SELECT rls_as('dario');
INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('dario'), rls_u('carla'), 'Dario');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('carla')), 1, 'dario non vede carla a vicenda (mutual)');
SELECT rls_is((SELECT count(*) FROM public.posts WHERE author = rls_u('carla')), 1, 'dario non vede il post di carla');
-- Il legame si rinomina, ma solo da chi segue, e solo il nome.
SELECT rls_is(rls_rows($q$UPDATE public.follows SET follower_name = 'Dario Bis' WHERE follower = rls_u('dario')$q$), 1, 'dario non rinomina il suo legame');
SELECT rls_is(rls_rows($q$UPDATE public.follows SET follower_name = 'Rubato' WHERE follower = rls_u('carla')$q$), 0, 'dario ha rinominato il legame di carla');
SELECT rls_expect($q$UPDATE public.follows SET followee = rls_u('alice') WHERE follower = rls_u('dario')$q$, '42501', 'un legame ha cambiato persona');

-- Nessuno scrive a nome di un altro.
SELECT rls_as('bob');
SELECT rls_expect($q$INSERT INTO public.posts (author, body) VALUES (rls_u('alice'), 'finto')$q$, '42501', 'post a nome di alice');
SELECT rls_expect($q$INSERT INTO public.comments (post, author, body) VALUES (rls_post('di alice'), rls_u('alice'), 'finto')$q$,
  '42501', 'commento a nome di alice');
SELECT rls_expect($q$INSERT INTO public.likes (uid, post) VALUES (rls_u('alice'), rls_post('di alice'))$q$, '42501', 'mi piace a nome di alice');
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, body) VALUES (rls_u('dario'), rls_u('alice'), 'finto')$q$,
  '42501', 'messaggio a nome di dario');
SELECT rls_expect($q$INSERT INTO public.reports (reporter, target, target_user, reason) VALUES (rls_u('dario'), 'user', rls_u('alice'), 'spam')$q$,
  '42501', 'segnalazione a nome di dario');
SELECT rls_expect($q$INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('dario'), rls_u('alice'), 'Dario')$q$,
  '42501', 'legame a nome di dario');
SELECT rls_expect($q$INSERT INTO public.blocks (blocker, blocked) VALUES (rls_u('dario'), rls_u('alice'))$q$, '42501', 'blocco a nome di dario');

-- Commenti e mi piace; i contatori li tiene il backend e non si scrivono a mano.
INSERT INTO public.comments (post, author, body) VALUES (rls_post('di alice'), rls_u('bob'), 'bob su alice');
INSERT INTO public.likes (uid, post) VALUES (rls_u('bob'), rls_post('di alice'));
SELECT rls_expect($q$INSERT INTO public.likes (uid, post) VALUES (rls_u('bob'), rls_post('di carla'))$q$, '42501', 'mi piace su un post che non vede');
SELECT rls_expect($q$INSERT INTO public.comments (post, author, body) VALUES (rls_post('di carla'), rls_u('bob'), 'x')$q$,
  '42501', 'commento su un post che non vede');
SELECT rls_expect($q$INSERT INTO public.likes (uid, post) VALUES (rls_u('bob'), rls_post('di alice'))$q$, '23505', 'due mi piace sullo stesso post');
SELECT rls_expect($q$UPDATE public.posts SET likes = 99$q$, '42501', 'contatore dei mi piace scritto a mano');
SELECT rls_expect($q$UPDATE public.posts SET body = 'cambiato' WHERE author = rls_u('bob')$q$, '42501', 'un post è stato modificato');
SELECT rls_expect($q$INSERT INTO public.posts (author, body, likes) VALUES (rls_u('bob'), 'gonfio', 50)$q$, '42501', 'post nato con dei mi piace');
SELECT rls_expect($q$INSERT INTO public.comments (post, author, body, flags) VALUES (rls_post('di alice'), rls_u('bob'), 'x', 0)$q$,
  '42501', 'commento nato coi contatori');
SELECT rls_expect($q$UPDATE public.comments SET likes = 9$q$, '42501', 'contatore dei commenti scritto a mano');
SELECT rls_as('carla');
INSERT INTO public.comments (post, author, body) VALUES (rls_post('di alice'), rls_u('carla'), 'carla su alice');
SELECT rls_as('dario');
INSERT INTO public.comments (post, author, body) VALUES (rls_post('di alice'), rls_u('dario'), 'dario su alice');
INSERT INTO public.comments (post, author, parent, body)
  VALUES (rls_post('di alice'), rls_u('dario'), rls_comment('bob su alice'), 'dario risponde a bob');
SELECT rls_expect($q$INSERT INTO public.comments (post, author, parent, body)
  VALUES (rls_post('di dario'), rls_u('dario'), rls_comment('bob su alice'), 'risposta sul post sbagliato')$q$,
  '23503', 'risposta a un commento di un altro post');
INSERT INTO public.likes (uid, comment) VALUES (rls_u('dario'), rls_comment('bob su alice'));
-- Il padrone del post toglie un commento altrui; un terzo no.
SELECT rls_is(rls_rows($q$DELETE FROM public.comments WHERE body = 'bob su alice'$q$), 0, 'un terzo ha tolto il commento di bob');
SELECT rls_as('alice');
SELECT rls_is(rls_rows($q$DELETE FROM public.comments WHERE body = 'carla su alice'$q$), 1, 'alice non toglie un commento sotto il suo post');
RESET ROLE;
SELECT rls_is((SELECT likes FROM public.posts WHERE body = 'di alice'), 1, 'mi piace del post');
SELECT rls_is((SELECT comments FROM public.posts WHERE body = 'di alice'), 3, 'commenti del post');
SELECT rls_is((SELECT likes FROM public.comments WHERE body = 'bob su alice'), 1, 'mi piace del commento');
-- Il soprannome sul commento (0006): lo mette il backend, lo vede chi vede il post anche col profilo chiuso.
SELECT rls_as('carla');
SELECT rls_expect($q$INSERT INTO public.comments (post, author, author_name, body) VALUES (rls_post('di alice'), rls_u('carla'), 'Alice', 'x')$q$,
  '42501', 'commento firmato col nome di un altro');
INSERT INTO public.comments (post, author, body) VALUES (rls_post('di alice'), rls_u('carla'), 'carla parla piano');
UPDATE public.profiles SET name = 'Carla Bis' WHERE id = rls_u('carla');
SELECT rls_as('alice');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('carla')), 0, 'alice vede il profilo di carla (mutual)');
SELECT rls_is((SELECT count(*) FROM public.comments WHERE body = 'carla parla piano' AND author_name = 'Carla'), 1,
  'il commento di carla senza il soprannome di quando l''ha scritto');
SELECT rls_as('carla');
UPDATE public.profiles SET name = 'Carla' WHERE id = rls_u('carla');
RESET ROLE;

-- Messaggi. dario accetta tutti, bob chi segue lui, alice nessuno.
SELECT rls_as('dario');
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, body) VALUES (rls_u('dario'), rls_u('bob'), 'ciao')$q$,
  '42501', 'messaggio a bob, che non segue dario');
SELECT rls_as('bob');
INSERT INTO public.messages (sender, recipient, body) VALUES (rls_u('bob'), rls_u('dario'), 'ciao dario');
SELECT rls_as('dario');
INSERT INTO public.messages (sender, recipient, body) VALUES (rls_u('dario'), rls_u('bob'), 'ciao bob');
SELECT rls_as('alice');
INSERT INTO public.messages (sender, recipient, body) VALUES (rls_u('alice'), rls_u('bob'), 'ciao, ti seguo');
SELECT rls_as('bob');
-- La proroga: passa solo con la riga drive_shares giusta, una al giorno per condivisione.
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, body) VALUES (rls_u('bob'), rls_u('carla'), 'ciao')$q$,
  '42501', 'messaggio a carla, che accetta solo a vicenda');
INSERT INTO public.messages (sender, recipient, kind, body, share)
  VALUES (rls_u('bob'), rls_u('alice'), 'extension', 'più tempo?', 'f42188cff73586c2b9189aaaa391be9d');
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, kind, body, share)
  VALUES (rls_u('bob'), rls_u('alice'), 'extension', 'ancora?', 'f42188cff73586c2b9189aaaa391be9d')$q$,
  '42501', 'due richieste di proroga in un giorno');
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, kind, body, share)
  VALUES (rls_u('bob'), rls_u('alice'), 'extension', 'e questa?', '07963953f9554bc9d9375dde94f95929')$q$,
  '42501', 'proroga di una condivisione di un altro');
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, kind, body, share)
  VALUES (rls_u('bob'), rls_u('dario'), 'extension', 'a chi?', 'f42188cff73586c2b9189aaaa391be9d')$q$,
  '42501', 'proroga chiesta a chi non condivide');
SELECT rls_as('carla');
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, kind, body, share)
  VALUES (rls_u('carla'), rls_u('alice'), 'extension', 'anche a me', 'f42188cff73586c2b9189aaaa391be9d')$q$,
  '42501', 'proroga di una condivisione che non si riceve');
SELECT rls_is((SELECT count(*) FROM public.messages), 0, 'carla legge i messaggi degli altri');
-- read_at lo scrive solo il destinatario, e del messaggio nient'altro.
SELECT rls_as('bob');
SELECT rls_is(rls_rows($q$UPDATE public.messages SET read_at = now() WHERE body = 'ciao dario'$q$), 0, 'il mittente ha segnato letto');
SELECT rls_as('dario');
SELECT rls_is(rls_rows($q$UPDATE public.messages SET read_at = now() WHERE body = 'ciao dario'$q$), 1, 'il destinatario non segna letto');
SELECT rls_expect($q$UPDATE public.messages SET body = 'cambiato' WHERE body = 'ciao dario'$q$, '42501', 'un messaggio è stato riscritto');

-- Segnalazioni: si scrivono, non si rileggono, una per persona e oggetto; flags conta le persone.
SELECT rls_as('bob');
INSERT INTO public.reports (reporter, target, target_id, target_user, reason, snapshot)
  VALUES (rls_u('bob'), 'post', rls_post('di alice'), rls_u('alice'), 'spam', 'di alice');
SELECT rls_expect($q$SELECT 1 FROM public.reports$q$, '42501', 'bob rilegge le segnalazioni');
SELECT rls_expect($q$INSERT INTO public.reports (reporter, target, target_id, target_user, reason)
  VALUES (rls_u('bob'), 'post', rls_post('di alice'), rls_u('alice'), 'other')$q$, '23505', 'due segnalazioni sullo stesso post');
SELECT rls_as('dario');
INSERT INTO public.reports (reporter, target, target_id, target_user, reason)
  VALUES (rls_u('dario'), 'post', rls_post('di alice'), rls_u('alice'), 'spoiler');
INSERT INTO public.reports (reporter, target, target_user, reason) VALUES (rls_u('dario'), 'user', rls_u('alice'), 'harassment');
SELECT rls_expect($q$INSERT INTO public.reports (reporter, target, target_user, reason)
  VALUES (rls_u('dario'), 'user', rls_u('alice'), 'spam')$q$, '23505', 'due segnalazioni della stessa persona');
SELECT rls_expect($q$UPDATE public.posts SET flags = 0$q$, '42501', 'segnalazioni azzerate a mano');
RESET ROLE;
SELECT rls_is((SELECT flags FROM public.posts WHERE body = 'di alice'), 2, 'segnalazioni del post');

-- 0012: una segnalazione riguarda un oggetto che chi segnala vede e il suo autore vero; il nome sul
-- legame lo mette il backend dal profilo.
SELECT rls_as('dario');
INSERT INTO public.comments (post, author, body) VALUES (rls_post('di alice'), rls_u('dario'), 'commento da segnalare');
SELECT rls_as('bob');
SELECT rls_expect($q$INSERT INTO public.reports (reporter, target, target_id, target_user, reason)
  VALUES (rls_u('bob'), 'post', rls_post('di alice'), rls_u('dario'), 'other')$q$, '42501', 'segnalo un post attribuendolo a un altro');
SELECT rls_expect($q$INSERT INTO public.reports (reporter, target, target_id, target_user, reason)
  VALUES (rls_u('bob'), 'post', gen_random_uuid(), rls_u('alice'), 'other')$q$, '42501', 'segnalo un post che non esiste');
SELECT rls_expect($q$INSERT INTO public.reports (reporter, target, target_id, target_user, reason)
  VALUES (rls_u('bob'), 'comment', (SELECT id FROM public.comments WHERE body = 'commento da segnalare'), rls_u('alice'), 'other')$q$,
  '42501', 'segnalo un commento attribuendolo a un altro');
INSERT INTO public.reports (reporter, target, target_id, target_user, reason)
  VALUES (rls_u('bob'), 'comment', (SELECT id FROM public.comments WHERE body = 'commento da segnalare'), rls_u('dario'), 'other');
RESET ROLE;
SELECT rls_is((SELECT flags FROM public.comments WHERE body = 'commento da segnalare'), 1, 'segnalazioni del commento');
RESET ROLE;

-- Il blocco: reciproco, toglie i legami, nasconde profilo, post e commenti, ferma legami e messaggi.
SELECT rls_as('alice');
INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('alice'), rls_u('dario'), 'Alice');
INSERT INTO public.comments (post, author, body) VALUES (rls_post('di dario'), rls_u('alice'), 'alice su dario');
SELECT rls_as('bob');
INSERT INTO public.comments (post, author, body) VALUES (rls_post('di dario'), rls_u('bob'), 'bob su dario');
SELECT rls_as('dario');
INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('dario'), rls_u('alice'), 'Dario');
SELECT rls_as('alice');
INSERT INTO public.blocks (blocker, blocked) VALUES (rls_u('alice'), rls_u('dario'));
SELECT rls_is((SELECT count(*) FROM public.blocks), 1, 'alice non vede il suo blocco');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('dario')), 0, 'chi blocca vede il bloccato');
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, body) VALUES (rls_u('alice'), rls_u('dario'), 'ciao')$q$,
  '42501', 'chi blocca scrive al bloccato');
SELECT rls_as('dario');
SELECT rls_is((SELECT count(*) FROM public.blocks), 0, 'il bloccato vede il blocco');
SELECT rls_is((SELECT count(*) FROM public.follows WHERE rls_u('alice') IN (follower, followee)), 0, 'il blocco non ha tolto i legami');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('alice')), 0, 'il bloccato vede il profilo');
SELECT rls_is((SELECT count(*) FROM public.posts WHERE author = rls_u('alice')), 0, 'il bloccato vede i post');
SELECT rls_is((SELECT count(*) FROM public.comments WHERE author = rls_u('alice')), 0, 'il bloccato vede i commenti di chi blocca');
SELECT rls_is((SELECT count(*) FROM public.comments WHERE post = rls_post('di dario')), 1, 'sotto il suo post dario vede altro che bob');
SELECT rls_expect($q$INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('dario'), rls_u('alice'), 'Dario')$q$,
  '42501', 'il bloccato segue');
SELECT rls_expect($q$INSERT INTO public.comments (post, author, body) VALUES (rls_post('di alice'), rls_u('dario'), 'x')$q$,
  '42501', 'il bloccato commenta');
SELECT rls_expect($q$INSERT INTO public.likes (uid, post) VALUES (rls_u('dario'), rls_post('di alice'))$q$, '42501', 'il bloccato mette mi piace');
SELECT rls_as('bob');
SELECT rls_is((SELECT count(*) FROM public.comments WHERE post = rls_post('di dario')), 2, 'un terzo non vede i commenti di chi si è bloccato');

-- Una riga fuori forma è respinta.
SELECT rls_as('fede');
SELECT rls_expect($q$UPDATE public.profiles SET name = 'x' WHERE id = rls_u('fede')$q$, '23514', 'nome di un carattere');
SELECT rls_expect($q$UPDATE public.profiles SET bio = repeat('b', 161) WHERE id = rls_u('fede')$q$, '23514', 'bio troppo lunga');
SELECT rls_expect($q$UPDATE public.profiles SET audience = 'amici' WHERE id = rls_u('fede')$q$, '23514', 'pubblico sconosciuto');
SELECT rls_expect($q$UPDATE public.profiles SET week_id = '46' WHERE id = rls_u('fede')$q$, '23514', 'settimana fuori forma');
SELECT rls_expect($q$UPDATE public.profiles SET genres = (SELECT jsonb_agg(jsonb_build_object('name', 'g' || i, 'share', 10))
  FROM generate_series(1, 9) i) WHERE id = rls_u('fede')$q$, '23514', 'nove generi');
SELECT rls_expect($q$UPDATE public.profiles SET genres = '[{"name": "Azione", "share": 101}]' WHERE id = rls_u('fede')$q$, '23514', 'genere oltre 100');
SELECT rls_expect($q$UPDATE public.profiles SET series = jsonb_build_array(jsonb_build_object('title', repeat('t', 120), 'chapters', 1))
  WHERE id = rls_u('fede')$q$, '23514', 'titolo troppo lungo');
SELECT rls_expect($q$UPDATE public.profiles SET kinds = '{"fumetto": 10}' WHERE id = rls_u('fede')$q$, '23514', 'famiglia sconosciuta');
SELECT rls_expect($q$UPDATE public.profiles SET activity = '[1,2,3]' WHERE id = rls_u('fede')$q$, '23514', 'attività di tre giorni');
SELECT rls_expect($q$UPDATE public.profiles SET totals = '{"chapters": -1}' WHERE id = rls_u('fede')$q$, '23514', 'capitoli negativi');
UPDATE public.profiles SET genres = '[{"name": "Azione", "share": 60}]', kinds = '{"manga": 100}',
  series = '[{"title": "Alfa", "chapters": 60}]', activity = '[0,0,0,0,0,0,0,0,0,0,0,0,1,2]' WHERE id = rls_u('fede');
-- T5: la foto è di Google su https, o null.
UPDATE public.profiles SET photo = 'https://lh3.googleusercontent.com/a/ACg8ocAbC=s96-c' WHERE id = rls_u('fede');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('fede') AND photo = 'https://lh3.googleusercontent.com/a/ACg8ocAbC=s96-c'), 1, 'foto di Google accettata');
SELECT rls_expect($q$UPDATE public.profiles SET photo = 'http://lh3.googleusercontent.com/a/x' WHERE id = rls_u('fede')$q$, '23514', 'foto su http');
SELECT rls_expect($q$UPDATE public.profiles SET photo = 'https://tracker.example.com/a.png' WHERE id = rls_u('fede')$q$, '23514', 'foto di un altro host');
SELECT rls_expect($q$UPDATE public.profiles SET photo = 'javascript:alert(1)' WHERE id = rls_u('fede')$q$, '23514', 'foto javascript');
SELECT rls_expect($q$UPDATE public.profiles SET photo = 'https://lh3.googleusercontent.com.evil.example/a' WHERE id = rls_u('fede')$q$, '23514', 'foto di un host simile');
SELECT rls_expect($q$UPDATE public.profiles SET photo = 'https://evil.example/?https://lh3.googleusercontent.com/a' WHERE id = rls_u('fede')$q$, '23514', 'foto con l''host nella query');
UPDATE public.profiles SET photo = NULL WHERE id = rls_u('fede');
SELECT rls_is((SELECT count(*) FROM public.profiles WHERE id = rls_u('fede') AND photo IS NULL), 1, 'foto null accettata');
SELECT rls_expect($q$INSERT INTO public.posts (author, body) VALUES (rls_u('fede'), '')$q$, '23514', 'post vuoto');
SELECT rls_expect($q$INSERT INTO public.posts (author, kind, body, series_ref, series_title, rating)
  VALUES (rls_u('fede'), 'review', 'x', 'alfa', 'Alfa', 11)$q$, '23514', 'voto 11');
SELECT rls_expect($q$INSERT INTO public.posts (author, kind, body, series_ref, series_title)
  VALUES (rls_u('fede'), 'review', 'x', 'alfa', 'Alfa')$q$, '23514', 'recensione senza voto');
SELECT rls_expect($q$INSERT INTO public.posts (author, kind, body) VALUES (rls_u('fede'), 'recommendation', 'x')$q$, '23514', 'consiglio senza serie');
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, body) VALUES (rls_u('fede'), rls_u('dario'), '')$q$, '23514', 'messaggio vuoto');
SELECT rls_expect($q$INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('fede'), rls_u('fede'), 'Fede')$q$,
  '23514', 'seguire se stessi');

-- Limiti di frequenza, anche in un inserimento solo di molte righe.
SELECT rls_expect($q$INSERT INTO public.posts (author, body) SELECT rls_u('fede'), 'post ' || i FROM generate_series(1, 21) i$q$,
  '42501', '21 post in un giorno, in una richiesta');
INSERT INTO public.posts (author, body) SELECT rls_u('fede'), 'post ' || i FROM generate_series(1, 20) i;
SELECT rls_expect($q$INSERT INTO public.posts (author, body) VALUES (rls_u('fede'), 'il ventunesimo')$q$, '42501', '21 post in un giorno');
SELECT rls_expect($q$INSERT INTO public.messages (sender, recipient, body)
  SELECT rls_u('fede'), rls_u('dario'), 'messaggio ' || i FROM generate_series(1, 61) i$q$, '42501', '61 messaggi in un''ora');
SELECT rls_expect($q$INSERT INTO public.comments (post, author, body)
  SELECT rls_post('di dario'), rls_u('fede'), 'commento ' || i FROM generate_series(1, 61) i$q$, '42501', '61 commenti in un''ora');
INSERT INTO public.follows (follower, followee, follower_name)
  SELECT rls_u('fede'), ('00000000-0000-4000-9000-' || lpad(i::text, 12, '0'))::uuid, 'Fede' FROM generate_series(1, 500) i;
SELECT rls_expect($q$INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_u('fede'), rls_u('dario'), 'Fede')$q$,
  '42501', '501 persone seguite');
SELECT rls_expect($q$INSERT INTO public.reports (reporter, target, target_id, target_user, reason)
  SELECT rls_u('fede'), 'post', rls_post('post ' || i), rls_u('fede'), 'spam' FROM generate_series(1, 20) i
  UNION ALL SELECT rls_u('fede'), 'user', NULL, rls_u('dario'), 'spam'$q$, '42501', '21 segnalazioni in un giorno');

-- Uscire cancella tutto il proprio, anche nelle conversazioni degli altri, e lascia i blocchi.
SELECT rls_as('carla');
INSERT INTO public.blocks (blocker, blocked) VALUES (rls_u('carla'), rls_u('bob'));
INSERT INTO public.comments (post, author, body) VALUES (rls_post('di alice'), rls_u('carla'), 'carla di nuovo');
INSERT INTO public.likes (uid, post) VALUES (rls_u('carla'), rls_post('di alice'));
INSERT INTO public.messages (sender, recipient, body) VALUES (rls_u('carla'), rls_u('dario'), 'ciao da carla');
INSERT INTO public.reports (reporter, target, target_user, reason) VALUES (rls_u('carla'), 'user', rls_u('bob'), 'spam');
SELECT rls_is(rls_rows($q$DELETE FROM public.profiles WHERE id = rls_u('carla')$q$), 1, 'carla non esce');
SELECT rls_is((SELECT count(*) FROM public.blocks), 0, 'chi è uscito legge i suoi blocchi');
RESET ROLE;
SELECT rls_is((SELECT count(*) FROM public.posts WHERE author = rls_u('carla')), 0, 'post rimasti dopo l''uscita');
SELECT rls_is((SELECT count(*) FROM public.comments WHERE author = rls_u('carla')), 0, 'commenti rimasti dopo l''uscita');
SELECT rls_is((SELECT count(*) FROM public.likes WHERE uid = rls_u('carla')), 0, 'mi piace rimasti dopo l''uscita');
SELECT rls_is((SELECT count(*) FROM public.follows WHERE rls_u('carla') IN (follower, followee)), 0, 'legami rimasti dopo l''uscita');
SELECT rls_is((SELECT count(*) FROM public.messages WHERE rls_u('carla') IN (sender, recipient)), 0, 'messaggi rimasti dopo l''uscita');
SELECT rls_is((SELECT count(*) FROM public.blocks WHERE blocker = rls_u('carla')), 1, 'i blocchi non sono rimasti');
SELECT rls_is((SELECT count(*) FROM public.reports WHERE reporter = rls_u('carla')), 1, 'la segnalazione di chi è uscito non c''è più');

-- T3: l'indirizzo c'è solo con email confermata, accesso non anonimo e Google come unico provider.
-- fede diventa «la vittima»: un'altra persona con email e password e lo stesso indirizzo non vede né
-- inviti né condivisioni di bob, anche se conferma l'email.
RESET ROLE;
INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
  VALUES (rls_iid('bob@example.com', 'fede@example.com', 'https://kagami.example.org'), 'fede@example.com', 'bob@example.com', 'https://kagami.example.org', 'Bob');
INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data) VALUES
  ('00000000-0000-4000-8000-0000000000aa', 'FEDE@example.com', now(), '{"provider": "email", "providers": ["email"]}');
CREATE FUNCTION public.rls_me(uid uuid) RETURNS text LANGUAGE plpgsql AS $$
DECLARE r text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := public.kagami_me();
  PERFORM set_config('role', 'none', true);
  RETURN r;
END $$;
SELECT rls_is((rls_me('00000000-0000-4000-8000-0000000000aa') IS NULL)::int, 1, 'email e password confermata dà un indirizzo');
SELECT rls_is((rls_me(rls_u('fede')) = 'fede@example.com')::int, 1, 'google confermato non dà l''indirizzo');
UPDATE auth.users SET raw_app_meta_data = '{"providers": ["google", "email"]}' WHERE id = rls_u('fede');
SELECT rls_is((rls_me(rls_u('fede')) IS NULL)::int, 1, 'google più email dà un indirizzo');
UPDATE auth.users SET raw_app_meta_data = '{"providers": ["google"]}', is_anonymous = true WHERE id = rls_u('fede');
SELECT rls_is((rls_me(rls_u('fede')) IS NULL)::int, 1, 'un anonimo dà un indirizzo');
UPDATE auth.users SET is_anonymous = false WHERE id = rls_u('fede');
SELECT rls_is((rls_me(rls_u('fede')) = 'fede@example.com')::int, 1, 'google confermato non dà l''indirizzo (2)');
SELECT rls_as(NULL);
SELECT rls_is((rls_me('00000000-0000-4000-8000-0000000000aa') IS NULL)::int, 1, 'ancora l''account con email');
RESET ROLE;
SELECT set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000aa', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT rls_is((SELECT count(*) FROM public.server_invites), 0, 'l''account con email vede inviti');
SELECT rls_is((SELECT count(*) FROM public.drive_shares), 0, 'l''account con email vede condivisioni');
RESET ROLE;
SELECT rls_is((rls_me(rls_u('fede')) = 'fede@example.com')::int, 1, 'fede ha ancora il suo indirizzo');
RESET ROLE;
DROP FUNCTION public.rls_me(uuid);

-- T2: 30 inviti e 30 condivisioni nuove al giorno per mittente; il rinnovo non conta; `at` è del backend.
-- Gli id di drive_shares sono un hash: si calcolano come fa il vincolo.
CREATE FUNCTION public.rls_share_id(from_email text, to_email text, folder text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT substr(encode(sha256(convert_to(from_email || '|' || to_email || '|' || folder, 'UTF8')), 'hex'), 1, 32)
$$;
SELECT rls_as('dario');
SELECT rls_expect($q$INSERT INTO public.server_invites (id, to_email, from_email, url, server_name, at)
  SELECT rls_iid('dario@example.com', 'q' || i || '@example.com', 'https://k.example.com'), 'q' || i || '@example.com', 'dario@example.com', 'https://k.example.com', 'D', now() - interval '3 days'
  FROM generate_series(1, 31) i$q$, '42501', '31 inviti in un giorno');
INSERT INTO public.server_invites (id, to_email, from_email, url, server_name, at)
  SELECT rls_iid('dario@example.com', 'q' || i || '@example.com', 'https://k.example.com'), 'q' || i || '@example.com', 'dario@example.com', 'https://k.example.com', 'D', now() - interval '3 days'
  FROM generate_series(1, 30) i;
SELECT rls_is((SELECT count(*) FROM public.server_invites WHERE from_email = 'dario@example.com' AND at > now() - interval '1 hour'),
  30, 'at scritto dal client');
SELECT rls_expect($q$INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
  VALUES (rls_iid('dario@example.com', 'q31@example.com', 'https://k.example.com'), 'q31@example.com', 'dario@example.com', 'https://k.example.com', 'D')$q$, '42501', 'il trentunesimo invito');
INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
  VALUES (rls_iid('dario@example.com', 'q1@example.com', 'https://k.example.com'), 'q1@example.com', 'dario@example.com', 'https://k.example.com', 'D2')
  ON CONFLICT (id) DO UPDATE SET url = EXCLUDED.url, server_name = EXCLUDED.server_name;
SELECT rls_is((SELECT count(*) FROM public.server_invites WHERE id = rls_iid('dario@example.com', 'q1@example.com', 'https://k.example.com')
  AND server_name = 'D2'), 1, 'rinnovo di un invito');
SELECT rls_expect($q$UPDATE public.server_invites SET to_email = 'altro@example.com' WHERE id = rls_iid('dario@example.com', 'q1@example.com', 'https://k.example.com')$q$, '42501', 'destinatario cambiato');
UPDATE public.server_invites SET at = now() + interval '10 years' WHERE id = rls_iid('dario@example.com', 'q2@example.com', 'https://k.example.com');
SELECT rls_is((SELECT count(*) FROM public.server_invites WHERE id = rls_iid('dario@example.com', 'q2@example.com', 'https://k.example.com') AND at < now() + interval '1 day'), 1, 'at cambiato in update');

SELECT rls_expect($q$INSERT INTO public.drive_shares (id, to_email, from_email, folder_id, folder_name, permission_id)
  SELECT rls_share_id('dario@example.com', 'q' || i || '@example.com', 'F'), 'q' || i || '@example.com', 'dario@example.com', 'F', 'M', 'P'
  FROM generate_series(1, 31) i$q$, '42501', '31 condivisioni in un giorno');
INSERT INTO public.drive_shares (id, to_email, from_email, folder_id, folder_name, permission_id, at)
  SELECT rls_share_id('dario@example.com', 'q' || i || '@example.com', 'F'), 'q' || i || '@example.com', 'dario@example.com', 'F', 'M', 'P',
    now() - interval '3 days'
  FROM generate_series(1, 30) i;
SELECT rls_is((SELECT count(*) FROM public.drive_shares WHERE from_email = 'dario@example.com' AND at > now() - interval '1 hour'),
  30, 'at delle condivisioni scritto dal client');
SELECT rls_expect($q$INSERT INTO public.drive_shares (id, to_email, from_email, folder_id, folder_name, permission_id)
  VALUES (rls_share_id('dario@example.com', 'q31@example.com', 'F'), 'q31@example.com', 'dario@example.com', 'F', 'M', 'P')$q$,
  '42501', 'la trentunesima condivisione');
INSERT INTO public.drive_shares (id, to_email, from_email, folder_id, folder_name, permission_id)
  VALUES (rls_share_id('dario@example.com', 'q1@example.com', 'F'), 'q1@example.com', 'dario@example.com', 'F', 'M', 'P2')
  ON CONFLICT (id) DO UPDATE SET permission_id = EXCLUDED.permission_id, at = EXCLUDED.at;
SELECT rls_is((SELECT count(*) FROM public.drive_shares WHERE permission_id = 'P2'), 1, 'rinnovo di una condivisione');
UPDATE public.drive_shares SET at = now() + interval '10 years' WHERE permission_id = 'P2';
SELECT rls_is((SELECT count(*) FROM public.drive_shares WHERE permission_id = 'P2' AND at < now() + interval '1 day'), 1,
  'at cambiato in update di una condivisione');
RESET ROLE;
DROP FUNCTION public.rls_share_id(text, text, text);

-- T4: tetto di 16 MiB su readers.data. L'id di una riga è l'uid del proprietario (0012): una riga sola per owner.
SELECT rls_as('fede');
INSERT INTO public.readers (id, owner, data) VALUES (rls_u('fede')::text, rls_u('fede'), jsonb_build_object('p', repeat('a', 1024 * 1024)));
SELECT rls_expect($q$UPDATE public.readers SET data = jsonb_build_object('p', repeat('a', 17 * 1024 * 1024)) WHERE owner = rls_u('fede')$q$,
  '23514', 'aggiornamento di readers a 17 MiB');
UPDATE public.readers SET data = jsonb_build_object('p', repeat('a', 15 * 1024 * 1024)) WHERE owner = rls_u('fede');
SELECT rls_expect($q$INSERT INTO public.readers (id, owner, data) VALUES ('fede-2', rls_u('fede'), '{}')$q$, '23514', 'riga di readers con un id che non è il suo uid');
SELECT rls_expect($q$INSERT INTO public.readers (id, owner, data) VALUES (rls_u('fede')::text, rls_u('fede'), '{}')$q$, '23505', 'seconda riga di readers');
INSERT INTO public.readers (id, owner, data) VALUES (rls_u('fede')::text, rls_u('fede'), '{"revision": "2"}')
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;
SELECT rls_is((SELECT count(*) FROM public.readers WHERE owner = rls_u('fede')), 1, 'righe di readers dopo il rinnovo');
-- Chi occupa l'id di un altro non gli blocca il backup: la riga non nasce.
SELECT rls_expect($q$INSERT INTO public.readers (id, owner, data) VALUES (rls_u('alice')::text, rls_u('fede'), '{}')$q$, '23514', 'fede occupa la riga di alice');
SELECT rls_expect($q$INSERT INTO public.readers (id, owner, data) VALUES (rls_u('bob')::text, rls_u('fede'), '{}')
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data$q$, '23514', 'fede riscrive la riga di bob');
RESET ROLE;

-- Matrice per tabella (F8.2, punti 2 e 7): ogni tabella di public × chi agisce × ciò che prova a fare.
-- Un'operazione = una cella: rls_cell la esegue come quel ruolo, in una sottotransazione che si annulla
-- (le celle non si influenzano), e dice quante righe ha toccato o il codice che l'ha respinta; `x` è
-- 42501, che sul filo è sia «permesso negato» sia «regola violata». Le attese stanno sotto, una riga
-- per operazione, una colonna per chi agisce: A, B, K, O, R. anon non ha niente: è `x` ovunque.
--   A  ha un profilo aperto; B un altro lettore, mai bloccato; K è bloccato da A;
--   O  è «A col social spento»: l'accesso c'è, il profilo no;
--   R  è A che guarda il profilo ristretto di R (audience `mutual`, A non lo segue né è seguito).
-- {me} e {tgt} sono chi agisce e «l'altro» (B per A, A per B e per K, B per O, R per la colonna R);
-- {meE} e {tgtE} i loro indirizzi. Il «tentativo di scrivere a nome di un altro» è ogni riga `Spoof`
-- e `Take` (id preso con un upsert); il cambio di quelle colonne con un update è `updSpoof`.
CREATE FUNCTION public.rls_m(n int) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
  SELECT ('00000000-0000-4000-8000-0000000a000' || n)::uuid
$$;
CREATE FUNCTION public.rls_sid(from_email text, to_email text, folder text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT substr(encode(sha256(convert_to(from_email || '|' || to_email || '|' || folder, 'UTF8')), 'hex'), 1, 32)
$$;
CREATE FUNCTION public.rls_cell(r text, uid uuid, stmt text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE n bigint; res text;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE WHEN r = 'anon' THEN '' ELSE
    json_build_object('sub', uid, 'role', 'authenticated')::text END, true);
  PERFORM set_config('role', r, true);
  BEGIN
    EXECUTE stmt;
    GET DIAGNOSTICS n = ROW_COUNT;
    RAISE EXCEPTION 'annulla' USING ERRCODE = 'RLS00';
  EXCEPTION
    WHEN SQLSTATE 'RLS00' THEN res := n::text;
    WHEN OTHERS THEN res := CASE SQLSTATE WHEN '42501' THEN 'x' ELSE SQLSTATE END;
  END;
  PERFORM set_config('role', 'none', true);
  RETURN res;
END $$;

-- Gli attori della matrice: anon e le cinque colonne.
CREATE TEMP TABLE rls_actors AS SELECT * FROM (VALUES
  (0, 'anon', 'anon', 1, 2), (1, 'A', 'authenticated', 1, 2), (2, 'B', 'authenticated', 2, 1),
  (3, 'K', 'authenticated', 3, 1), (4, 'O', 'authenticated', 4, 2), (5, 'R', 'authenticated', 1, 5)
) t(pos, name, role, me, tgt);

INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data)
  SELECT rls_m(n), 'm' || n || '@m.test', now(), '{"providers": ["google"]}' FROM generate_series(1, 7) n;
-- 1 A, 2 B, 3 K, 4 O (senza profilo), 5 R (ristretto), 6 C (ristretto ma accetta messaggi), 7 H (serie nascoste)
INSERT INTO public.profiles (id, name, audience, messages, series, activity, week_id, month_id)
  SELECT rls_m(n), 'Mm' || n, CASE WHEN n IN (5, 6) THEN 'mutual' ELSE 'everyone' END,
    CASE n WHEN 5 THEN 'nobody' ELSE 'everyone' END,
    CASE WHEN n = 7 THEN NULL ELSE '[{"title": "S", "chapters": 3}]'::jsonb END,
    CASE WHEN n = 7 THEN NULL ELSE '[0,0,0,0,0,0,0,0,0,0,0,0,0,1]'::jsonb END, '2026-W46', '2026-11'
  FROM generate_series(1, 7) n WHERE n <> 4;
INSERT INTO public.follows (follower, followee, follower_name) VALUES
  (rls_m(1), rls_m(2), 'Mm1'), (rls_m(2), rls_m(1), 'Mm2'), (rls_m(5), rls_m(2), 'Mm5'), (rls_m(2), rls_m(5), 'Mm2');
INSERT INTO public.blocks (blocker, blocked) VALUES (rls_m(1), rls_m(3));
INSERT INTO public.posts (author, body) SELECT rls_m(n), 'p-' || chr(96 + n) FROM generate_series(1, 3) n;
INSERT INTO public.posts (author, body) VALUES (rls_m(5), 'p-r'), (rls_m(6), 'p-c');
INSERT INTO public.comments (post, author, body)
  SELECT rls_post('p-b'), rls_m(n), 'c-' || n FROM unnest(ARRAY[1, 2, 3, 5]) n;
INSERT INTO public.likes (uid, post) SELECT rls_m(n), rls_post('p-b') FROM generate_series(1, 3) n;
INSERT INTO public.messages (sender, recipient, body) VALUES
  (rls_m(1), rls_m(2), 'hello'), (rls_m(2), rls_m(1), 'ciao'), (rls_m(5), rls_m(2), 'da r');
INSERT INTO public.readers (id, owner) SELECT rls_m(n)::text, rls_m(n) FROM generate_series(1, 5) n;
INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
  SELECT rls_iid('m' || n || '@m.test', 'zz@m.test', 'https://k.example'), 'zz@m.test', 'm' || n || '@m.test', 'https://k.example', 'S' FROM generate_series(1, 5) n;
INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
  VALUES (rls_iid('m2@m.test', 'm1@m.test', 'https://k.example'), 'm1@m.test', 'm2@m.test', 'https://k.example', 'S');
INSERT INTO public.drive_shares (id, to_email, from_email, from_uid, folder_id, folder_name, permission_id)
  SELECT rls_sid('m' || n || '@m.test', t, 'F'), t, 'm' || n || '@m.test', rls_m(n), 'F', 'F', 'P'
  FROM generate_series(1, 5) n, unnest(ARRAY['zz@m.test']) t;
INSERT INTO public.drive_shares (id, to_email, from_email, from_uid, folder_id, folder_name, permission_id)
  VALUES (rls_sid('m2@m.test', 'm1@m.test', 'F'), 'm1@m.test', 'm2@m.test', rls_m(2), 'F', 'F', 'P');

CREATE TEMP TABLE rls_cells (tbl text, op text, stmt text, expect text);
INSERT INTO rls_cells VALUES
  -- readers: l'id lo sceglie il client, quindi anche l'upsert su un id altrui (Take)
  ('readers', 'selOwn',   $q$SELECT * FROM public.readers WHERE owner = '{me}'$q$, '1 1 1 1 1'),
  ('readers', 'selTgt',   $q$SELECT * FROM public.readers WHERE owner = '{tgt}'$q$, '0 0 0 0 0'),
  ('readers', 'insOwn',   $q$INSERT INTO public.readers (id, owner) VALUES ('{me}', '{me}')
                            ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data$q$, '1 1 1 1 1'),
  ('readers', 'insSpoof', $q$INSERT INTO public.readers (id, owner) VALUES ('{me}', '{tgt}')$q$, 'x x x x x'),
  ('readers', 'insSquat', $q$INSERT INTO public.readers (id, owner) VALUES ('{tgt}', '{me}')$q$, '23514 23514 23514 23514 23514'),
  ('readers', 'insTake',  $q$INSERT INTO public.readers (id, owner) VALUES ('{tgt}', '{me}')
                            ON CONFLICT (id) DO UPDATE SET owner = EXCLUDED.owner$q$, '23514 23514 23514 23514 23514'),
  ('readers', 'updOwn',   $q$UPDATE public.readers SET data = '{"a": 1}' WHERE owner = '{me}'$q$, '1 1 1 1 1'),
  ('readers', 'updTgt',   $q$UPDATE public.readers SET data = '{"a": 1}' WHERE owner = '{tgt}'$q$, '0 0 0 0 0'),
  ('readers', 'updSpoof', $q$UPDATE public.readers SET owner = '{tgt}' WHERE owner = '{me}'$q$, 'x x x x x'),
  ('readers', 'delOwn',   $q$DELETE FROM public.readers WHERE owner = '{me}'$q$, '1 1 1 1 1'),
  ('readers', 'delTgt',   $q$DELETE FROM public.readers WHERE owner = '{tgt}'$q$, '0 0 0 0 0'),
  -- server_invites: legge chi manda e chi riceve (B ha mandato un invito ad A); l'indirizzo c'è anche senza profilo
  ('server_invites', 'selOwn',   $q$SELECT * FROM public.server_invites WHERE from_email = '{meE}'$q$, '1 2 1 1 1'),
  ('server_invites', 'selTgt',   $q$SELECT * FROM public.server_invites WHERE from_email = '{tgtE}'$q$, '1 0 0 0 0'),
  ('server_invites', 'insOwn',   $q$INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
                                   VALUES (rls_iid('{meE}', 'y@m.test', 'https://k.example'), 'y@m.test', '{meE}', 'https://k.example', 'S')$q$, '1 1 1 1 1'),
  -- l'id dell'invito che l'altro scriverebbe (0014): chi arriva prima non lo occupa
  ('server_invites', 'insSquat', $q$INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
                                   VALUES (rls_iid('{tgtE}', 'y@m.test', 'https://k.example'), 'y@m.test', '{meE}', 'https://k.example', 'S')$q$,
                                   '23514 23514 23514 23514 23514'),
  ('server_invites', 'insSpoof', $q$INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
                                   VALUES ('n-{me}', 'y@m.test', '{tgtE}', 'https://k.example', 'S')$q$, 'x x x x x'),
  ('server_invites', 'insTake',  $q$INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
                                   VALUES (rls_iid('{tgtE}', 'zz@m.test', 'https://k.example'), 'zz@m.test', '{meE}', 'https://k.example', 'S')
                                   ON CONFLICT (id) DO UPDATE SET url = EXCLUDED.url$q$, '23514 23514 23514 23514 23514'),
  ('server_invites', 'updOwn',   $q$UPDATE public.server_invites SET server_name = 'N' WHERE from_email = '{meE}'$q$, '1 2 1 1 1'),
  ('server_invites', 'updTgt',   $q$UPDATE public.server_invites SET server_name = 'N' WHERE from_email = '{tgtE}'$q$, '0 0 0 0 0'),
  ('server_invites', 'updSpoof', $q$UPDATE public.server_invites SET from_email = '{tgtE}' WHERE from_email = '{meE}'$q$, 'x x x x x'),
  ('server_invites', 'delOwn',   $q$DELETE FROM public.server_invites WHERE from_email = '{meE}'$q$, '1 2 1 1 1'),
  ('server_invites', 'delTgt',   $q$DELETE FROM public.server_invites WHERE from_email = '{tgtE}'$q$, '1 0 0 0 0'),
  -- drive_shares: legge chi manda e chi riceve, scrive e toglie solo chi manda
  ('drive_shares', 'selOwn',   $q$SELECT * FROM public.drive_shares WHERE from_email = '{meE}'$q$, '1 2 1 1 1'),
  ('drive_shares', 'selTgt',   $q$SELECT * FROM public.drive_shares WHERE from_email = '{tgtE}'$q$, '1 0 0 0 0'),
  ('drive_shares', 'insOwn',   $q$INSERT INTO public.drive_shares (id, to_email, from_email, from_uid, folder_id, folder_name, permission_id)
                                 VALUES (rls_sid('{meE}', 'y@m.test', 'G'), 'y@m.test', '{meE}', '{me}', 'G', 'G', 'P')$q$, '1 1 1 1 1'),
  ('drive_shares', 'insSpoof', $q$INSERT INTO public.drive_shares (id, to_email, from_email, from_uid, folder_id, folder_name, permission_id)
                                 VALUES (rls_sid('{tgtE}', 'y@m.test', 'G'), 'y@m.test', '{tgtE}', '{me}', 'G', 'G', 'P')$q$, 'x x x x x'),
  ('drive_shares', 'insSpoofUid', $q$INSERT INTO public.drive_shares (id, to_email, from_email, from_uid, folder_id, folder_name, permission_id)
                                 VALUES (rls_sid('{meE}', 'y@m.test', 'G'), 'y@m.test', '{meE}', '{tgt}', 'G', 'G', 'P')$q$, 'x x x x x'),
  ('drive_shares', 'updOwn',   $q$UPDATE public.drive_shares SET folder_name = 'N' WHERE from_email = '{meE}'$q$, '1 2 1 1 1'),
  ('drive_shares', 'updTgt',   $q$UPDATE public.drive_shares SET folder_name = 'N' WHERE from_email = '{tgtE}'$q$, '0 0 0 0 0'),
  ('drive_shares', 'updDownload', $q$UPDATE public.drive_shares SET download = true WHERE from_email = '{tgtE}'$q$, '0 0 0 0 0'),
  ('drive_shares', 'updSpoof', $q$UPDATE public.drive_shares SET from_uid = '{tgt}' WHERE from_email = '{meE}'$q$, 'x x x x x'),
  ('drive_shares', 'updSpoofE', $q$UPDATE public.drive_shares SET from_email = '{tgtE}' WHERE from_email = '{meE}'$q$, 'x x x x x'),
  ('drive_shares', 'delOwn',   $q$DELETE FROM public.drive_shares WHERE from_email = '{meE}'$q$, '1 2 1 1 1'),
  ('drive_shares', 'delTgt',   $q$DELETE FROM public.drive_shares WHERE from_email = '{tgtE}'$q$, '0 0 0 0 0'),
  -- profiles: il profilo di R non lo vede A; chi ha il social spento (O) può crearlo di nuovo
  ('profiles', 'selOwn',   $q$SELECT * FROM public.profiles WHERE id = '{me}'$q$, '1 1 1 0 1'),
  ('profiles', 'selTgt',   $q$SELECT * FROM public.profiles WHERE id = '{tgt}'$q$, '1 1 0 0 0'),
  ('profiles', 'insOwn',   $q$INSERT INTO public.profiles (id, name, week_id, month_id) VALUES ('{me}', 'Nome', '2026-W46', '2026-11')$q$,
                           '23505 23505 23505 1 23505'),
  ('profiles', 'insSpoof', $q$INSERT INTO public.profiles (id, name, week_id, month_id) VALUES ('{tgt}', 'Nome', '2026-W46', '2026-11')$q$, 'x x x x x'),
  ('profiles', 'updOwn',   $q$UPDATE public.profiles SET bio = 'b' WHERE id = '{me}'$q$, '1 1 1 0 1'),
  ('profiles', 'updTgt',   $q$UPDATE public.profiles SET bio = 'b' WHERE id = '{tgt}'$q$, '0 0 0 0 0'),
  ('profiles', 'updSpoof', $q$UPDATE public.profiles SET id = '{tgt}' WHERE id = '{me}'$q$, 'x x x 0 x'),
  ('profiles', 'updBackend', $q$UPDATE public.profiles SET updated_at = now() WHERE id = '{me}'$q$, 'x x x x x'),
  ('profiles', 'delOwn',   $q$DELETE FROM public.profiles WHERE id = '{me}'$q$, '1 1 1 0 1'),
  ('profiles', 'delTgt',   $q$DELETE FROM public.profiles WHERE id = '{tgt}'$q$, '0 0 0 0 0'),
  -- follows: scrive solo chi segue (e solo il nome); toglie chi segue e chi è seguito
  ('follows', 'selOwn',   $q$SELECT * FROM public.follows WHERE follower = '{me}'$q$, '1 2 0 0 1'),
  ('follows', 'selTgt',   $q$SELECT * FROM public.follows WHERE follower = '{tgt}'$q$, '1 1 0 0 0'),
  ('follows', 'insOwn',   $q$INSERT INTO public.follows (follower, followee, follower_name) VALUES ('{me}', '{tgt}', 'Nome')$q$,
                          '23505 23505 x 23503 1'),
  ('follows', 'insSpoof', $q$INSERT INTO public.follows (follower, followee, follower_name) VALUES ('{tgt}', '{me}', 'Nome')$q$, 'x x x x x'),
  ('follows', 'updOwn',   $q$UPDATE public.follows SET follower_name = 'Altro' WHERE follower = '{me}'$q$, '1 2 0 0 1'),
  ('follows', 'updTgt',   $q$UPDATE public.follows SET follower_name = 'Altro' WHERE follower = '{tgt}'$q$, '0 0 0 0 0'),
  ('follows', 'updSpoof', $q$UPDATE public.follows SET follower = '{tgt}' WHERE follower = '{me}'$q$, 'x x x x x'),
  ('follows', 'delOwn',   $q$DELETE FROM public.follows WHERE follower = '{me}'$q$, '1 2 0 0 1'),
  ('follows', 'delTgt',   $q$DELETE FROM public.follows WHERE follower = '{tgt}'$q$, '1 1 0 0 0'),
  -- blocks: solo i propri, e solo con un profilo; non si cambiano
  ('blocks', 'selOwn',   $q$SELECT * FROM public.blocks WHERE blocker = '{me}'$q$, '1 0 0 0 1'),
  ('blocks', 'selTgt',   $q$SELECT * FROM public.blocks WHERE blocker = '{tgt}'$q$, '0 0 0 0 0'),
  ('blocks', 'insOwn',   $q$INSERT INTO public.blocks (blocker, blocked) VALUES ('{me}', '{tgt}')$q$, '1 1 1 x 1'),
  ('blocks', 'insSpoof', $q$INSERT INTO public.blocks (blocker, blocked) VALUES ('{tgt}', '{me}')$q$, 'x x x x x'),
  ('blocks', 'updOwn',   $q$UPDATE public.blocks SET blocked = '{tgt}' WHERE blocker = '{me}'$q$, 'x x x x x'),
  ('blocks', 'updSpoof', $q$UPDATE public.blocks SET blocker = '{tgt}' WHERE blocker = '{me}'$q$, 'x x x x x'),
  ('blocks', 'delOwn',   $q$DELETE FROM public.blocks WHERE blocker = '{me}'$q$, '1 0 0 0 1'),
  ('blocks', 'delTgt',   $q$DELETE FROM public.blocks WHERE blocker = '{tgt}'$q$, '0 0 0 0 0'),
  -- posts: li vede chi vede l'autore; non si modificano
  ('posts', 'selOwn',   $q$SELECT * FROM public.posts WHERE author = '{me}'$q$, '1 1 1 0 1'),
  ('posts', 'selTgt',   $q$SELECT * FROM public.posts WHERE author = '{tgt}'$q$, '1 1 0 0 0'),
  ('posts', 'insOwn',   $q$INSERT INTO public.posts (author, body) VALUES ('{me}', 'x')$q$, '1 1 1 23503 1'),
  ('posts', 'insSpoof', $q$INSERT INTO public.posts (author, body) VALUES ('{tgt}', 'x')$q$, 'x x x x x'),
  ('posts', 'updOwn',   $q$UPDATE public.posts SET body = 'y' WHERE author = '{me}'$q$, 'x x x x x'),
  ('posts', 'updSpoof', $q$UPDATE public.posts SET author = '{tgt}' WHERE author = '{me}'$q$, 'x x x x x'),
  ('posts', 'delOwn',   $q$DELETE FROM public.posts WHERE author = '{me}'$q$, '1 1 1 0 1'),
  ('posts', 'delTgt',   $q$DELETE FROM public.posts WHERE author = '{tgt}'$q$, '0 0 0 0 0'),
  -- comments: tutti commentano sotto p-b (di B); il padrone del post toglie anche i commenti altrui
  ('comments', 'selOwn',   $q$SELECT * FROM public.comments WHERE author = '{me}'$q$, '1 1 1 0 1'),
  ('comments', 'selTgt',   $q$SELECT * FROM public.comments WHERE author = '{tgt}'$q$, '1 1 0 0 1'),
  ('comments', 'insOwn',   $q$INSERT INTO public.comments (post, author, body) VALUES (rls_post('p-b'), '{me}', 'c')$q$, '1 1 1 x 1'),
  ('comments', 'insHidden', $q$INSERT INTO public.comments (post, author, body) VALUES (rls_post('p-r'), '{me}', 'c')$q$, 'x 1 x x x'),
  ('comments', 'insSpoof', $q$INSERT INTO public.comments (post, author, body) VALUES (rls_post('p-b'), '{tgt}', 'c')$q$, 'x x x x x'),
  ('comments', 'updOwn',   $q$UPDATE public.comments SET body = 'y' WHERE author = '{me}'$q$, 'x x x x x'),
  ('comments', 'updSpoof', $q$UPDATE public.comments SET author = '{tgt}' WHERE author = '{me}'$q$, 'x x x x x'),
  ('comments', 'delOwn',   $q$DELETE FROM public.comments WHERE author = '{me}'$q$, '1 1 1 0 1'),
  ('comments', 'delTgt',   $q$DELETE FROM public.comments WHERE author = '{tgt}'$q$, '0 1 0 0 0'),
  -- likes: li legge solo chi li ha messi
  ('likes', 'selOwn',   $q$SELECT * FROM public.likes WHERE uid = '{me}'$q$, '1 1 1 0 1'),
  ('likes', 'selTgt',   $q$SELECT * FROM public.likes WHERE uid = '{tgt}'$q$, '0 0 0 0 0'),
  ('likes', 'insOwn',   $q$INSERT INTO public.likes (uid, post) VALUES ('{me}', rls_post('p-a'))$q$, '1 1 x x 1'),
  ('likes', 'insSpoof', $q$INSERT INTO public.likes (uid, post) VALUES ('{tgt}', rls_post('p-a'))$q$, 'x x x x x'),
  ('likes', 'updOwn',   $q$UPDATE public.likes SET post = NULL WHERE uid = '{me}'$q$, 'x x x x x'),
  ('likes', 'updSpoof', $q$UPDATE public.likes SET uid = '{tgt}' WHERE uid = '{me}'$q$, 'x x x x x'),
  ('likes', 'delOwn',   $q$DELETE FROM public.likes WHERE uid = '{me}'$q$, '1 1 1 0 1'),
  ('likes', 'delTgt',   $q$DELETE FROM public.likes WHERE uid = '{tgt}'$q$, '0 0 0 0 0'),
  -- messages: li vedono i due; si scrive a chi accetta e non ha bloccato; del messaggio cambia solo read_at (il destinatario)
  ('messages', 'selOwn',   $q$SELECT * FROM public.messages WHERE sender = '{me}'$q$, '1 1 0 0 1'),
  ('messages', 'selTgt',   $q$SELECT * FROM public.messages WHERE sender = '{tgt}'$q$, '1 1 0 0 0'),
  ('messages', 'insOwn',   $q$INSERT INTO public.messages (sender, recipient, body) VALUES ('{me}', '{tgt}', 'x')$q$, '1 1 x 23503 x'),
  ('messages', 'insSpoof', $q$INSERT INTO public.messages (sender, recipient, body) VALUES ('{tgt}', '{me}', 'x')$q$, 'x x x x x'),
  ('messages', 'updOwn',   $q$UPDATE public.messages SET read_at = now() WHERE recipient = '{me}'$q$, '1 2 0 0 1'),
  ('messages', 'updTgt',   $q$UPDATE public.messages SET read_at = now() WHERE recipient = '{tgt}'$q$, '0 0 0 0 0'),
  ('messages', 'updSpoof', $q$UPDATE public.messages SET recipient = '{tgt}' WHERE recipient = '{me}'$q$, 'x x x x x'),
  ('messages', 'updSpoofS', $q$UPDATE public.messages SET sender = '{tgt}' WHERE sender = '{me}'$q$, 'x x x x x'),
  ('messages', 'delOwn',   $q$DELETE FROM public.messages WHERE sender = '{me}'$q$, '1 1 0 0 1'),
  ('messages', 'delTgt',   $q$DELETE FROM public.messages WHERE sender = '{tgt}'$q$, '1 1 0 0 0'),
  -- reports: si scrivono e basta
  ('reports', 'selOwn',   $q$SELECT * FROM public.reports WHERE reporter = '{me}'$q$, 'x x x x x'),
  ('reports', 'selTgt',   $q$SELECT * FROM public.reports WHERE reporter = '{tgt}'$q$, 'x x x x x'),
  ('reports', 'insOwn',   $q$INSERT INTO public.reports (reporter, target, target_user, reason) VALUES ('{me}', 'user', '{tgt}', 'spam')$q$,
                           '1 1 1 x 1'),
  ('reports', 'insSpoof', $q$INSERT INTO public.reports (reporter, target, target_user, reason) VALUES ('{tgt}', 'user', '{me}', 'spam')$q$, 'x x x x x'),
  ('reports', 'insNoOwner', $q$INSERT INTO public.reports (reporter, target, target_user, reason) VALUES (NULL, 'user', '{tgt}', 'spam')$q$, 'x x x x x'),
  ('reports', 'updOwn',   $q$UPDATE public.reports SET note = 'y' WHERE reporter = '{me}'$q$, 'x x x x x'),
  ('reports', 'updSpoof', $q$UPDATE public.reports SET reporter = '{tgt}' WHERE reporter = '{me}'$q$, 'x x x x x'),
  ('reports', 'delOwn',   $q$DELETE FROM public.reports WHERE reporter = '{me}'$q$, 'x x x x x'),
  -- server_tickets: nessuno la tocca a mano, solo kagami_ticket e kagami_ticket_who (F8.6)
  ('server_tickets', 'selOwn', $q$SELECT * FROM public.server_tickets WHERE uid = '{me}'$q$, 'x x x x x'),
  ('server_tickets', 'selTgt', $q$SELECT * FROM public.server_tickets WHERE uid = '{tgt}'$q$, 'x x x x x'),
  ('server_tickets', 'insOwn', $q$INSERT INTO public.server_tickets (hash, uid, email, audience, expires_at)
                                 VALUES ('\x00', '{me}', '{meE}', repeat('a', 32), now())$q$, 'x x x x x'),
  ('server_tickets', 'updOwn', $q$UPDATE public.server_tickets SET expires_at = now() WHERE uid = '{me}'$q$, 'x x x x x'),
  ('server_tickets', 'delOwn', $q$DELETE FROM public.server_tickets WHERE uid = '{me}'$q$, 'x x x x x'),
  -- server_origins: solo kagami_server_origin e kagami_ticket_who (0013)
  ('server_origins', 'selOwn', $q$SELECT * FROM public.server_origins WHERE uid = '{me}'$q$, 'x x x x x'),
  ('server_origins', 'insOwn', $q$INSERT INTO public.server_origins (audience, origin, uid, email)
                                 VALUES (repeat('a', 32), 'https://k.example', '{me}', '{meE}')$q$, 'x x x x x'),
  ('server_origins', 'updOwn', $q$UPDATE public.server_origins SET origin = 'https://m.example' WHERE uid = '{me}'$q$, 'x x x x x'),
  ('server_origins', 'delOwn', $q$DELETE FROM public.server_origins WHERE uid = '{me}'$q$, 'x x x x x');

-- Esegue ogni cella per ogni attore e raccoglie gli scarti, tutti insieme.
DO $$
DECLARE c record; a record; got text; want text; bad text := ''; cells int := 0; missing text;
BEGIN
  SELECT string_agg(t.relname, ', ') INTO missing FROM pg_class t
    WHERE t.relnamespace = 'public'::regnamespace AND t.relkind = 'r' AND t.relname !~ '^rls_'
      AND NOT EXISTS (SELECT 1 FROM rls_cells x WHERE x.tbl = t.relname);
  IF missing IS NOT NULL THEN RAISE EXCEPTION 'matrice: nessun caso per %', missing; END IF;
  FOR c IN SELECT * FROM rls_cells LOOP
    FOR a IN SELECT * FROM rls_actors LOOP
      got := public.rls_cell(a.role, rls_m(a.me), replace(replace(replace(replace(c.stmt,
        '{me}', rls_m(a.me)::text), '{tgt}', rls_m(a.tgt)::text),
        '{meE}', 'm' || a.me || '@m.test'), '{tgtE}', 'm' || a.tgt || '@m.test'));
      want := CASE WHEN a.pos = 0 THEN 'x' ELSE split_part(c.expect, ' ', a.pos) END;
      cells := cells + 1;
      IF got IS DISTINCT FROM want THEN
        bad := bad || format(E'\n  %s %s come %s: %s invece di %s', c.tbl, c.op, a.name, got, want);
      END IF;
    END LOOP;
  END LOOP;
  IF bad <> '' THEN RAISE EXCEPTION 'matrice:%', bad; END IF;
  IF cells < 600 THEN RAISE EXCEPTION 'matrice: solo % celle', cells; END IF;
END $$;

-- T7. Ciò che non si deve leggere né scrivere, per ogni colonna: A guarda il profilo ristretto di R, K guarda
-- chi lo ha bloccato, O (senza profilo) guarda B; la serie nascosta è la colonna a NULL di H (l'app non
-- manda al backend ciò che l'utente nasconde), e nessun altro la scrive. Le colonne si leggono dal catalogo:
-- una colonna nuova entra da sola. Vale per `profiles` e `posts`, i cui contatori (likes, comments, flags)
-- e i cui totali sono i «numeri»; una colonna generata si rifiuta già al parse (428C9), e comunque non è concessa.
DO $$
DECLARE col record; bad text := ''; checked int := 0;
  closed text; h text := rls_m(7)::text;
BEGIN
  FOR col IN SELECT c.relname AS tbl, a.attname AS name,
      has_column_privilege('authenticated', c.oid, a.attnum, 'UPDATE') AS can_update, a.attgenerated <> '' AS generated
    FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
    WHERE c.relnamespace = 'public'::regnamespace AND c.relname IN ('profiles', 'posts') AND a.attnum > 0 AND NOT a.attisdropped
      AND has_column_privilege('authenticated', c.oid, a.attnum, 'SELECT')
  LOOP
    closed := CASE col.tbl WHEN 'profiles' THEN 'id' ELSE 'author' END;
    checked := checked + 1;
    IF public.rls_cell('authenticated', rls_m(1), format('SELECT %I FROM public.%I WHERE %I = %L', col.name, col.tbl, closed, rls_m(5))) <> '0'
      THEN bad := bad || format(E'\n  %s.%s: A legge il profilo ristretto', col.tbl, col.name); END IF;
    IF public.rls_cell('authenticated', rls_m(3), format('SELECT %I FROM public.%I WHERE %I = %L', col.name, col.tbl, closed, rls_m(1))) <> '0'
      THEN bad := bad || format(E'\n  %s.%s: K legge chi lo ha bloccato', col.tbl, col.name); END IF;
    IF public.rls_cell('authenticated', rls_m(4), format('SELECT %I FROM public.%I WHERE %I = %L', col.name, col.tbl, closed, rls_m(2))) <> '0'
      THEN bad := bad || format(E'\n  %s.%s: O legge senza profilo', col.tbl, col.name); END IF;
    IF col.tbl = 'profiles' THEN
      IF public.rls_cell('authenticated', rls_m(2), format('SELECT %I FROM public.profiles WHERE id = %L', col.name, h)) <> '1'
        THEN bad := bad || format(E'\n  profiles.%s: B non legge H, che è aperto', col.name); END IF;
      IF public.rls_cell('authenticated', rls_m(2), format('UPDATE public.profiles SET %1$I = %1$I WHERE id = %2$L', col.name, h))
          IS DISTINCT FROM (CASE WHEN col.generated THEN '428C9' WHEN col.can_update THEN '0' ELSE 'x' END)
        THEN bad := bad || format(E'\n  profiles.%s: B scrive sul profilo di H', col.name); END IF;
    END IF;
  END LOOP;
  IF checked < 30 THEN RAISE EXCEPTION 'T7: solo % colonne', checked; END IF;
  IF bad <> '' THEN RAISE EXCEPTION 'T7:%', bad; END IF;
END $$;

-- La serie nascosta è NULL e resta NULL per chi guarda; un `null` JSON non è NULL e non passa.
DO $$
DECLARE got text;
BEGIN
  got := public.rls_cell('authenticated', rls_m(2), format('SELECT * FROM public.profiles WHERE id = %L AND series IS NULL AND activity IS NULL', rls_m(7)));
  IF got <> '1' THEN RAISE EXCEPTION 'serie nascosta di H: %', got; END IF;
  got := public.rls_cell('authenticated', rls_m(7), format('UPDATE public.profiles SET series = %L::jsonb WHERE id = %L', 'null', rls_m(7)));
  IF got <> '23514' THEN RAISE EXCEPTION 'series = null JSON: %', got; END IF;
  got := public.rls_cell('authenticated', rls_m(7), format('UPDATE public.profiles SET series = NULL WHERE id = %L', rls_m(7)));
  IF got <> '1' THEN RAISE EXCEPTION 'nascondere la serie: %', got; END IF;
END $$;

-- Le funzioni che rispondono con un valore, chiamate a mano via RPC da chi vuole leggere ciò che le tabelle gli
-- nascondono. Rispondono solo di auth.uid(): chi non è uno dei due di un blocco ottiene NULL.
CREATE FUNCTION public.rls_val(uid uuid, expr text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE res text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  EXECUTE format('SELECT coalesce((SELECT public.%s)::text, ''NULL'')', expr) INTO res;
  PERFORM set_config('role', 'none', true);
  RETURN res;
END $$;
DO $$
DECLARE bad text := ''; got text; c text[];
BEGIN
  FOREACH c SLICE 1 IN ARRAY ARRAY[
    -- chi guarda (1 A, 2 B, 3 K, 4 O), funzione, atteso
    ['1', 'kagami_sees(rls_m(5))', 'false'], ['1', 'kagami_sees(rls_m(3))', 'false'], ['1', 'kagami_sees(rls_m(7))', 'true'],
    ['2', 'kagami_sees(rls_m(1))', 'true'], ['3', 'kagami_sees(rls_m(1))', 'false'], ['4', 'kagami_sees(rls_m(2))', 'false'],
    ['1', 'kagami_blocked(rls_m(1), rls_m(3))', 'true'], ['3', 'kagami_blocked(rls_m(3), rls_m(1))', 'true'],
    ['2', 'kagami_blocked(rls_m(1), rls_m(3))', 'NULL'], ['2', 'kagami_blocked(rls_m(2), rls_m(1))', 'false'],
    ['1', 'kagami_accepts(rls_m(5))', 'false'], ['1', 'kagami_accepts(rls_m(4))', 'false'],
    ['1', 'kagami_me()', 'm1@m.test'], ['4', 'kagami_me()', 'm4@m.test']
  ] LOOP
    got := public.rls_val(rls_m(c[1]::int), c[2]);
    IF got <> c[3] THEN bad := bad || format(E'\n  %s come %s: %s invece di %s', c[2], c[1], got, c[3]); END IF;
  END LOOP;
  IF bad <> '' THEN RAISE EXCEPTION 'T7, funzioni:%', bad; END IF;
END $$;
-- R9: kagami_accepts(C) dice ad A che C esiste e accetta messaggi anche se il profilo di C è ristretto (audience
-- `mutual`) e per A non c'è. Lo stesso lo dice l'esito di un messaggio, e `messages` è indipendente da `audience`
-- per scelta di docs/social.md: se il proprietario vuole che un profilo ristretto non si lasci sondare, serve
-- una decisione di prodotto (accepts falso se kagami_sees è falso), non una correzione di passaggio.
--   SELECT public.rls_is((public.rls_val(rls_m(1), 'kagami_accepts(rls_m(6))') = 'false')::int, 1, 'R9: accepts su profilo ristretto');

-- «Profilo chiuso» e la vista dei seguiti: A segue C, che è ristretto e non lo segue: i post di C non arrivano.
INSERT INTO public.follows (follower, followee, follower_name) VALUES (rls_m(1), rls_m(6), 'Mm1');
DO $$
DECLARE got text;
BEGIN
  got := public.rls_cell('authenticated', rls_m(1), format('SELECT * FROM public.following_posts WHERE author = %L', rls_m(6)));
  IF got <> '0' THEN RAISE EXCEPTION 'following_posts mostra il post di un profilo ristretto: %', got; END IF;
  got := public.rls_cell('authenticated', rls_m(1), format('SELECT * FROM public.following_posts WHERE author = %L', rls_m(2)));
  IF got <> '1' THEN RAISE EXCEPTION 'following_posts non mostra il post di chi si vede: %', got; END IF;
  got := public.rls_cell('authenticated', rls_m(3), format('SELECT * FROM public.following_posts WHERE author = %L', rls_m(1)));
  IF got <> '0' THEN RAISE EXCEPTION 'following_posts: K vede i post di chi lo ha bloccato: %', got; END IF;
END $$;

-- Il realtime, per ciò che Postgres sa: quali tabelle entrano nella pubblicazione e con quale identità di riga.
-- Il servizio realtime applica le regole di lettura di chi è abbonato (quelle provate sopra: messages solo ai due,
-- invii e condivisioni solo a chi manda o riceve) e di una riga tolta manda la sola chiave. Come lo faccia davvero,
-- e se lo faccia su Hestia, non si vede da qui: va visto dal vivo con due account (R2).
DO $$
DECLARE published text; loose text;
BEGIN
  SELECT string_agg(tablename, ', ' ORDER BY tablename) INTO published FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public';
  IF published IS DISTINCT FROM 'drive_shares, messages, server_invites' THEN
    RAISE EXCEPTION 'realtime pubblica: % (attese drive_shares, messages, server_invites)', published;
  END IF;
  -- Identità `full` manderebbe a chi ascolta la riga intera di una cancellazione.
  SELECT string_agg(c.relname, ', ') INTO loose FROM pg_class c JOIN pg_publication_tables t
    ON t.tablename = c.relname AND t.schemaname = 'public' AND t.pubname = 'supabase_realtime'
    WHERE c.relnamespace = 'public'::regnamespace AND c.relreplident <> 'd';
  IF loose IS NOT NULL THEN RAISE EXCEPTION 'realtime: identità di riga non predefinita su %', loose; END IF;
END $$;

-- F8.6, T1: i biglietti per il Kagami Server. Li crea solo chi ha un indirizzo (kagami_me), valgono solo per
-- l'audience e fino al termine, e la risposta di kagami_ticket_who la dà solo ad anon (il server).
CREATE FUNCTION pg_temp.rls_call(r text, uid uuid, expr text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE res text;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE WHEN r = 'anon' THEN '' ELSE
    json_build_object('sub', uid, 'role', 'authenticated')::text END, true);
  PERFORM set_config('role', r, true);
  BEGIN
    EXECUTE format('SELECT coalesce((%s)::text, ''NULL'')', expr) INTO res;
  EXCEPTION WHEN OTHERS THEN res := 'E' || SQLSTATE;
  END;
  PERFORM set_config('role', 'none', true);
  RETURN res;
END $$;
DO $$
DECLARE
  v text := repeat('a', 32); m text := repeat('b', 32); t text; t2 text; got text; bad text := '';
  who text := '(SELECT email FROM public.kagami_ticket_who(%L, %L))';
BEGIN
  t := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_ticket(%L)', v));
  IF t !~ '^[0-9a-f]{96}$' THEN RAISE EXCEPTION 'biglietto: %', t; END IF;
  t2 := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_ticket(%L)', v));
  IF t2 = t THEN RAISE EXCEPTION 'due biglietti uguali'; END IF;
  IF (SELECT count(*) FROM public.server_tickets WHERE hash = convert_to(t, 'UTF8') OR encode(hash, 'hex') = t) > 0 THEN
    RAISE EXCEPTION 'il backend tiene il biglietto in chiaro';
  END IF;
  FOREACH got IN ARRAY ARRAY[
    -- ciò che si prova, atteso, separati da |
    format(who, t, v) || '|m1@m.test',
    format(who, t, m) || '|NULL',                         -- il biglietto per V non vale su M
    format(who, repeat('0', 96), v) || '|NULL',           -- inventato
    format(who, upper(t), v) || '|NULL',
    format(who, NULL, v) || '|NULL'
  ] LOOP
    IF pg_temp.rls_call('anon', NULL, split_part(got, '|', 1)) <> split_part(got, '|', 2) THEN
      bad := bad || format(E'\n  anon %s: %s', split_part(got, '|', 1), pg_temp.rls_call('anon', NULL, split_part(got, '|', 1)));
    END IF;
  END LOOP;
  -- Il biglietto non è una sessione: chi ha l'accesso non chiede di chi sono i biglietti, anon non li crea.
  got := pg_temp.rls_call('authenticated', rls_m(2), format(who, t, v));
  IF got <> 'E42501' THEN bad := bad || E'\n  B chiede di chi è un biglietto: ' || got; END IF;
  got := pg_temp.rls_call('anon', NULL, format('public.kagami_ticket(%L)', v));
  IF got <> 'E42501' THEN bad := bad || E'\n  anon crea un biglietto: ' || got; END IF;
  got := pg_temp.rls_call('authenticated', rls_m(2), '(SELECT count(*) FROM public.server_tickets)');
  IF got <> 'E42501' THEN bad := bad || E'\n  B legge i biglietti: ' || got; END IF;
  got := pg_temp.rls_call('anon', NULL, '(SELECT count(*) FROM public.server_tickets)');
  IF got <> 'E42501' THEN bad := bad || E'\n  anon legge i biglietti: ' || got; END IF;
  got := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_ticket(%L)', 'V'));
  IF got <> 'E22023' THEN bad := bad || E'\n  audience non valida: ' || got; END IF;
  -- Senza indirizzo (email e password, T3) niente biglietto.
  got := pg_temp.rls_call('authenticated', '00000000-0000-4000-8000-0000000000aa', format('public.kagami_ticket(%L)', v));
  IF got <> 'E42501' THEN bad := bad || E'\n  biglietto senza Google: ' || got; END IF;
  -- Scaduto, e riusato dopo il termine.
  UPDATE public.server_tickets SET expires_at = now() - interval '1 second' WHERE hash = sha256(convert_to(t, 'UTF8'));
  got := pg_temp.rls_call('anon', NULL, format(who, t, v));
  IF got <> 'NULL' THEN bad := bad || E'\n  biglietto scaduto: ' || got; END IF;
  got := pg_temp.rls_call('anon', NULL, format(who, t2, v));
  IF got <> 'm1@m.test' THEN bad := bad || E'\n  il secondo biglietto: ' || got; END IF;
  -- Sessanta l'ora: A ne ha due, al sessantunesimo no.
  FOR i IN 3..60 LOOP PERFORM pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_ticket(%L)', v)); END LOOP;
  IF (SELECT count(*) FROM public.server_tickets WHERE uid = rls_m(1)) <> 60 THEN RAISE EXCEPTION 'biglietti: non sono 60'; END IF;
  got := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_ticket(%L)', v));
  IF got <> 'E42501' THEN bad := bad || E'\n  il sessantunesimo biglietto: ' || got; END IF;
  got := pg_temp.rls_call('authenticated', rls_m(2), format('public.kagami_ticket(%L)', v));
  IF got !~ '^[0-9a-f]{96}$' THEN bad := bad || E'\n  la quota di A ferma B: ' || got; END IF;
  -- Quelli di più di un'ora fa non contano più e si tolgono.
  UPDATE public.server_tickets SET at = now() - interval '61 minutes' WHERE uid = rls_m(1);
  got := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_ticket(%L)', v));
  IF got !~ '^[0-9a-f]{96}$' THEN bad := bad || E'\n  dopo un''ora: ' || got; END IF;
  IF (SELECT count(*) FROM public.server_tickets WHERE uid = rls_m(1)) <> 1 THEN bad := bad || E'\n  i biglietti vecchi restano'; END IF;
  IF bad <> '' THEN RAISE EXCEPTION 'biglietti:%', bad; END IF;
END $$;

-- 0013 (F8.5): il biglietto porta l'indirizzo a cui l'app parla, e vale solo se il proprietario del
-- server l'ha garantito per quell'id. A (m1) è il proprietario di V e ne garantisce l'indirizzo; B (m2) è
-- l'amico; M è un server che dichiara l'id di V da un altro indirizzo, e K (m3) ne è il proprietario.
DO $$
DECLARE
  v text := repeat('a', 32); vu text := 'https://v.example'; mu text := 'https://m.example';
  t text; tm text; t0 text; got text; bad text := '';
  who text := '(SELECT email FROM public.kagami_ticket_who(%L, %L, %L))';
  old text := '(SELECT email FROM public.kagami_ticket_who(%L, %L))';
BEGIN
  got := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_server_origin(%L, %L)', v, vu));
  IF got <> '' THEN RAISE EXCEPTION 'garanzia: %', got; END IF;
  -- (void: la risposta è vuota). La stessa due volte non è un errore.
  got := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_server_origin(%L, %L)', v, vu));
  IF got <> '' THEN bad := bad || E'\n  garanzia ripetuta: ' || got; END IF;
  t := pg_temp.rls_call('authenticated', rls_m(2), format('public.kagami_ticket(%L, %L)', v, vu));
  IF t !~ '^[0-9a-f]{96}$' THEN RAISE EXCEPTION 'biglietto con indirizzo: %', t; END IF;
  tm := pg_temp.rls_call('authenticated', rls_m(2), format('public.kagami_ticket(%L, %L)', v, mu));
  t0 := pg_temp.rls_call('authenticated', rls_m(2), format('public.kagami_ticket(%L)', v));
  FOREACH got IN ARRAY ARRAY[
    format(who, t, v, 'm1@m.test') || '|m2@m.test',
    format(who, t, v, 'M1@m.test') || '|m2@m.test',      -- l'email del proprietario come la scrive il server
    format(who, t, v, 'm3@m.test') || '|NULL',           -- un altro proprietario non l'ha garantito
    format(who, t, repeat('b', 32), 'm1@m.test') || '|NULL',
    format(who, tm, v, 'm1@m.test') || '|NULL',          -- il biglietto chiesto attraverso M non vale su V
    format(who, t0, v, 'm1@m.test') || '|NULL',          -- senza indirizzo (l'app di prima) non vale
    format(old, t, v) || '|NULL',                        -- un server di prima non accetta quelli nuovi
    format(old, t0, v) || '|m2@m.test'                   -- e accetta ancora quelli di prima
  ] LOOP
    IF pg_temp.rls_call('anon', NULL, split_part(got, '|', 1)) <> split_part(got, '|', 2) THEN
      bad := bad || format(E'\n  anon %s: %s', split_part(got, '|', 1), pg_temp.rls_call('anon', NULL, split_part(got, '|', 1)));
    END IF;
  END LOOP;
  -- Il proprietario di M garantisce il suo indirizzo per l'id di V: vale solo per chi chiede col suo nome.
  PERFORM pg_temp.rls_call('authenticated', rls_m(3), format('public.kagami_server_origin(%L, %L)', v, mu));
  got := pg_temp.rls_call('anon', NULL, format(who, tm, v, 'm1@m.test'));
  IF got <> 'NULL' THEN bad := bad || E'\n  la garanzia di K vale per V: ' || got; END IF;
  got := pg_temp.rls_call('anon', NULL, format(who, tm, v, 'm3@m.test'));
  IF got <> 'm2@m.test' THEN bad := bad || E'\n  la garanzia di K per sé: ' || got; END IF;
  -- Indirizzi non validi, chi non può garantire, chi non può chiedere.
  FOREACH got IN ARRAY ARRAY['https://v.example/', 'ftp://v.example', 'https://a@v.example', 'https://v.example?x=1', '']
  LOOP
    IF pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_server_origin(%L, %L)', v, got)) <> 'E22023'
      OR pg_temp.rls_call('authenticated', rls_m(2), format('public.kagami_ticket(%L, %L)', v, got)) <> 'E22023' THEN
      bad := bad || E'\n  indirizzo non valido accettato: ' || got;
    END IF;
  END LOOP;
  got := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_server_origin(%L, NULL)', v));
  IF got <> 'E22023' THEN bad := bad || E'\n  indirizzo nullo: ' || got; END IF;
  got := pg_temp.rls_call('anon', NULL, format('public.kagami_server_origin(%L, %L)', v, vu));
  IF got <> 'E42501' THEN bad := bad || E'\n  anon garantisce: ' || got; END IF;
  got := pg_temp.rls_call('anon', NULL, format('public.kagami_ticket(%L, %L)', v, vu));
  IF got <> 'E42501' THEN bad := bad || E'\n  anon crea un biglietto con indirizzo: ' || got; END IF;
  got := pg_temp.rls_call('authenticated', '00000000-0000-4000-8000-0000000000aa', format('public.kagami_server_origin(%L, %L)', v, vu));
  IF got <> 'E42501' THEN bad := bad || E'\n  garanzia senza Google: ' || got; END IF;
  got := pg_temp.rls_call('authenticated', rls_m(2), format(who, t, v, 'm1@m.test'));
  IF got <> 'E42501' THEN bad := bad || E'\n  B chiede di chi è un biglietto con indirizzo: ' || got; END IF;
  -- Cento indirizzi per account; ripeterne uno non conta.
  FOR i IN 2..100 LOOP
    PERFORM pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_server_origin(%L, %L)', v, vu || '/p' || i));
  END LOOP;
  IF (SELECT count(*) FROM public.server_origins WHERE uid = rls_m(1)) <> 100 THEN RAISE EXCEPTION 'garanzie: non sono 100'; END IF;
  got := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_server_origin(%L, %L)', v, vu || '/p101'));
  IF got <> 'E42501' THEN bad := bad || E'\n  la centunesima garanzia: ' || got; END IF;
  got := pg_temp.rls_call('authenticated', rls_m(1), format('public.kagami_server_origin(%L, %L)', v, vu));
  IF got <> '' THEN bad := bad || E'\n  rinnovo oltre la quota: ' || got; END IF;
  IF bad <> '' THEN RAISE EXCEPTION 'indirizzi dei biglietti:%', bad; END IF;
END $$;

-- 0014: un invito con l'id di prima (senza mittente) resta: chi riceve lo legge e lo toglie, chi manda
-- anche; uno nuovo con l'id di prima no. Il vincolo si toglie e si rimette come su un backend vero.
ALTER TABLE public.server_invites DROP CONSTRAINT server_invites_id;
INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
  VALUES (substr(encode(sha256(convert_to('m2@m.test|https://vecchio.example', 'UTF8')), 'hex'), 1, 32), 'm2@m.test',
    'm1@m.test', 'https://vecchio.example', 'V'),
  (substr(encode(sha256(convert_to('m3@m.test|https://vecchio.example', 'UTF8')), 'hex'), 1, 32), 'm3@m.test',
    'm1@m.test', 'https://vecchio.example', 'V');
ALTER TABLE public.server_invites ADD CONSTRAINT server_invites_id CHECK (
  id = substr(encode(sha256(convert_to(from_email || '|' || to_email || '|' || url, 'UTF8')), 'hex'), 1, 32)
) NOT VALID;
DO $$
DECLARE got text; bad text := '';
BEGIN
  got := public.rls_cell('authenticated', rls_m(2), $q$SELECT * FROM public.server_invites WHERE url = 'https://vecchio.example'$q$);
  IF got <> '1' THEN bad := bad || E'\n  chi riceve non legge l''invito di prima: ' || got; END IF;
  got := public.rls_cell('authenticated', rls_m(2), $q$DELETE FROM public.server_invites WHERE url = 'https://vecchio.example'$q$);
  IF got <> '1' THEN bad := bad || E'\n  chi riceve non toglie l''invito di prima: ' || got; END IF;
  got := public.rls_cell('authenticated', rls_m(1), $q$DELETE FROM public.server_invites WHERE url = 'https://vecchio.example'$q$);
  IF got <> '2' THEN bad := bad || E'\n  chi manda non toglie gli inviti di prima: ' || got; END IF;
  got := public.rls_cell('authenticated', rls_m(1), $q$UPDATE public.server_invites SET server_name = 'W' WHERE url = 'https://vecchio.example'$q$);
  IF got <> '23514' THEN bad := bad || E'\n  un invito di prima si riscrive senza id nuovo: ' || got; END IF;
  got := public.rls_cell('authenticated', rls_m(1), $q$INSERT INTO public.server_invites (id, to_email, from_email, url, server_name)
    VALUES (substr(encode(sha256(convert_to('m4@m.test|https://vecchio.example', 'UTF8')), 'hex'), 1, 32), 'm4@m.test',
      'm1@m.test', 'https://vecchio.example', 'V')$q$);
  IF got <> '23514' THEN bad := bad || E'\n  invito nuovo con l''id di prima: ' || got; END IF;
  IF bad <> '' THEN RAISE EXCEPTION 'inviti di prima:%', bad; END IF;
END $$;

-- I contatori, dopo tutto questo, dicono ancora il vero.
SELECT rls_is((SELECT count(*) FROM public.posts p WHERE p.likes <> (SELECT count(*) FROM public.likes l WHERE l.post = p.id)
  OR p.comments <> (SELECT count(*) FROM public.comments c WHERE c.post = p.id)
  OR p.flags <> (SELECT count(*) FROM public.reports r WHERE r.target = 'post' AND r.target_id = p.id)), 0, 'contatori dei post');
SELECT rls_is((SELECT count(*) FROM public.comments c WHERE c.likes <> (SELECT count(*) FROM public.likes l WHERE l.comment = c.id)),
  0, 'contatori dei commenti');

ROLLBACK;
\echo rls-test: ok
