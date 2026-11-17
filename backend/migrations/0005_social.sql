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
