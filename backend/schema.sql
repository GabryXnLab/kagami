-- Schema del backend di Kagami: le migrazioni di backend/migrations/ una dopo l'altra, per un
-- backend nuovo. Non si scrive a mano: si aggiunge una migrazione e la si accoda qui (lo controlla
-- test/backend_config_test.dart).

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

-- 0002 — La data di `readers` la mette il backend, a ogni scrittura: un telefono con l'orologio
-- sbagliato non deve poter dichiarare di essere il più recente.

CREATE FUNCTION public.kagami_touch() RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.kagami_touch() FROM PUBLIC;
CREATE TRIGGER readers_touch BEFORE INSERT OR UPDATE ON public.readers
  FOR EACH ROW EXECUTE FUNCTION public.kagami_touch();

-- 0003 — Gli inviti arrivano mentre l'app è aperta: `server_invites` entra nella pubblicazione che
-- il realtime di Supabase ascolta. Un backend che non ce l'ha resta com'è, e l'app rilegge gli
-- inviti all'avvio e tornando in primo piano.

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.server_invites;
  END IF;
END $$;

-- 0004 — La libreria su Drive che un account lascia leggere a un altro (docs/drive.md, «La libreria
-- condivisa»). Il permesso vero sta su Drive; la riga è l'invito per chi riceve e, per chi condivide,
-- l'unico posto dove sta la scadenza quando Drive non la tiene.
--
-- Legge chi manda e chi riceve; scrive e toglie solo chi manda: se chi riceve potesse togliere la
-- riga, il permesso su Drive resterebbe senza più nessuno che ne ricordi il termine. `id` è l'impronta
-- di mittente, destinatario e cartella, e lo controlla la tabella: nessuno può occupare la riga di un
-- altro mittente scrivendone prima l'id. `from_uid` è l'utente che condivide: nel social, dove gli
-- indirizzi non esistono, è così che chi riceve trova a chi chiedere più tempo (docs/social.md).

CREATE TABLE public.drive_shares (
  id text PRIMARY KEY,
  to_email text NOT NULL CHECK (to_email = lower(to_email) AND length(to_email) < 320),
  from_email text NOT NULL,
  from_uid uuid NOT NULL DEFAULT auth.uid(),
  from_name text CHECK (length(from_name) < 128),
  folder_id text NOT NULL CHECK (length(folder_id) < 128),
  folder_name text NOT NULL CHECK (length(folder_name) < 128),
  permission_id text NOT NULL CHECK (length(permission_id) < 128),
  at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  CONSTRAINT drive_shares_id CHECK (
    id = substr(encode(sha256(convert_to(from_email || '|' || to_email || '|' || folder_id, 'UTF8')), 'hex'), 1, 32)
  )
);
CREATE INDEX drive_shares_to_idx ON public.drive_shares (to_email);
CREATE INDEX drive_shares_from_idx ON public.drive_shares (from_email);
ALTER TABLE public.drive_shares ENABLE ROW LEVEL SECURITY;
CREATE POLICY drive_shares_read ON public.drive_shares FOR SELECT TO authenticated
  USING (to_email = public.kagami_me() OR from_email = public.kagami_me());
CREATE POLICY drive_shares_delete ON public.drive_shares FOR DELETE TO authenticated
  USING (from_email = public.kagami_me());
CREATE POLICY drive_shares_create ON public.drive_shares FOR INSERT TO authenticated
  WITH CHECK (from_email = public.kagami_me() AND from_uid = auth.uid());
CREATE POLICY drive_shares_update ON public.drive_shares FOR UPDATE TO authenticated
  USING (from_email = public.kagami_me()) WITH CHECK (from_email = public.kagami_me() AND from_uid = auth.uid());

REVOKE ALL ON public.drive_shares FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.drive_shares TO authenticated;
GRANT ALL ON public.drive_shares TO service_role;

-- L'invito e il rinnovo arrivano mentre l'app è aperta, come per `server_invites` (0003). Il ritiro
-- no: di una riga tolta il realtime dice solo la chiave, e il filtro per destinatario non la vede;
-- chi riceve lo scopre rileggendo, all'avvio e tornando in primo piano.

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.drive_shares;
  END IF;
END $$;

-- 0005 — Il social: profili, legami, blocchi, post, commenti, mi piace, messaggi e segnalazioni
-- (docs/social.md, che è l'originale di ogni regola qui sotto).
--
-- Chi non ha un profilo non vede niente: ogni lettura passa da `kagami_sees`, che chiede il profilo
-- di chi guarda. Uscire è `DELETE` della propria riga di `profiles`: tutto ciò che è suo cade a
-- cascata; i blocchi e le segnalazioni puntano ad `auth.users` e restano. I contatori, le date e
-- `updated_at` li scrive il backend: all'app mancano i permessi su quelle colonne.

-- Forma di una lista di oggetti `{<etichetta>: testo, <numero>: 0..massimo}`, per i CHECK: un CHECK
-- non può contenere una sottoquery, una funzione sì.
CREATE FUNCTION public.kagami_pairs_ok(items jsonb, max_items int, label text, label_max int, amount text, amount_max numeric)
  RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT jsonb_typeof(items) = 'array' AND jsonb_array_length(items) <= max_items AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(items) item
    WHERE jsonb_typeof(item) <> 'object' OR jsonb_typeof(item -> label) IS DISTINCT FROM 'string'
      OR char_length(item ->> label) > label_max OR jsonb_typeof(item -> amount) IS DISTINCT FROM 'number'
      OR (item ->> amount)::numeric NOT BETWEEN 0 AND amount_max
  )
$$;

