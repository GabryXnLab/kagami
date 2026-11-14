-- 0006 — Il soprannome sul commento (docs/social.md, «Chi vede cosa»). Chi commenta in casa d'altri
-- con un profilo ristretto arrivava senza nome («Un lettore»): come nei social comuni, il commento
-- porta il soprannome di chi l'ha scritto, preso dal backend nel momento in cui scrive. Il profilo
-- resta chiuso: niente foto, niente altro. L'app non ha il permesso sulla colonna.

ALTER TABLE public.comments
  ADD COLUMN author_name text NOT NULL DEFAULT '' CHECK (char_length(author_name) <= 24);

UPDATE public.comments c SET author_name = p.name FROM public.profiles p WHERE p.id = c.author;
-- Il soprannome sul commento lo prende il backend dal profilo di chi scrive, nel momento in cui scrive:
-- nessuno firma col nome di un altro. SECURITY DEFINER per leggere il profilo anche dove la regola
-- di profiles non arriva. Un cambio di soprannome dopo non riscrive i commenti già fatti.
CREATE FUNCTION public.kagami_comment_author_name() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  NEW.author_name := coalesce((SELECT p.name FROM public.profiles p WHERE p.id = NEW.author), '');
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.kagami_comment_author_name() FROM PUBLIC;
CREATE TRIGGER comments_author_name BEFORE INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.kagami_comment_author_name();
