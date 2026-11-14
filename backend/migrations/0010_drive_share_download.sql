-- 0010 — Il permesso di scaricare nella condivisione (F5.17, FASE-5b §4; T21 di F8.2).
--
-- `download` dice se chi riceve può anche scaricare i capitoli sul telefono o solo leggerli in
-- streaming. È un patto fra app, non una protezione: il ruolo `reader` di Drive lascia scaricare a
-- chiunque abbia l'accesso. Lo scrive solo chi condivide (le policy di `drive_shares` non cambiano:
-- chi riceve non ha UPDATE sulla riga); le righe di prima restano «solo streaming».

ALTER TABLE public.drive_shares ADD COLUMN download boolean NOT NULL DEFAULT false;
