-- 0009 — La foto del profilo è solo di Google (F8.2: T5).
--
-- `profiles.photo` era un testo libero sotto i 512 caratteri e l'app lo carica con `Image.network` da
-- qualsiasi host: chi pubblica un profilo vede l'IP di chi lo guarda. La foto viene da `avatar_url` o
-- `picture` dell'account Google (cloud.dart, _accountOf), cioè `https://lh3.googleusercontent.com/a/…`;
-- il vincolo ammette `lh3`-`lh6` (non misurato su un backend vero: R2) e `https://`, e null. Le righe
-- fuori regola vanno a null prima del vincolo, che così nasce valido. L'app (F8.4) deve scartare le
-- foto fuori regola prima dell'upsert, o l'intero profilo fallisce con 23514.

UPDATE public.profiles SET photo = NULL
  WHERE photo IS NOT NULL
    AND (length(photo) >= 512 OR photo !~ '^https://lh[3-6]\.googleusercontent\.com/[^[:space:]]+$');

ALTER TABLE public.profiles DROP CONSTRAINT profiles_photo_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_photo_check
  CHECK (length(photo) < 512 AND photo ~ '^https://lh[3-6]\.googleusercontent\.com/[^[:space:]]+$');
