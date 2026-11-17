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
