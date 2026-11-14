# Il social (contratto)

La «Comunità» di Kagami: profili, classifiche, post sulle serie, commenti, messaggi privati fra lettori
che usano lo stesso backend. Sta sul backend **di chi compila** (`backend/`, compatibile Supabase): solo
tabelle, regole (RLS), trigger e il realtime; nessuna funzione chiamata dall'app, nessun servizio in più.
Codice: `lib/src/data/social/` (tipi e interfacce: `profile.dart`, `content.dart`, `backend.dart`),
schermate in `lib/src/ui/social_*.dart`. Questo documento è l'originale: una regola nuova nasce qui, poi
in `backend/` e nel codice.

## Principi

- **Spento finché l'utente non lo accende.** Spento vuol dire due cose insieme: di lui non esce niente,
  e lui non vede gli altri né gestisce legami. Lo garantisce due volte: l'app spenta non fa nessuna
  chiamata, e il backend non mostra niente a chi non ha un profilo. L'ingresso «Comunità» da spento è
  solo l'invito ad accenderlo, con l'anteprima esatta di ciò che uscirebbe.
- **Spegnere cancella.** Uscire toglie la riga del profilo e, a cascata, tutto ciò che è suo sulla rete:
  post, commenti, mi piace, legami, messaggi (anche nelle conversazioni degli altri). L'interfaccia lo
  dice prima di farlo. «Elimina i dati dall'account» fa lo stesso. I blocchi restano: chi rientra non
  ritrova davanti chi aveva bloccato.
- **Mai un indirizzo.** Una persona è il suo `uid` e un soprannome scelto (non ricavato dall'account).
  Nessuna tabella del social ha un'email, nessuna ricerca per email: direbbe a chiunque se un indirizzo è
  iscritto.
- **Le serie nascoste non escono mai** (F2, D7): né titoli, né generi, né numeri, né post, e di una serie
  nascosta l'app non chiede niente alla rete (nemmeno i post degli altri: la richiesta porterebbe il
  titolo). Le loro letture contano nei totali privati e in nessuna superficie pubblica. Lo tengono
  `buildPublicProfile` (lancia se le statistiche non sono state chieste con `excluding`) e
  `PostDraft.refusal`, non chi li chiama.
- **I numeri sono dichiarati dal telefono.** Regole e `CHECK` controllano forma e limiti, non la verità:
  le classifiche non sono a prova d'imbroglio, e va bene così.
- **La radio resta spenta.** Il profilo si pubblica negli stessi tre momenti della sincronizzazione
  (avvio, uscita, a richiesta) e solo se è cambiato (`PublicProfile.fingerprint`). Le azioni — un post,
  un segui, un messaggio — partono dal gesto e falliscono a voce alta. Niente notifiche push: quelle
  locali, ad app aperta. Messaggi privati: una notifica per conversazione (`message_alerts.dart`, chiave
  `message:<uid>`, canale degli inviti) se ci sono non letti dell'altro non ancora annunciati (ultimo id per
  conversazione in `social.messages.seen`); mai con social spento, `messages` = nessuno, mittente bloccato o
  silenziato. La conversazione aperta non è esclusa: può notificare prima che la schermata la segni letta.
- **Tre stati, come ovunque.** Una lettura fallita lancia; `null` e lista vuota vogliono dire che il
  backend ha risposto.

## Chi vede cosa

Il proprietario del profilo sceglie il suo pubblico (`audience`), e la stessa regola vale per il profilo,
per i suoi post e per la sua presenza in classifiche e ricerca. `vede(chi guarda, proprietario)` è vera se:

1. chi guarda **è** il proprietario; oppure
2. chi guarda ha un profilo (ha il social acceso) e un'email verificata, nessuno dei due ha bloccato
   l'altro, e:

| `audience` | in più serve che |
|---|---|
| `everyone` | — |
| `following` | il proprietario segua chi guarda |
| `mutual` | il proprietario segua chi guarda **e** chi guarda segua il proprietario |

Con un pubblico ristretto è il proprietario a scegliere: segue lui per primo. Chi è seguito lo viene a
sapere dal legame, che porta il soprannome di chi segue (`follower_name`): così può ricambiare anche se
il profilo dell'altro (livello `mutual`) non gli è ancora visibile. Un profilo che non si vede e uno che
non esiste sono indistinguibili da fuori, apposta.

Dentro un profilo visibile, tre interruttori (spenti di partenza): **foto** (`photo`), **titoli**
(`series`: le più lette, e ciò che si ha «in comune»), **attività** (`activity`: capitoli al giorno delle
ultime due settimane). Numeri, generi e famiglie di tipo ci sono sempre: sono il profilo. Un interruttore
spento pubblica `null`, non una lista vuota. Un post su una serie ne nomina il titolo per scelta
esplicita, qualunque sia l'interruttore dei titoli.

