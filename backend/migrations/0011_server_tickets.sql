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
