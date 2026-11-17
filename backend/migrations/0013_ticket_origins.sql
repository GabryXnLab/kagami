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