Un **commento** si vede dove si vede il post: chi commenta parla in casa d'altri, e lo vede chi vede il
post (tranne chi ha un blocco con lui). Porta il **soprannome** che chi commenta aveva quando ha scritto
(`author_name`, migrazione 0006, scritto dal backend col trigger `comments_author_name`: nessuno firma col
nome di un altro, e un cambio di nome dopo non lo riscrive), come nei social comuni: un profilo ristretto
commenta col suo nome ma resta chiuso — niente foto, e chi non può vederlo, toccandolo, legge «Profilo
privato» (`SocialCard.closed`). Senza la 0006 sul backend il nome manca e resta «Un lettore». **Chi può scrivermi** (`messages`): `everyone`, `following` (chi
seguo; valore iniziale), `mutual`, `nobody`. Si può sempre rispondere a chi ti ha scritto.

**Silenziare** è locale (`social.muted`): i post e i commenti di quella persona non si mostrano, e lei non
lo sa. **Bloccare** è sul backend ed è reciproco: nessuno dei due vede l'altro né gli scrive, e i legami
fra i due cadono. Il bloccato non viene avvisato: ogni rifiuto è lo stesso «non è stato possibile».

## Tabelle (`backend/`, migrazione di F7.2)

Tutte in `public`, RLS accesa, `anon` senza niente. Ogni `uuid` di persona è `auth.uid()`.

| Tabella | Colonne | Chi legge | Chi scrive |
|---|---|---|---|
| `profiles` | `id` (PK, → `auth.users` a cascata), `name` 2..24, `bio` ≤160, `photo` <512 null, `audience`, `messages`, `since date`, `totals jsonb`, `streak jsonb`, `week_id`, `week_chapters`, `month_id`, `month_chapters`, `genres jsonb` (≤8 di `{name<40, share 0..100}`), `kinds jsonb`, `series jsonb` null (≤10 di `{title<120, chapters}`), `activity jsonb` null (14 interi), `updated_at` (del backend) | `vede(io, id)` | solo `id = auth.uid()` |
| `follows` | `follower`, `followee` (PK insieme, → `profiles` a cascata, diversi), `follower_name` (lo mette il backend dal profilo), `at` | i due | inserisce e rinomina chi segue; toglie uno dei due |
| `blocks` | `blocker`, `blocked` (PK, → `auth.users`), `at` | solo chi blocca | solo chi blocca |
| `posts` | `id`, `author` (→ `profiles` a cascata), `kind` (`note`, `review`, `recommendation`), `body` 1..2000, `series_ref` e `series_title` <120 null, `rating` 1..10 null, `spoiler`, `chapter numeric` null, `at`, `likes`, `comments`, `flags` (i tre contatori: trigger) | `vede(io, author)` | inserisce e toglie l'autore; **nessuno modifica** |
| `comments` | `id`, `post` (→ a cascata), `author`, `parent` null (→ `comments` a cascata), `body` 1..1000, `spoiler`, `chapter`, `at`, `likes`, `flags` | chi vede il post, senza blocco con l'autore | inserisce chi vede il post; toglie l'autore **o l'autore del post** |
| `likes` | `uid`, `post` null, `comment` null (uno solo dei due; unico per persona e oggetto), `at` | solo i propri | solo i propri, su ciò che si vede |
| `messages` | `id`, `sender`, `recipient` (→ `profiles` a cascata), `kind` (`text`, `extension`), `body` 1..2000, `share` <64 null, `at`, `read_at` null | i due | inserisce il mittente (regole sotto); `read_at` solo il destinatario; toglie uno dei due |
| `reports` | `id`, `reporter` (→ `auth.users`, `SET NULL`), `target` (`user`, `post`, `comment`, `message`), `target_id` null, `target_user`, `reason`, `note` ≤500, `snapshot` ≤2000, `at`; una per persona e oggetto; l'oggetto deve essere visibile a chi segnala e `target_user` il suo autore | **nessuno** dall'app | inserisce chi segnala |

- **Le regole usano funzioni `SECURITY DEFINER`** (`search_path` vuoto, come `kagami_me()`), perché una
  regola che rilegge la sua stessa tabella ricorre: `kagami_sees(uuid)` (la tabella sopra),
  `kagami_blocked(uuid, uuid)` (in un verso o nell'altro), `kagami_accepts(uuid)` (se quel destinatario
  accetta un mio messaggio). Solo `authenticated` le esegue, e rispondono solo di `auth.uid()`.