-- Un oggetto i cui valori sono tutti numeri fra 0 e [amount_max], con le sole chiavi [allowed].
CREATE FUNCTION public.kagami_numbers_ok(value jsonb, allowed text[], amount_max numeric)
  RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT jsonb_typeof(value) = 'object' AND NOT EXISTS (
    SELECT 1 FROM jsonb_each(value) entry
    WHERE entry.key <> ALL (allowed) OR jsonb_typeof(entry.value) <> 'number'
      OR (entry.value #>> '{}')::numeric NOT BETWEEN 0 AND amount_max
  )
$$;

-- Un array di esattamente [days] interi non negativi.
CREATE FUNCTION public.kagami_days_ok(value jsonb, days int)
  RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT jsonb_typeof(value) = 'array' AND jsonb_array_length(value) = days AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(value) day
    WHERE jsonb_typeof(day) <> 'number' OR (day #>> '{}')::numeric < 0
  )
$$;

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  name text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 24 AND name = btrim(name)),
  bio text NOT NULL DEFAULT '' CHECK (char_length(bio) <= 160),
  photo text CHECK (length(photo) < 512),
  audience text NOT NULL DEFAULT 'everyone' CHECK (audience IN ('everyone', 'following', 'mutual')),
  messages text NOT NULL DEFAULT 'following' CHECK (messages IN ('everyone', 'following', 'mutual', 'nobody')),
  since date,
  totals jsonb NOT NULL DEFAULT '{}'
    CHECK (public.kagami_numbers_ok(totals, ARRAY['chapters', 'pages', 'minutes', 'series', 'completed', 'meanRating'], 1e9)),
  streak jsonb NOT NULL DEFAULT '{}' CHECK (public.kagami_numbers_ok(streak, ARRAY['current', 'longest'], 1e6)),
  week_id text NOT NULL CHECK (week_id ~ '^\d{4}-W\d{2}$'),
  week_chapters int NOT NULL DEFAULT 0 CHECK (week_chapters >= 0),
  month_id text NOT NULL CHECK (month_id ~ '^\d{4}-\d{2}$'),
  month_chapters int NOT NULL DEFAULT 0 CHECK (month_chapters >= 0),
  genres jsonb NOT NULL DEFAULT '[]' CHECK (public.kagami_pairs_ok(genres, 8, 'name', 39, 'share', 100)),
  kinds jsonb NOT NULL DEFAULT '{}' CHECK (public.kagami_numbers_ok(kinds, ARRAY['manga', 'manhwa', 'manhua', 'other'], 100)),
  series jsonb CHECK (public.kagami_pairs_ok(series, 10, 'title', 119, 'chapters', 1e9)),
  activity jsonb CHECK (public.kagami_days_ok(activity, 14)),
  updated_at timestamptz NOT NULL DEFAULT now(),
  -- Le classifiche «sempre» e «giorni di fila» ordinano per queste: un indice su una colonna.
  total_chapters bigint GENERATED ALWAYS AS (((totals ->> 'chapters')::numeric)::bigint) STORED,
  streak_current int GENERATED ALWAYS AS (((streak ->> 'current')::numeric)::int) STORED
);
CREATE INDEX profiles_week_idx ON public.profiles (week_id, week_chapters DESC);
CREATE INDEX profiles_month_idx ON public.profiles (month_id, month_chapters DESC);
CREATE INDEX profiles_total_idx ON public.profiles (total_chapters DESC NULLS LAST);
CREATE INDEX profiles_streak_idx ON public.profiles (streak_current DESC NULLS LAST);
CREATE TRIGGER profiles_touch BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.kagami_touch();

CREATE TABLE public.follows (
  follower uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles ON DELETE CASCADE,
  followee uuid NOT NULL REFERENCES public.profiles ON DELETE CASCADE,
  follower_name text NOT NULL CHECK (char_length(follower_name) BETWEEN 2 AND 24),
  at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower, followee),
  CHECK (follower <> followee)
);
CREATE INDEX follows_followee_idx ON public.follows (followee);

CREATE TABLE public.blocks (
  blocker uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users ON DELETE CASCADE,
  blocked uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker, blocked),
  CHECK (blocker <> blocked)
);
CREATE INDEX blocks_blocked_idx ON public.blocks (blocked);

-- Le regole: SECURITY DEFINER perché una regola che rilegge la sua stessa tabella ricorre, e
-- search_path vuoto come in kagami_me(). Rispondono solo di auth.uid().

-- Se fra [a] e [b] c'è un blocco, in un verso o nell'altro. NULL se chi chiama non è uno dei due:
-- in una regola vale «no».
CREATE FUNCTION public.kagami_blocked(a uuid, b uuid) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE WHEN auth.uid() IN (a, b) THEN EXISTS (
    SELECT 1 FROM public.blocks
    WHERE (blocker = a AND blocked = b) OR (blocker = b AND blocked = a)
  ) END
$$;

-- vede(io, owner) di docs/social.md, «Chi vede cosa».
CREATE FUNCTION public.kagami_sees(owner uuid) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT owner = auth.uid() OR (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid())
    AND public.kagami_me() IS NOT NULL
    AND NOT public.kagami_blocked(auth.uid(), owner)
    AND EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = owner AND (
        p.audience = 'everyone'
        OR (p.audience IN ('following', 'mutual')
          AND EXISTS (SELECT 1 FROM public.follows WHERE follower = owner AND followee = auth.uid())
          AND (p.audience = 'following'
            OR EXISTS (SELECT 1 FROM public.follows WHERE follower = auth.uid() AND followee = owner)))
      )
    )
  )
$$;

CREATE TABLE public.posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles ON DELETE CASCADE,
  kind text NOT NULL DEFAULT 'note' CHECK (kind IN ('note', 'review', 'recommendation')),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  series_ref text CHECK (length(series_ref) < 120),
  series_title text CHECK (length(series_title) < 120),
  rating int CHECK (rating BETWEEN 1 AND 10),
  spoiler boolean NOT NULL DEFAULT false,
  chapter numeric CHECK (chapter >= 0),
  at timestamptz NOT NULL DEFAULT now(),
  likes int NOT NULL DEFAULT 0,
  comments int NOT NULL DEFAULT 0,
  flags int NOT NULL DEFAULT 0,
  CHECK ((series_ref IS NULL) = (series_title IS NULL)),
  CHECK (kind = 'note' OR series_ref IS NOT NULL),
  CHECK (kind <> 'review' OR rating IS NOT NULL)
);
CREATE INDEX posts_at_idx ON public.posts (at DESC);
CREATE INDEX posts_author_idx ON public.posts (author, at DESC);
CREATE INDEX posts_series_idx ON public.posts (series_ref, at DESC);

CREATE TABLE public.comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post uuid NOT NULL REFERENCES public.posts ON DELETE CASCADE,
  author uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles ON DELETE CASCADE,
  parent uuid,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 1000),
  spoiler boolean NOT NULL DEFAULT false,
  chapter numeric CHECK (chapter >= 0),
  at timestamptz NOT NULL DEFAULT now(),
  likes int NOT NULL DEFAULT 0,
  flags int NOT NULL DEFAULT 0,
  -- La risposta sta sotto lo stesso post del commento a cui risponde: lo dice la chiave, perché una
  -- regola su comments non può rileggere comments.
  UNIQUE (id, post),
  FOREIGN KEY (parent, post) REFERENCES public.comments (id, post) ON DELETE CASCADE
);
CREATE INDEX comments_post_idx ON public.comments (post, at);

