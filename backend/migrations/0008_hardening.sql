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
