-- 0002 — La data di `readers` la mette il backend, a ogni scrittura: un telefono con l'orologio
-- sbagliato non deve poter dichiarare di essere il più recente.

CREATE FUNCTION public.kagami_touch() RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.kagami_touch() FROM PUBLIC;
CREATE TRIGGER readers_touch BEFORE INSERT OR UPDATE ON public.readers
  FOR EACH ROW EXECUTE FUNCTION public.kagami_touch();