CREATE TABLE public.likes (
  uid uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles ON DELETE CASCADE,
  post uuid REFERENCES public.posts ON DELETE CASCADE,
  comment uuid REFERENCES public.comments ON DELETE CASCADE,
  at timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(post, comment) = 1)
);
CREATE UNIQUE INDEX likes_post_idx ON public.likes (uid, post) WHERE post IS NOT NULL;
CREATE UNIQUE INDEX likes_comment_idx ON public.likes (uid, comment) WHERE comment IS NOT NULL;

CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles ON DELETE CASCADE,
  recipient uuid NOT NULL REFERENCES public.profiles ON DELETE CASCADE,
  kind text NOT NULL DEFAULT 'text' CHECK (kind IN ('text', 'extension')),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  share text CHECK (length(share) < 64),
  at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz,
  CHECK (sender <> recipient),
  CHECK (kind = 'text' OR share IS NOT NULL)
);
CREATE INDEX messages_recipient_idx ON public.messages (recipient, at DESC);
CREATE INDEX messages_sender_idx ON public.messages (sender, at DESC);

CREATE TABLE public.reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter uuid DEFAULT auth.uid() REFERENCES auth.users ON DELETE SET NULL,
  target text NOT NULL CHECK (target IN ('user', 'post', 'comment', 'message')),
  target_id uuid,
  target_user uuid NOT NULL,
  reason text NOT NULL CHECK (reason IN ('spam', 'harassment', 'spoiler', 'inappropriate', 'other')),
  note text NOT NULL DEFAULT '' CHECK (char_length(note) <= 500),
  snapshot text NOT NULL DEFAULT '' CHECK (char_length(snapshot) <= 2000),
  at timestamptz NOT NULL DEFAULT now(),
  CHECK ((target = 'user') = (target_id IS NULL)),
  UNIQUE NULLS NOT DISTINCT (reporter, target, target_id, target_user)
);

-- Se [recipient] accetta un mio messaggio: per il suo `messages`, o perché mi ha già scritto lui.
CREATE FUNCTION public.kagami_accepts(recipient uuid) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = kagami_accepts.recipient AND (
      p.messages = 'everyone'
      OR (p.messages IN ('following', 'mutual')
        AND EXISTS (SELECT 1 FROM public.follows f WHERE f.follower = kagami_accepts.recipient AND f.followee = auth.uid())
        AND (p.messages = 'following'
          OR EXISTS (SELECT 1 FROM public.follows f WHERE f.follower = auth.uid() AND f.followee = kagami_accepts.recipient)))
    )
  ) OR EXISTS (
    -- Il parametro si qualifica: in una funzione SQL una colonna con lo stesso nome vince.
    SELECT 1 FROM public.messages m WHERE m.sender = kagami_accepts.recipient AND m.recipient = auth.uid()
  )
$$;

REVOKE ALL ON FUNCTION public.kagami_blocked(uuid, uuid), public.kagami_sees(uuid), public.kagami_accepts(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.kagami_blocked(uuid, uuid), public.kagami_sees(uuid), public.kagami_accepts(uuid) TO authenticated;

-- Regole. `anon` non ha niente; chi non ha un profilo non passa da kagami_sees né dalle chiavi esterne.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY profiles_read ON public.profiles FOR SELECT TO authenticated USING (public.kagami_sees(id));
CREATE POLICY profiles_create ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid() AND public.kagami_me() IS NOT NULL);
CREATE POLICY profiles_update ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());
CREATE POLICY profiles_delete ON public.profiles FOR DELETE TO authenticated USING (id = auth.uid());

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY follows_read ON public.follows FOR SELECT TO authenticated
  USING (follower = auth.uid() OR followee = auth.uid());
CREATE POLICY follows_create ON public.follows FOR INSERT TO authenticated
  WITH CHECK (follower = auth.uid() AND NOT public.kagami_blocked(follower, followee));
CREATE POLICY follows_rename ON public.follows FOR UPDATE TO authenticated
  USING (follower = auth.uid()) WITH CHECK (follower = auth.uid());
CREATE POLICY follows_delete ON public.follows FOR DELETE TO authenticated
  USING (follower = auth.uid() OR followee = auth.uid());

-- I blocchi sopravvivono all'uscita, ma chi è uscito non li gestisce: «spento» non gestisce legami.
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY blocks_read ON public.blocks FOR SELECT TO authenticated
  USING (blocker = auth.uid() AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()));
CREATE POLICY blocks_create ON public.blocks FOR INSERT TO authenticated
  WITH CHECK (blocker = auth.uid() AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()));
CREATE POLICY blocks_delete ON public.blocks FOR DELETE TO authenticated
  USING (blocker = auth.uid() AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()));

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY posts_read ON public.posts FOR SELECT TO authenticated USING (public.kagami_sees(author));
CREATE POLICY posts_create ON public.posts FOR INSERT TO authenticated WITH CHECK (author = auth.uid());
CREATE POLICY posts_delete ON public.posts FOR DELETE TO authenticated USING (author = auth.uid());

-- La sottoquery su posts passa dalla sua regola: «chi vede il post».
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY comments_read ON public.comments FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post) AND NOT public.kagami_blocked(auth.uid(), author));
CREATE POLICY comments_create ON public.comments FOR INSERT TO authenticated
  WITH CHECK (
    author = auth.uid() AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post)
  );
CREATE POLICY comments_delete ON public.comments FOR DELETE TO authenticated
  USING (author = auth.uid() OR EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post AND p.author = auth.uid()));

ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY likes_read ON public.likes FOR SELECT TO authenticated USING (uid = auth.uid());
CREATE POLICY likes_create ON public.likes FOR INSERT TO authenticated
  WITH CHECK (uid = auth.uid() AND (
    EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post)
    OR EXISTS (SELECT 1 FROM public.comments c WHERE c.id = comment)
  ));
CREATE POLICY likes_delete ON public.likes FOR DELETE TO authenticated USING (uid = auth.uid());

