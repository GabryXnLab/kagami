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
