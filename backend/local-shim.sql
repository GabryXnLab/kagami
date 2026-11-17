-- Il minimo di Supabase che manca a un Postgres qualsiasi, per provare schema e regole in locale
-- (backend/test.sh). Non va mai su un backend vero: lì ruoli, auth.users e auth.uid() ci sono già.

CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
-- Le colonne che le regole leggono, come in GoTrue e in Hestia: `raw_app_meta_data` lo scrive solo il
-- backend (provider dell'accesso), `raw_user_meta_data` l'utente.
CREATE TABLE auth.users (
  id uuid PRIMARY KEY,
  email text,
  email_confirmed_at timestamptz,
  raw_app_meta_data jsonb NOT NULL DEFAULT '{}',
  raw_user_meta_data jsonb NOT NULL DEFAULT '{}',
  is_anonymous boolean NOT NULL DEFAULT false
);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub')::uuid
$$;
GRANT USAGE ON SCHEMA auth, public TO anon, authenticated, service_role;
-- Come Supabase e Hestia: ogni tabella, sequenza e funzione nuova di public nasce concessa ad anon e
-- authenticated, e lo schema deve toglierlo da sé. Senza, i test proverebbero un backend più chiuso del vero.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
-- La pubblicazione che il realtime di Supabase ascolta: le migrazioni ci aggiungono le loro tabelle.
SET client_min_messages = error; -- l'avviso su wal_level: qui nessuno si abbona
CREATE PUBLICATION supabase_realtime;
RESET client_min_messages;