-- La proroga (`extension`) vale solo con la condivisione giusta: la riga di drive_shares la vede chi
-- la riceve (to_email = kagami_me()), e deve venire da chi riceve il messaggio.
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY messages_read ON public.messages FOR SELECT TO authenticated
  USING (sender = auth.uid() OR recipient = auth.uid());
CREATE POLICY messages_create ON public.messages FOR INSERT TO authenticated
  WITH CHECK (
    sender = auth.uid() AND NOT public.kagami_blocked(sender, recipient) AND (
      (kind = 'text' AND public.kagami_accepts(recipient))
      OR (kind = 'extension' AND EXISTS (
        SELECT 1 FROM public.drive_shares d
        WHERE d.id = share AND d.from_uid = recipient AND d.to_email = public.kagami_me()
      ))
    )
  );
CREATE POLICY messages_read_at ON public.messages FOR UPDATE TO authenticated
  USING (recipient = auth.uid()) WITH CHECK (recipient = auth.uid());
CREATE POLICY messages_delete ON public.messages FOR DELETE TO authenticated
  USING (sender = auth.uid() OR recipient = auth.uid());

-- Nessuna regola di lettura: le segnalazioni le legge solo service_role.
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY reports_create ON public.reports FOR INSERT TO authenticated
  WITH CHECK (reporter = auth.uid() AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()));

-- Permessi per colonna: contatori, date, `updated_at` e le colonne generate non si scrivono.
REVOKE ALL ON public.profiles, public.follows, public.blocks, public.posts, public.comments, public.likes,
  public.messages, public.reports FROM anon, authenticated;
GRANT SELECT, DELETE ON public.profiles, public.follows, public.blocks, public.posts, public.comments,
  public.likes, public.messages TO authenticated;
GRANT INSERT (id, name, bio, photo, audience, messages, since, totals, streak, week_id, week_chapters, month_id,
  month_chapters, genres, kinds, series, activity),
  UPDATE (id, name, bio, photo, audience, messages, since, totals, streak, week_id, week_chapters, month_id,
  month_chapters, genres, kinds, series, activity) ON public.profiles TO authenticated;
GRANT INSERT (follower, followee, follower_name), UPDATE (follower_name) ON public.follows TO authenticated;
GRANT INSERT (blocker, blocked) ON public.blocks TO authenticated;
GRANT INSERT (author, kind, body, series_ref, series_title, rating, spoiler, chapter) ON public.posts TO authenticated;
GRANT INSERT (post, author, parent, body, spoiler, chapter) ON public.comments TO authenticated;
GRANT INSERT (uid, post, comment) ON public.likes TO authenticated;
GRANT INSERT (sender, recipient, kind, body, share), UPDATE (read_at) ON public.messages TO authenticated;
GRANT INSERT (reporter, target, target_id, target_user, reason, note, snapshot) ON public.reports TO authenticated;
GRANT ALL ON public.profiles, public.follows, public.blocks, public.posts, public.comments, public.likes,
  public.messages, public.reports TO service_role;

-- «Solo chi seguo»: la vista gira coi permessi e le regole di chi legge (security_invoker), quindi
-- mostra solo i post che lui vede già. Un filtro `author=in.(…)` con 500 persone non sta in un URL.
CREATE VIEW public.following_posts WITH (security_invoker = true) AS
  SELECT p.* FROM public.posts p
  JOIN public.follows f ON f.followee = p.author AND f.follower = auth.uid();
REVOKE ALL ON public.following_posts FROM anon, authenticated;
GRANT SELECT ON public.following_posts TO authenticated;
GRANT ALL ON public.following_posts TO service_role;

-- Limiti di frequenza. In un trigger e non in una regola: la sottoquery di una regola non vede le
-- righe che lo stesso INSERT ha già scritto, e un inserimento di 500 righe in una richiesta
-- passerebbe tutto. Il rifiuto è lo stesso 42501 di una regola, «non è stato possibile».
CREATE FUNCTION public.kagami_quota() RETURNS trigger
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  n bigint;
  most int;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'posts' THEN
      SELECT count(*), 20 INTO n, most FROM public.posts WHERE author = NEW.author AND at > now() - interval '1 day';
    WHEN 'comments' THEN
      SELECT count(*), 60 INTO n, most FROM public.comments WHERE author = NEW.author AND at > now() - interval '1 hour';
    WHEN 'messages' THEN
      SELECT count(*), 60 INTO n, most FROM public.messages WHERE sender = NEW.sender AND at > now() - interval '1 hour';
      IF n < most AND NEW.kind = 'extension' THEN
        -- Una richiesta di proroga al giorno per condivisione.
        SELECT count(*), 1 INTO n, most FROM public.messages
          WHERE sender = NEW.sender AND kind = 'extension' AND share = NEW.share AND at > now() - interval '1 day';
      END IF;
    WHEN 'reports' THEN
      SELECT count(*), 20 INTO n, most FROM public.reports WHERE reporter = NEW.reporter AND at > now() - interval '1 day';
    WHEN 'follows' THEN
      SELECT count(*), 500 INTO n, most FROM public.follows WHERE follower = NEW.follower;
  END CASE;
  IF n >= most THEN
    RAISE EXCEPTION 'limite di frequenza' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.kagami_quota() FROM PUBLIC;
CREATE TRIGGER posts_quota BEFORE INSERT ON public.posts FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();
CREATE TRIGGER comments_quota BEFORE INSERT ON public.comments FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();
CREATE TRIGGER messages_quota BEFORE INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();
CREATE TRIGGER reports_quota BEFORE INSERT ON public.reports FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();
CREATE TRIGGER follows_quota BEFORE INSERT ON public.follows FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();

-- I contatori: mi piace e commenti sui post, mi piace sui commenti, segnalazioni (una per persona e
-- oggetto, quindi persone diverse). SECURITY DEFINER perché chi scrive non ha il permesso su quelle
-- colonne. Una riga che se ne va con il suo oggetto (cascata) aggiorna una riga che non c'è più.
CREATE FUNCTION public.kagami_count() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  item record;
  step int;
