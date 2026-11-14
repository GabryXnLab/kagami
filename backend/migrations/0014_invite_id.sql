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