- **I contatori li tiene il backend**, con trigger: `likes` e `comments` sui post, `likes` sui commenti,
  `flags` (persone diverse che hanno segnalato). L'app non ha il permesso di scriverli (permessi per
  colonna), quindi non si contano mi piace finti. Da `Post.flagged` segnalazioni in su l'app mostra il
  contenuto coperto, con un tocco per vederlo: non lo toglie, perché cinque account non devono poter
  cancellare qualcuno.
- **Un post non si modifica**: si toglie e si riscrive. Un contenuto segnalato non cambia sotto la
  segnalazione, che comunque ne porta una copia (`snapshot`).
- **Messaggi.** Si inserisce se nessuno dei due ha bloccato l'altro e: (`text`) il destinatario mi
  accetta — per il suo `messages`, o perché mi ha già scritto lui; (`extension`) esiste la riga
  `drive_shares` con `id = share`, `from_uid = recipient` e `to_email = kagami_me()`: chi legge una
  libreria condivisa può chiedere più tempo a chi gliela condivide qualunque sia il suo `messages`, e non
  più di una volta al giorno per condivisione (`docs/drive.md`). Il proprietario rinnova dal messaggio
  (`DriveAccess.renew` sulla riga che `share` indica) o blocca. `messages` entra nel realtime, filtrato
  per `recipient`.
- **Limiti di frequenza**: 20 post al giorno, 60 commenti l'ora, 60 messaggi l'ora, 20 segnalazioni al
  giorno, 500 persone seguite in tutto, e (0008) 30 inviti e 30 condivisioni nuove al giorno per mittente, al più
  2 righe `readers` per account (un rinnovo, cioè un upsert su un id esistente, non conta). Oltre, la scrittura è rifiutata con lo stesso `42501` di una regola.
  Stanno in un trigger (`kagami_quota`) e non nelle regole: la sottoquery di una regola non vede le righe
  che lo stesso `INSERT` ha già scritto, e un inserimento di molte righe in una richiesta passerebbe.
  `kagami_me()` (0008) dà l'indirizzo solo a un account non anonimo, con email confermata e Google come
  unico provider: un account con email e password non eredita inviti e condivisioni di un indirizzo.
- **Una risposta** sta sotto lo stesso post del commento a cui risponde: lo tiene la chiave esterna
  `(parent, post)`, perché una regola su `comments` non può rileggere `comments` (ricorre).
- **Bloccare** toglie con un trigger i due legami fra le persone, nello stesso istante.
- **Classifiche** = letture di `profiles` ordinate: settimana (`week_id = eq.<adesso>`, per
  `week_chapters`), mese, sempre (colonna generata `total_chapters`), giorni di fila (`streak_current`).
  Chi non pubblica da una settimana esce da sola dalla classifica della settimana. La RLS le filtra: ognuno
  vede la classifica di chi può vedere. Indici sulle quattro. Il seguito («solo chi seguo») è la vista
  `following_posts` (`security_invoker`, su `posts` e `follows`): un filtro `author=in.(…)` con 500 persone
  non starebbe in un indirizzo.
- **Le segnalazioni le legge chi gestisce il backend** (`service_role`): l'app non ha un pannello di
  moderazione. Va scritto in `backend/README.md`.

### Casi che `backend/rls-test.sql` deve provare

Chi non ha un profilo non legge nessuna tabella del social. I tre livelli di `audience`, ognuno nei due
versi. Un bloccato non vede profilo, post e commenti, non segue, non scrive; il blocco toglie i legami.
Nessuno scrive a nome di un altro (profilo, post, commento, mi piace, messaggio, segnalazione). I
contatori non si scrivono a mano. Il padrone del post toglie un commento altrui, un terzo no. Un
messaggio a chi non lo accetta è rifiutato; la risposta a chi ha scritto passa; la richiesta di proroga
passa solo con la riga `drive_shares` giusta. `read_at` lo scrive solo il destinatario. Le segnalazioni
non si rileggono. Uscire cancella tutto il proprio e lascia i blocchi. Una riga fuori forma è respinta.

## Sul telefono

- **Impostazioni** (`SocialSettings`, chiavi `social.*` nel database, quindi in backup e account):
  `enabled`, `name`, `bio`, `audience`, `messages`, `showPhoto`, `showSeries`, `showActivity`, `muted`.
  Una chiave che manca o non si capisce vale il valore più chiuso. I legami **non** sono un'impostazione:
  stanno sul backend, perché da loro dipende chi vede cosa.