BEGIN
  IF TG_OP = 'INSERT' THEN item := NEW; step := 1; ELSE item := OLD; step := -1; END IF;
  CASE TG_TABLE_NAME
    WHEN 'likes' THEN
      UPDATE public.posts SET likes = likes + step WHERE id = item.post;
      UPDATE public.comments SET likes = likes + step WHERE id = item.comment;
    WHEN 'comments' THEN
      UPDATE public.posts SET comments = comments + step WHERE id = item.post;
    WHEN 'reports' THEN
      IF item.target = 'post' THEN
        UPDATE public.posts SET flags = flags + step WHERE id = item.target_id;
      ELSIF item.target = 'comment' THEN
        UPDATE public.comments SET flags = flags + step WHERE id = item.target_id;
      END IF;
  END CASE;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.kagami_count() FROM PUBLIC;
CREATE TRIGGER likes_count AFTER INSERT OR DELETE ON public.likes FOR EACH ROW EXECUTE FUNCTION public.kagami_count();
CREATE TRIGGER comments_count AFTER INSERT OR DELETE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.kagami_count();
CREATE TRIGGER reports_count AFTER INSERT OR DELETE ON public.reports FOR EACH ROW EXECUTE FUNCTION public.kagami_count();

-- Bloccare toglie i legami fra i due, nello stesso istante.
CREATE FUNCTION public.kagami_unfollow_blocked() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  DELETE FROM public.follows
    WHERE (follower = NEW.blocker AND followee = NEW.blocked) OR (follower = NEW.blocked AND followee = NEW.blocker);
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.kagami_unfollow_blocked() FROM PUBLIC;
CREATE TRIGGER blocks_unfollow AFTER INSERT ON public.blocks FOR EACH ROW EXECUTE FUNCTION public.kagami_unfollow_blocked();

-- I messaggi arrivano mentre l'app è aperta; l'app filtra il canale per `recipient`.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;

-- 0006 — Il soprannome sul commento (docs/social.md, «Chi vede cosa»). Chi commenta in casa d'altri
-- con un profilo ristretto arrivava senza nome («Un lettore»): come nei social comuni, il commento
-- porta il soprannome di chi l'ha scritto, preso dal backend nel momento in cui scrive. Il profilo
-- resta chiuso: niente foto, niente altro. L'app non ha il permesso sulla colonna.

ALTER TABLE public.comments
  ADD COLUMN author_name text NOT NULL DEFAULT '' CHECK (char_length(author_name) <= 24);

UPDATE public.comments c SET author_name = p.name FROM public.profiles p WHERE p.id = c.author;
-- Il soprannome sul commento lo prende il backend dal profilo di chi scrive, nel momento in cui scrive:
-- nessuno firma col nome di un altro. SECURITY DEFINER per leggere il profilo anche dove la regola
-- di profiles non arriva. Un cambio di soprannome dopo non riscrive i commenti già fatti.
CREATE FUNCTION public.kagami_comment_author_name() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  NEW.author_name := coalesce((SELECT p.name FROM public.profiles p WHERE p.id = NEW.author), '');
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.kagami_comment_author_name() FROM PUBLIC;
CREATE TRIGGER comments_author_name BEFORE INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.kagami_comment_author_name();

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

-- 0008 — Un client modificato non deve poter più di quanto l'app chieda (F8.2: T2, T3, T4).
--
-- T3: kagami_me() dava l'indirizzo a chiunque avesse un account con email confermata. Con email e
-- password un indirizzo si «conferma» anche se è di un altro (dipende dal backend), e chi lo registra
-- leggeva inviti e condivisioni della vittima. Ora l'indirizzo c'è solo per un account non anonimo
-- con email confermata e Google come unico provider. È più stretto del server (identity.dart accetta
-- «contiene google»): F8.3 lo allinea. Prima di applicarla a un backend vero va contato chi
-- resterebbe senza indirizzo (R2).
--
-- T2: inviti e condivisioni non avevano limiti. Ora 30 inviti e 30 condivisioni nuove ogni 24 ore per
-- mittente, nel trigger delle quote. Il rinnovo (upsert su un id che esiste) non conta. `at` lo mette
-- il backend sulle righe nuove (scritto dal client aggirerebbe il conteggio) e in update resta quello
-- di prima; `to_email` di un invito non cambia. Resta aperto: cancellare e reinserire.
--
-- T4: `readers.data` non aveva tetto. Il tetto è di 16 MiB sul testo del jsonb, `NOT VALID` perché un
-- backend vero può avere righe oltre (le scritture nuove sì, quelle vecchie no finché non si
-- riscrivono; `VALIDATE CONSTRAINT` dopo averle contate). Misura sintetica, non su un backup vero:
-- ~0,8 MiB con 10k letture e 10k sessioni, ~10 MiB con 100k e 100k. In più al più 2 righe per owner.

CREATE OR REPLACE FUNCTION public.kagami_me() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT lower(u.email) FROM auth.users u
  WHERE u.id = auth.uid() AND u.email_confirmed_at IS NOT NULL AND u.is_anonymous IS NOT TRUE
    AND u.raw_app_meta_data -> 'providers' = '["google"]'::jsonb
$$;

ALTER TABLE public.readers ADD CONSTRAINT readers_data_size
  CHECK (octet_length(data::text) <= 16 * 1024 * 1024) NOT VALID;

CREATE OR REPLACE FUNCTION public.kagami_quota() RETURNS trigger
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  n bigint;
  most int;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.at := OLD.at;
    IF TG_TABLE_NAME = 'server_invites' AND NEW.to_email IS DISTINCT FROM OLD.to_email THEN
      RAISE EXCEPTION 'il destinatario di un invito non cambia' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;
  CASE TG_TABLE_NAME
    WHEN 'posts' THEN
      SELECT count(*), 20 INTO n, most FROM public.posts WHERE author = NEW.author AND at > now() - interval '1 day';
    WHEN 'comments' THEN
      SELECT count(*), 60 INTO n, most FROM public.comments WHERE author = NEW.author AND at > now() - interval '1 hour';
    WHEN 'messages' THEN
      SELECT count(*), 60 INTO n, most FROM public.messages WHERE sender = NEW.sender AND at > now() - interval '1 hour';
      IF n < most AND NEW.kind = 'extension' THEN
        -- Una richiesta di proroga al giorno per condivisione.
        SELECT count(*), 1 INTO n, most FROM public.messages
          WHERE sender = NEW.sender AND kind = 'extension' AND share = NEW.share AND at > now() - interval '1 day';
      END IF;
    WHEN 'reports' THEN
      SELECT count(*), 20 INTO n, most FROM public.reports WHERE reporter = NEW.reporter AND at > now() - interval '1 day';
    WHEN 'follows' THEN
      SELECT count(*), 500 INTO n, most FROM public.follows WHERE follower = NEW.follower;
    WHEN 'server_invites' THEN
      NEW.at := now();
      SELECT count(*), 30 INTO n, most FROM public.server_invites
        WHERE from_email = NEW.from_email AND at > now() - interval '1 day'
          AND NOT EXISTS (SELECT 1 FROM public.server_invites o WHERE o.id = NEW.id);
    WHEN 'drive_shares' THEN
      NEW.at := now();
      SELECT count(*), 30 INTO n, most FROM public.drive_shares
        WHERE from_email = NEW.from_email AND at > now() - interval '1 day'
          AND NOT EXISTS (SELECT 1 FROM public.drive_shares o WHERE o.id = NEW.id);
    WHEN 'readers' THEN
      SELECT count(*), 2 INTO n, most FROM public.readers WHERE owner = NEW.owner
        AND NOT EXISTS (SELECT 1 FROM public.readers o WHERE o.id = NEW.id);
  END CASE;
  IF n >= most THEN
    RAISE EXCEPTION 'limite di frequenza' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER server_invites_quota BEFORE INSERT ON public.server_invites
  FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();
