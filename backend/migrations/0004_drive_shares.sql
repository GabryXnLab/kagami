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