- **Profilo**: `buildPublicProfile(uid, settings, statistics, series, hidden, now, photo)`, pura. Le
  statistiche si chiedono con `StatisticsRepository.load(excluding: nascoste)`; le serie con ciò che la
  libreria sa (`ProfileSeries`). Generi: peso in centesimi sui capitoli letti, i primi otto. Settimana ISO
  (`weekId`), mese (`monthId`).
- **Fra due lettori**, calcolato sul telefono da due profili già visibili: `affinity` (generi in comune,
  0..100) e `inCommon` (titoli che tutti e due mostrano). Due lettori parlano della stessa serie se
  `seriesRef(titolo)` coincide: ognuno ha la sua libreria e la sua chiave, in comune c'è solo il titolo.
- **Spoiler**: post e commenti hanno `spoiler` e, se chi scrive lo dice, il capitolo fino a cui
  raccontano. `Spoilable.concealedFor(progresso)` li copre finché chi legge non c'è arrivato; senza la
  serie in libreria, o senza capitolo dichiarato, restano coperti con l'avviso.
- **Errori**: `SocialUnavailable` (il backend non ha il social: lo si scopre **leggendo** — tabella
  assente o non concessa — la sezione lo dice e non riprova a ogni avvio) e `SocialRefused` (una
  **scrittura** che le regole non ammettono, dove le letture funzionano: blocco, limite, messaggi non
  accettati). Sul filo sono lo stesso `42501`: li distingue l'operazione, non il codice.
- **Interfacce** (`backend.dart`): `SocialBackend` (profili, classifiche, ricerca, legami, blocchi),
  `SocialPosts`, `SocialMessages`, `SocialReports`. Ognuna ha la realizzazione sul backend e una in
  memoria per i test, scritte dalla voce che la usa.

## Chi fa cosa (voci di `handoff/raccolte-social-sorgenti/`)

| Voce | Cosa |
|---|---|
| F7.2 | tutta la migrazione (le otto tabelle, funzioni, trigger, regole, casi RLS); `HestiaSocial` e `MemorySocial` per `SocialBackend`; pubblicazione nei tre momenti; uscita |
| F7.3, F7.4 | piano, mockup e schermata «Comunità»: adesione con anteprima, classifiche, profilo, feed |
| F7.5 | segui, «solo chi seguo», affinità, in comune, silenzia |
| F7.7 | `SocialMessages` (backend e memoria), conversazioni, non letti, richiesta di proroga |
| F7.8 | `SocialPosts` (backend e memoria), post, commenti, risposte, mi piace, spoiler, post sulla scheda di una serie non nascosta |
| F7.9 | `SocialReports`, blocca e segnala dall'interfaccia, contenuti coperti da `flags` |
| F7.10 | Impostazioni → Privacy e Comunità: acceso/spento con ciò che cancella, pubblico, interruttori, chi può scrivermi |
| F7.11 | soprannome sul commento (`author_name`, migrazione 0006), «Profilo privato» toccandolo |

F7.10 è `lib/src/ui/privacy_screen.dart`: l'interruttore della Comunità (spegnere chiede conferma e cancella dal
backend, accendere vuole soprannome e account, altrimenti rimanda a Comunità), `SocialVisibilityControls` (livello e
interruttori, lo stesso blocco dell'invito di Comunità), chi può scrivermi (`MessagePolicy`) e l'elenco dei
bloccati. Il backend conosce dei bloccati solo l'`uid`: il soprannome si salva sul telefono al momento del blocco
(`social.blockedNames`, JSON uid → nome, `setBlocked(..., name:)`) e senza di lui l'elenco dice «Persona bloccata».
Le scelte valgono anche a Comunità spenta: si salvano e si applicano quando la si accende.

## Fuori, per scelta

Chat di gruppo; notifiche push dal backend; contatori pubblici di seguaci (i legami li vedono solo i
due: niente gara di popolarità, e una regola in meno); modifica dei post; ricerca per email; un pannello
di moderazione nell'app; ripubblicazioni e hashtag.

## Non provato

Solo i tipi e `buildPublicProfile` (`test/social_profile_test.dart`). Post, commenti e mi piace (F7.8:
`HestiaPosts`, `MemoryPosts`, `lib/src/ui/social_posts.dart`) sono provati in memoria
(`test/social_posts_test.dart`); `HestiaPosts` contro un PostgREST vero no. Il soprannome sul commento (F7.11)
è provato da `backend/rls-test.sql` e in memoria (`test/social_comment_author_test.dart`). Le regole diventano vere con la
migrazione di F7.2 e i suoi casi in `backend/rls-test.sql`; a schermo e con due account, col collaudo F7.6.