CREATE TRIGGER server_invites_keep BEFORE UPDATE ON public.server_invites
  FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();
CREATE TRIGGER drive_shares_quota BEFORE INSERT ON public.drive_shares
  FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();
CREATE TRIGGER drive_shares_keep BEFORE UPDATE ON public.drive_shares
  FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();
CREATE TRIGGER readers_quota BEFORE INSERT ON public.readers
  FOR EACH ROW EXECUTE FUNCTION public.kagami_quota();

-- 0009 — La foto del profilo è solo di Google (F8.2: T5).
--
-- `profiles.photo` era un testo libero sotto i 512 caratteri e l'app lo carica con `Image.network` da
-- qualsiasi host: chi pubblica un profilo vede l'IP di chi lo guarda. La foto viene da `avatar_url` o
-- `picture` dell'account Google (cloud.dart, _accountOf), cioè `https://lh3.googleusercontent.com/a/…`;
-- il vincolo ammette `lh3`-`lh6` (non misurato su un backend vero: R2) e `https://`, e null. Le righe
-- fuori regola vanno a null prima del vincolo, che così nasce valido. L'app (F8.4) deve scartare le
-- foto fuori regola prima dell'upsert, o l'intero profilo fallisce con 23514.

UPDATE public.profiles SET photo = NULL
  WHERE photo IS NOT NULL
    AND (length(photo) >= 512 OR photo !~ '^https://lh[3-6]\.googleusercontent\.com/[^[:space:]]+$');

ALTER TABLE public.profiles DROP CONSTRAINT profiles_photo_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_photo_check
  CHECK (length(photo) < 512 AND photo ~ '^https://lh[3-6]\.googleusercontent\.com/[^[:space:]]+$');

-- 0010 — Il permesso di scaricare nella condivisione (F5.17, FASE-5b §4; T21 di F8.2).
--
-- `download` dice se chi riceve può anche scaricare i capitoli sul telefono o solo leggerli in
-- streaming. È un patto fra app, non una protezione: il ruolo `reader` di Drive lascia scaricare a
-- chiunque abbia l'accesso. Lo scrive solo chi condivide (le policy di `drive_shares` non cambiano:
-- chi riceve non ha UPDATE sulla riga); le righe di prima restano «solo streaming».

ALTER TABLE public.drive_shares ADD COLUMN download boolean NOT NULL DEFAULT false;

-- 0011 — Il Kagami Server non riceve più il token della sessione (F8.6, T1).
--
-- Chi invitava una vittima al proprio server e la convinceva ad accettare riceveva il suo token di
-- sessione, e con quello agiva da lei sul backend finché valeva. Ora l'app chiede al backend un
-- biglietto per quel server (kagami_ticket) e manda solo quello; il server chiede al backend di chi è
-- (kagami_ticket_who) con la sola chiave anon. Il biglietto vale dieci minuti e solo per l'`audience`,
-- cioè l'id casuale del server (docs/server-api.md, «Biglietto»): su un altro server e sul backend non
-- apre niente. Del biglietto il backend tiene solo l'impronta.
--
-- Il casuale viene da gen_random_uuid() (nel nucleo da Postgres 13, 122 bit ciascuno): tre fanno 366
-- bit, senza pgcrypto, che su Supabase sta in un altro schema. kagami_ticket_who è la prima funzione
-- concessa ad anon: risponde solo a chi ha già il biglietto, e non elenca niente.

CREATE TABLE public.server_tickets (
  hash bytea PRIMARY KEY,
  uid uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  email text NOT NULL,
  audience text NOT NULL CHECK (audience ~ '^[0-9a-f]{32}$'),
  at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);
CREATE INDEX server_tickets_uid_idx ON public.server_tickets (uid, at);
-- RLS accesa e nessuna regola: la toccano solo le due funzioni.
ALTER TABLE public.server_tickets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.server_tickets FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.kagami_ticket(audience text) RETURNS text
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  me text := public.kagami_me();
  ticket text;
  n bigint;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'serve l''accesso con Google' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF audience IS NULL OR audience !~ '^[0-9a-f]{32}$' THEN
    RAISE EXCEPTION 'id del server non valido' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  -- I biglietti di più di un'ora fa sono scaduti e non contano per la quota: si tolgono qui.
  DELETE FROM public.server_tickets t WHERE t.at < now() - interval '1 hour';
  SELECT count(*) INTO n FROM public.server_tickets t WHERE t.uid = auth.uid();
  IF n >= 60 THEN
    RAISE EXCEPTION 'limite di frequenza' USING ERRCODE = 'insufficient_privilege';
  END IF;
  ticket := replace(gen_random_uuid()::text || gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  INSERT INTO public.server_tickets (hash, uid, email, audience, expires_at)
    VALUES (sha256(convert_to(ticket, 'UTF8')), auth.uid(), me, kagami_ticket.audience, now() + interval '10 minutes');
  RETURN ticket;
END $$;

CREATE FUNCTION public.kagami_ticket_who(ticket text, audience text)
  RETURNS TABLE (email text, expires_at timestamptz)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT t.email, t.expires_at FROM public.server_tickets t
  WHERE t.hash = sha256(convert_to(kagami_ticket_who.ticket, 'UTF8'))
    AND t.audience = kagami_ticket_who.audience AND t.expires_at > now()
$$;

REVOKE EXECUTE ON FUNCTION public.kagami_ticket(text), public.kagami_ticket_who(text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kagami_ticket(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.kagami_ticket_who(text, text) TO anon, service_role;

-- 0012 — Nessuno occupa ciò che è di un altro (F8.5: riga di backup, nome sul legame, segnalazioni).
--
-- readers: `id` è una chiave globale scelta dal client, e l'app usa l'uid come id. Chi inseriva
-- `readers(id = uid di un altro, owner = sé)` teneva la riga e l'upsert dell'altro falliva per
-- sempre (la regola d'aggiornamento non lo lascia toccare). Ora l'id è l'uid del proprietario: la
-- riga di un altro non si può nemmeno prenotare. Righe esistenti: se un proprietario non ha la riga
-- con id = uid, la più recente prende quell'id; le altre non si toccano né si cancellano (sono
-- backup) e restano fuori regola, `NOT VALID` perché un backend vero può averne. Prima di
-- `VALIDATE CONSTRAINT` si contano: `SELECT count(*) FROM readers WHERE id <> owner::text`. Il
-- tetto di 2 righe per owner (0008) resta, ma con id = uid ne esiste una sola: serve solo a chi ha
-- righe vecchie.
--
-- follows: `follower_name` lo scriveva il client, quindi uno poteva firmare il legame col nome di
-- un altro. Come per i commenti (0006) lo prende il backend dal profilo di chi segue, a ogni
-- scrittura; la colonna resta scrivibile perché l'app la manda ancora, ma il valore è ignorato.
--
-- reports: `target_id` e `target_user` erano liberi, e `flags` si alza sul post o commento con quell'id
-- (kagami_count). Ora l'oggetto deve esistere ed essere visibile a chi segnala (le sottoquery
-- passano dalle regole di posts, comments e messages) e `target_user` deve esserne l'autore.
-- Un messaggio lo segnala solo chi lo ha ricevuto.

UPDATE public.readers r SET id = r.owner::text
  WHERE r.id <> r.owner::text
    AND r.updated_at = (SELECT max(o.updated_at) FROM public.readers o WHERE o.owner = r.owner)
    AND NOT EXISTS (SELECT 1 FROM public.readers o WHERE o.id = r.owner::text);

ALTER TABLE public.readers ADD CONSTRAINT readers_id_is_owner CHECK (id = owner::text) NOT VALID;

CREATE FUNCTION public.kagami_follower_name() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- Senza profilo il valore resta e a rifiutare la riga è la chiave esterna.
  NEW.follower_name := coalesce((SELECT p.name FROM public.profiles p WHERE p.id = NEW.follower), NEW.follower_name);
  RETURN NEW;
END $$;
REVOKE EXECUTE ON FUNCTION public.kagami_follower_name() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER follows_follower_name BEFORE INSERT OR UPDATE ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.kagami_follower_name();

DROP POLICY reports_create ON public.reports;
CREATE POLICY reports_create ON public.reports FOR INSERT TO authenticated
  WITH CHECK (
    reporter = auth.uid() AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid())
    AND CASE target
      WHEN 'user' THEN true
      WHEN 'post' THEN EXISTS (SELECT 1 FROM public.posts p WHERE p.id = target_id AND p.author = target_user)
      WHEN 'comment' THEN EXISTS (SELECT 1 FROM public.comments c WHERE c.id = target_id AND c.author = target_user)
      WHEN 'message' THEN EXISTS (
        SELECT 1 FROM public.messages m WHERE m.id = target_id AND m.sender = target_user AND m.recipient = auth.uid())
    END
  );

-- 0013 — Un biglietto vale per il server a cui l'app parla, non per quello che il server dice di essere
-- (F8.5).
--
-- Con 0011 il biglietto era per l'`audience`, cioè l'id che il server dichiara in `GET /`, che è
-- pubblico. Un server M, a un primo collegamento, dichiarava l'id del server B della vittima, riceveva
-- un biglietto per B e lo ripeteva su B entro dieci minuti agendo come la vittima. Ora il biglietto
-- porta anche l'`origin`, l'indirizzo a cui l'app sta parlando (lo sceglie l'app, non il server), e
-- vale solo se il proprietario del server ha garantito quell'indirizzo per quell'id
-- (kagami_server_origin): il server chiede con l'email del suo proprietario, da KAGAMI_SETUP. Il
-- biglietto chiesto attraverso M porta l'indirizzo di M, che il proprietario di B non ha garantito.
-- Protocollo: docs/server-api.md, «Biglietto».
--
-- Le forme di prima restano per chi non è aggiornato: kagami_ticket(audience) rilascia biglietti senza
-- indirizzo, che il kagami_ticket_who nuovo non accetta; il kagami_ticket_who(ticket, audience) dei
-- server di prima non accetta più quelli con indirizzo, così un biglietto nuovo non si ripete su un
-- server vecchio (che si aggiorna da sé entro un'ora).

ALTER TABLE public.server_tickets ADD COLUMN origin text
  CHECK (origin IS NULL OR (length(origin) < 512 AND origin ~ '^https?://[^/?#@[:space:]]+(/[^?#[:space:]]*)?$'
    AND right(origin, 1) <> '/'));

-- Gli indirizzi garantiti: chi (uid ed email al momento della garanzia) dice che a `origin` risponde il
-- suo server con l'id `audience`. Chiunque può garantirne, ma conta solo la garanzia del proprietario
-- che il server nomina. RLS accesa e nessuna regola: la toccano solo le funzioni.
CREATE TABLE public.server_origins (
  audience text NOT NULL CHECK (audience ~ '^[0-9a-f]{32}$'),
  origin text NOT NULL CHECK (length(origin) < 512 AND origin ~ '^https?://[^/?#@[:space:]]+(/[^?#[:space:]]*)?$'
    AND right(origin, 1) <> '/'),
  uid uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  email text NOT NULL,
  at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (audience, origin, uid)
);
CREATE INDEX server_origins_uid_idx ON public.server_origins (uid);
ALTER TABLE public.server_origins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.server_origins FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.kagami_server_origin(audience text, origin text) RETURNS void
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  me text := public.kagami_me();
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'serve l''accesso con Google' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF audience IS NULL OR audience !~ '^[0-9a-f]{32}$' OR origin IS NULL
    OR length(origin) >= 512 OR origin !~ '^https?://[^/?#@[:space:]]+(/[^?#[:space:]]*)?$' OR right(origin, 1) = '/' THEN
    RAISE EXCEPTION 'id o indirizzo del server non validi' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  -- Ripetere una garanzia non conta; cento indirizzi per account bastano a chiunque.
  IF NOT EXISTS (SELECT 1 FROM public.server_origins o WHERE o.audience = kagami_server_origin.audience
      AND o.origin = kagami_server_origin.origin AND o.uid = auth.uid())
    AND (SELECT count(*) FROM public.server_origins o WHERE o.uid = auth.uid()) >= 100 THEN
    RAISE EXCEPTION 'troppi indirizzi garantiti' USING ERRCODE = 'insufficient_privilege';
  END IF;
  INSERT INTO public.server_origins (audience, origin, uid, email)
    VALUES (kagami_server_origin.audience, kagami_server_origin.origin, auth.uid(), me)
    ON CONFLICT ON CONSTRAINT server_origins_pkey DO UPDATE SET email = EXCLUDED.email, at = now();
END $$;

CREATE FUNCTION public.kagami_ticket(audience text, origin text) RETURNS text
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  me text := public.kagami_me();
  ticket text;
  n bigint;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'serve l''accesso con Google' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF audience IS NULL OR audience !~ '^[0-9a-f]{32}$' OR origin IS NULL
    OR length(origin) >= 512 OR origin !~ '^https?://[^/?#@[:space:]]+(/[^?#[:space:]]*)?$' OR right(origin, 1) = '/' THEN
    RAISE EXCEPTION 'id o indirizzo del server non validi' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  DELETE FROM public.server_tickets t WHERE t.at < now() - interval '1 hour';
  SELECT count(*) INTO n FROM public.server_tickets t WHERE t.uid = auth.uid();
  IF n >= 60 THEN
    RAISE EXCEPTION 'limite di frequenza' USING ERRCODE = 'insufficient_privilege';
  END IF;
  ticket := replace(gen_random_uuid()::text || gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  INSERT INTO public.server_tickets (hash, uid, email, audience, origin, expires_at)
    VALUES (sha256(convert_to(ticket, 'UTF8')), auth.uid(), me, kagami_ticket.audience, kagami_ticket.origin,
      now() + interval '10 minutes');
  RETURN ticket;
END $$;

-- Il server chiede con l'email del suo proprietario: il biglietto vale se il suo indirizzo l'ha
-- garantito lui per questo id.
CREATE FUNCTION public.kagami_ticket_who(ticket text, audience text, owner text)
  RETURNS TABLE (email text, expires_at timestamptz)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT t.email, t.expires_at FROM public.server_tickets t
  WHERE t.hash = sha256(convert_to(kagami_ticket_who.ticket, 'UTF8'))
    AND t.audience = kagami_ticket_who.audience AND t.expires_at > now() AND t.origin IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.server_origins o
      WHERE o.audience = t.audience AND o.origin = t.origin AND o.email = lower(kagami_ticket_who.owner))
$$;

CREATE OR REPLACE FUNCTION public.kagami_ticket_who(ticket text, audience text)
  RETURNS TABLE (email text, expires_at timestamptz)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT t.email, t.expires_at FROM public.server_tickets t
  WHERE t.hash = sha256(convert_to(kagami_ticket_who.ticket, 'UTF8'))
    AND t.audience = kagami_ticket_who.audience AND t.expires_at > now() AND t.origin IS NULL
$$;

REVOKE EXECUTE ON FUNCTION public.kagami_server_origin(text, text), public.kagami_ticket(text, text),
  public.kagami_ticket_who(text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kagami_server_origin(text, text), public.kagami_ticket(text, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.kagami_ticket_who(text, text, text) TO anon, service_role;

-- 0014 — L'id dell'invito a un server contiene il mittente (F8.5).
--
-- L'app calcolava l'id di server_invites da destinatario e indirizzo (sha256("<to>|<url>")): chiunque
-- sapesse a chi e per quale indirizzo il proprietario avrebbe scritto un invito poteva inserire per
-- primo una riga con quell'id e il proprio from_email, e l'upsert del proprietario falliva per sempre
-- (la regola d'aggiornamento non gli lascia toccare la riga di un altro). Ora l'id è
-- sha256("<from_email>|<to_email>|<url>"), i primi 32 caratteri, come drive_shares (0004), e la tabella
-- lo controlla. `NOT VALID` perché un backend vero ha inviti con l'id di prima: restano leggibili e
-- chi manda o chi riceve li toglie ancora; prima di `VALIDATE CONSTRAINT` si contano:
-- SELECT count(*) FROM server_invites WHERE id <> substr(encode(sha256(convert_to(from_email || '|' ||
-- to_email || '|' || url, 'UTF8')), 'hex'), 1, 32).

ALTER TABLE public.server_invites ADD CONSTRAINT server_invites_id CHECK (
  id = substr(encode(sha256(convert_to(from_email || '|' || to_email || '|' || url, 'UTF8')), 'hex'), 1, 32)
) NOT VALID;

-- 0015 — Un indirizzo garantito scade (F8.10).
--
-- Con 0013 una garanzia (kagami_server_origin) valeva per sempre: se il proprietario perdeva un
-- dominio e qualcun altro lo prendeva, i biglietti verso quel dominio restavano validi sul suo server.
-- Ora kagami_ticket_who conta solo le garanzie degli ultimi 90 giorni (`at`). Si rinnova dichiarandola
-- di nuovo: kagami_server_origin aggiorna già `at` su una garanzia esistente, e l'app la ripete al più
-- ogni 7 giorni (ServerAccess, originRenewal) finché il proprietario apre il server. Nessuna colonna
-- nuova. Protocollo: docs/server-api.md, «Biglietto».

CREATE OR REPLACE FUNCTION public.kagami_ticket_who(ticket text, audience text, owner text)
  RETURNS TABLE (email text, expires_at timestamptz)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT t.email, t.expires_at FROM public.server_tickets t
  WHERE t.hash = sha256(convert_to(kagami_ticket_who.ticket, 'UTF8'))
    AND t.audience = kagami_ticket_who.audience AND t.expires_at > now() AND t.origin IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.server_origins o
      WHERE o.audience = t.audience AND o.origin = t.origin AND o.email = lower(kagami_ticket_who.owner)
        AND o.at > now() - interval '90 days')
$$;
