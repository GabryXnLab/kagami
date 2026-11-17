# Catalogo dei siti — definizioni firmate, aggiornate a distanza

Un sito di manga cambia forma senza avvisare (Coffee Manga, 2026-10-28:
`handoff/siti-che-cambiano/`). Con i soli siti inclusi la correzione arriva con
una release, cioè dopo giorni; con i siti degli utenti (`docs/siti.md`) arriva
solo a chi ha installato il file giusto. Il **catalogo** è il terzo modo: un
elenco di definizioni di siti, nello stesso formato di `docs/siti.md`, firmato
da chi compila e pubblicato a un indirizzo che l'app e il server ricontrollano
da soli. Una correzione pubblicata lì arriva a tutti in pochi minuti, senza
ricompilare niente.

Questo documento è l'originale del formato del catalogo: un campo nuovo si
aggiunge prima qui, poi in `packages/kagami_archive/lib/catalog.dart` (chi
legge) e nello strumento che lo scrive (`tool/catalog.dart`). Il formato delle
singole definizioni resta quello di `docs/siti.md`.

## Facoltativo, di chi compila

Il catalogo esiste solo se chi compila lo configura. Il sorgente pubblico non
ne nomina nessuno: senza configurazione l'app e il server hanno i siti inclusi e
quelli degli utenti, e sono completi (`CLAUDE.md`, «Kagami è indipendente»).
Le build del manutentore ricevono i valori da `build.yml`; un fork usa i suoi o
nessuno.

| Dove | Indirizzi | Chiavi pubbliche |
|---|---|---|
| App | `--dart-define=CATALOG_URLS=…` | `--dart-define=CATALOG_KEYS=…` |
| Server, immagine | build-arg `CATALOG_URLS` | build-arg `CATALOG_KEYS` |
| Server, contenitore | `KAGAMI_CATALOG_URLS` (vince sul build-arg) | `KAGAMI_CATALOG_KEYS` |

- `CATALOG_URLS`: uno o più indirizzi `https` separati da virgole, ognuno la
  **cartella** del catalogo (l'indice sta in `<url>/index.json`). Il primo è la
  fonte primaria, gli altri specchi con lo stesso contenuto.
- `CATALOG_KEYS`: una o più chiavi pubbliche RSA separate da virgole, ognuna
  `<kid>.<n>.<e>`: `kid` un nome di lettere minuscole, cifre e `-` (al più 32),
  `n` ed `e` modulo ed esponente in base64url senza `=`, come in un JWK. Più
  chiavi servono alla rotazione (sotto, «Firma»). Modulo di almeno 3072 bit;
  una chiave più corta si scarta.
- Uno dei due vuoto, o nessuna chiave valida: niente catalogo. Una variabile
  mal scritta non ferma l'app né il server, spegne solo il catalogo, e chi la
  legge lo registra.

Il server con `KAGAMI_CATALOG_URLS` vuoto ma presente spegne il catalogo
dell'immagine: è il modo per chi installa di non fidarsi di quello di chi l'ha
compilata.

## I file

Nella cartella del catalogo:

```text
<url>/
  index.json
  index.sig
  sites/
    coffeemanga-7.json
    mangak-3.json
```

Solo `index.json` e `index.sig` hanno un nome fisso; le definizioni stanno dove
dice l'indice (`path`, relativo alla cartella). Nomi con la versione, mai
riscritti: un cliente che ha appena letto l'indice vecchio trova ancora i file
che quello nomina. Si pubblica prima `sites/`, poi `index.sig` e `index.json`
insieme (scambio atomico, vedi P8 in `handoff/provider-remoti/`).

### `index.json`

```json
{
  "catalog": 1,
  "serial": 42,
  "issuedAt": "2026-11-15T09:30:00Z",
  "sites": {
    "coffeemanga": {
      "state": "ok",
      "variants": [
        {"version": 7, "minEngine": 2, "sha256": "9f2c…(64 cifre esadecimali)", "path": "sites/coffeemanga-7.json"},
        {"version": 6, "minEngine": 1, "sha256": "41aa…", "path": "sites/coffeemanga-6.json"}
      ]
    },
    "mangak": {
      "state": "broken",
      "message": "MangaK non risponde dal 2026-11-14; correzione in arrivo.",
      "variants": [
        {"version": 3, "minEngine": 1, "sha256": "07be…", "path": "sites/mangak-3.json"}
      ]
    }
  }
}
```

- `catalog`: la versione di questo formato, oggi `1`. Un cliente che non la
  conosce tiene il catalogo che ha già, come per un catalogo irraggiungibile.
- `serial`: intero che cresce a ogni pubblicazione. È ciò che difende dal
  ritorno indietro (sotto, «Adozione»), non `issuedAt`.
- `issuedAt`: quando è stato firmato, ISO 8601 in UTC. Solo da mostrare
  («catalogo del 15 novembre»): gli orologi dei telefoni sbagliano, quindi non
  decide niente.
- `sites`: per id di sito (lo stesso `id` del file della definizione, regole di
  `docs/siti.md`), al più 200.
  - `state`: `ok` o `broken`. `broken` dice che il manutentore sa che il sito non
    va: l'app mostra `message` nella pagina Siti e nell'errore delle serie di
    quel sito, invece di «il sito è cambiato» generico, e non apre segnalazioni
    nuove. Il sito resta usabile: per qualcuno potrebbe ancora funzionare, e la
    variante pubblicata è l'ultima migliore.
  - `message`: facoltativo, al più 300 caratteri, nella lingua del manutentore
    (non si traduce: arriva dopo la release).
  - `builtin`: facoltativo, `on` (default) o `off`. Con `off` il registro non
    ripiega sul sito incluso quando la definizione del catalogo fallisce
    (sotto, «Il registro: chi vince»). I clienti che non conoscono il campo lo
    ignorano, come ogni campo sconosciuto.
  - `variants`: da 1 a 8. `version` è la `version` della definizione (deve
    coincidere con quella nel file); `minEngine` l'`engine` più basso che sa
    interpretarla; `sha256` l'impronta dei byte del file, in esadecimale
    minuscolo; `path` il percorso relativo, senza `..` né `/` iniziale.

Campi sconosciuti si ignorano, in radice come nei siti: un campo nuovo non
deve spegnere il catalogo dei clienti di prima. Un valore di tipo sbagliato in
un campo noto invece invalida l'indice intero.

Tetti: `index.json` al più 1 MB, `index.sig` al più 64 KB (ogni riga costa una
verifica RSA), ogni definizione al più 256 KB (le definizioni di oggi pesano
pochi KB). Un file più grande si rifiuta senza leggerlo tutto. L'interprete
accetta fino a 256 KB una definizione che gli arriva con la voce del catalogo
(`catalog`), mentre quella di un sito dell'utente resta a 64 KB.

Regole strette, perché un indice firmato male si rifiuta intero invece di
leggerlo a metà: `issuedAt` obbligatorio e valido; `serial` intero da 0;
`version` e `minEngine` da 1; due varianti con la stessa `version` invalidano
l'indice; gli id seguono `docs/siti.md` (`[a-z0-9]{1,32}`); in `path` niente
`\`, `:`, `?`, `#`, `%`, segmenti vuoti, `.` o `..`.

### `index.sig`

Una o più righe `<kid> <firma>`: `kid` come in `CATALOG_KEYS`, la firma
RSASSA-PKCS1-v1_5 con SHA-256 (RFC 8017) dei **byte esatti** di `index.json`,
in base64url senza `=`. L'indice è valido se almeno una riga ha un `kid` noto e
una firma che si verifica con quella chiave; le righe con `kid` sconosciuti si
ignorano.

Una firma sola copre tutto: le definizioni sono legate all'indice dal loro
`sha256`. Un file in `sites/` cambiato, anche da chi ospita, non passa.

Rotazione: si aggiunge la chiave nuova a `CATALOG_KEYS` in una release, si
firma con le due chiavi (due righe) finché le versioni con la sola chiave
vecchia sono in giro, poi si firma con la nuova e la vecchia esce dalla
configurazione. Una chiave compromessa si toglie dalla configurazione con una
release: fino ad allora chi la ha può pubblicare, ed è il rischio accettato.

Si usa RSA perché il server ha già la verifica (JWT di Google e di Hestia) e il
pacchetto resta Dart puro, solo con `crypto`; Ed25519 vorrebbe una dipendenza
crittografica in più (`server/CLAUDE.md`). Il codice è
`packages/kagami_archive/lib/signature.dart`.

## `engine` e varianti

`engine` è un intero del pacchetto (`catalogEngine` in `catalog.dart`): quante
primitive del formato dei siti sa interpretare quella versione del motore.
`1` è il formato 1, oggi è `6` (variabili e modelli, ripieghi, filtri e condizioni, schemi di host, JSON dentro un testo: `docs/siti.md`); ogni primitiva nuova (formato 2,
pagina resa) lo alza di uno, e `docs/siti.md` tiene la tabella primitiva →
`engine` da cui la prende.

Per ogni sito il cliente prende, fra le varianti con `minEngine ≤ engine`, quella
con la `version` più alta. Così una correzione che usa una primitiva nuova
convive con una variante più povera per le app non aggiornate: il manutentore
pubblica le due, e ognuno prende la sua. Se nessuna variante va bene, il cliente
tiene l'ultima buona che aveva per quel sito o, se non ne aveva, il sito
incluso; la pagina Siti dice «serve Kagami più nuovo» per quel sito.

`minEngine` lo calcola lo strumento (`tool/catalog.dart build`) dalle chiavi che
la definizione usa, non chi la scrive: un numero sbagliato a mano farebbe
fallire la lettura nelle app vecchie invece di saltare la variante.

Lo strumento (`packages/kagami_archive/tool/catalog.dart`, `dart run tool/catalog.dart`) ha `build`, `sign`, `verify` e `pubkey`. La chiave privata è un PEM di `openssl genrsa -out catalogo.pem 3072` (PKCS#1 o PKCS#8, fuori da git); `pubkey catalogo.pem --kid K` stampa la voce per `CATALOG_KEYS`.

## Stato dei siti: `catalog/status.json`

`state`, `message` e `builtin` dell'indice non stanno nelle
definizioni, perché cambiano senza che la definizione cambi (un annuncio
`broken` non è una versione nuova del sito). Li tiene un file in git,
`catalog/status.json`, accanto a `catalog/sites/`:

```json
{
  "sites": {
    "mangak": {"state": "broken", "message": "MangaK non risponde dal 2026-11-14; correzione in arrivo.", "builtin": "on"},
    "asurascans": {"state": "ok", "builtin": "off"}
  }
}
```

Un sito che non c'è vale `state: "ok"`, `builtin: "on"`, senza messaggio;
un id che non ha una definizione in `catalog/sites/` è un errore, perché è
quasi sempre un nome sbagliato. `build` lo legge e scrive `state` e `message`
nell'indice, e `builtin` solo quando è `off`; così l'annuncio rapido diventa un
commit di una riga invece di una modifica a mano dell'indice prima di `sign`,
e la storia degli stati è nella storia di git.

`build` fa in più due controlli contro `--previous`:

- una variante con la stessa `version` di una pubblicata ma uno `sha256`
  diverso si rifiuta: un file pubblicato non si riscrive mai, e chi ha
  corretto senza alzare `version` lo scopre qui invece che su un telefono;
- stampa gli host che una definizione nuova nomina (`hosts`, `mediaHosts`,
  host degli indirizzi composti) e che la variante pubblicata prima non
  nominava. Non è un errore, ma è la riga da leggere prima della firma: un
  host nuovo è il modo in cui una definizione sbagliata o ostile manda il
  telefono altrove.

## Il registro: chi vince

I siti che l'app e il server conoscono sono tre strati
(`packages/kagami_archive/lib/providers.dart`, `providers`):

1. inclusi (`builtInProviders`, Dart);
2. catalogo: una definizione con l'id di un incluso lo sostituisce, una nuova si
   aggiunge;
3. utenti confermati (`docs/siti.md`): stanno sopra il catalogo con lo stesso id.

Il catalogo scavalca l'incluso **senza** chiedere conferma all'utente, a
differenza di un sito dell'utente (`site-replacements.json`): la firma dice che
viene da chi ha compilato l'app, cioè dalla stessa fonte del codice incluso.
L'utente può spegnere il catalogo intero dalla pagina Siti (interruttore,
ricordato sul telefono): allora valgono inclusi e suoi.

I provider Dart non si tolgono quando un sito passa al catalogo: restano il
ripiego di chi non ha catalogo, delle build senza configurazione e del primo
avvio senza rete.

**Auto-ripiego** (`packages/kagami_archive/lib/fallback.dart`): se la
definizione del catalogo dà un `ProviderChanged` e sotto c'è un sito incluso
con lo stesso id, il registro ripete l'operazione una volta con l'incluso. Se
riesce vale il suo esito; se fallisce anche lui vale l'errore del catalogo,
che è quello da correggere. Serve quando una pubblicazione è sbagliata: il
catalogo arriva a tutti in pochi minuti, e senza ripiego una definizione sbagliata
spegnerebbe un sito che il codice incluso sapeva ancora leggere. Errori di rete
e di stato non fanno ripiegare: l'incluso parla allo stesso sito e fallirebbe
uguale.
Vale per `fetchSeries`, `fetchPages` e `search`; un ripiego riuscito lascia
`layer:builtIn` nella traccia (il `degraded` della sonda). Per le tavole i
`metadata` del capitolo li ha scritti il catalogo: se all'incluso non bastano,
fallisce e vale l'errore del catalogo. Un incluso che dà alla serie un id
diverso da quello del catalogo non vale come ripiego: l'id è il primo gruppo di
`series.path` sul link, o con `series.id` quello che il catalogo ha letto dalla
pagina prima di cadere. Se con `series.id` il catalogo non è arrivato a leggerlo,
l'identità non si può verificare e il ripiego non vale nemmeno lì.

Si spegne per sito con `builtin: "off"` nell'indice, quando la correzione
cambia l'identità delle serie (`docs/malf.md` § Cambi d'identità): l'incluso
darebbe agli stessi capitoli gli id di prima, e mescolare le due forme nella
stessa libreria è peggio di un errore. I siti dell'utente non ripiegano mai:
sono una scelta sua, e un incluso sotto non lo è.

Le serie non cambiano chiave: restano `<id>:<id serie>` qualunque strato serva
il sito. Una definizione che dà alle serie un id diverso è un cambio d'identità
(`docs/malf.md` § Cambi d'identità), come per un sito dell'utente.

Un sito del catalogo ha i tetti di un sito di fiducia (fino a 32 richieste per
operazione invece di 8, risposte fino a 8 MB invece di 2, tempo invariato), perché è firmato; uno dell'utente
quelli di `declarative.dart`.

## Adozione

Il catalogo si scarica e si sostituisce al vecchio solo se tutto torna, e una
lettura fallita non è un catalogo vuoto (`CLAUDE.md`, «Adozione, non
sovrascrittura»):

1. `GET <url>/index.json` con `If-None-Match` dell'ETag di prima: `304` vuol dire
   niente di nuovo. Errore di rete, `5xx`, risposta troppo grande: si prova
   l'indirizzo dopo; se nessuno risponde si tiene la cache.
2. `GET <url>/index.sig`, verifica della firma. Firma assente o falsa: quel
   indirizzo è scartato come irraggiungibile, si prova il successivo.
3. `serial` minore di quello già adottato: si rifiuta (anti-rollback). Uguale,
   con byte diversi: si rifiuta. Uguale e uguale: niente di nuovo. Un ritorno a
   una definizione vecchia si fa ripubblicandola con un `serial` più alto.
4. Per ogni sito, la variante scelta (sopra): se il suo `sha256` è già in cache
   non si scarica; altrimenti `GET <url>/<path>`, verifica dell'impronta,
   lettura con l'interprete (`declarative.dart`) e controllo che `id` e
   `version` coincidano con l'indice. Un sito che fallisce tiene la sua variante
   di prima, gli altri passano alla nuova.
5. Solo alla fine si scrivono in cache l'indice, la firma e le definizioni
   nuove, e il registro passa al catalogo nuovo. Le definizioni non più nominate
   si cancellano dalla cache dopo.

Il `serial` adottato e l'ETag stanno accanto alla cache. Un catalogo
irraggiungibile per sempre non spegne nulla: la cache resta valida
indefinitamente, perché la firma non scade.

## Cache

Fuori dalla libreria, mai su Drive: il catalogo è di chi ha compilato l'app, non
dei dati dell'utente, e scriverlo in `providers/` chiederebbe Drive in scrittura
e sporcherebbe la cartella.

- Telefono: `catalog/` nella cartella di supporto dell'app
  (`getApplicationSupportDirectory`), con `index.json`, `index.sig`,
  `state.json` (`serial`, ETag, ora dell'ultimo controllo) e `sites/<sha256>.json`.
  Al primo avvio, senza cache, valgono gli inclusi finché il primo recupero non
  va a buon fine.
- Server: `catalog/` nel volume dei dati, stessa forma, una per tutto il server
  (non per account: il catalogo è dell'immagine, non degli utenti).

## Quando si ricontrolla

- all'avvio dell'app e a ogni giro di sfondo del telefono;
- sul server, prima di ogni giro e di ogni controllo;
- subito quando un'operazione su un sito fallisce con `ProviderChanged`
  (`packages/kagami_archive/lib/model.dart`), al più una volta ogni 10 minuti,
  e se c'è una variante nuova di quel sito l'operazione si ritenta una volta.

Con l'ETag un controllo senza novità costa una richiesta e nessun byte di
corpo. Con un DSN di Sentry configurato, i `ProviderChanged` portano i tag
`site` e `version` (della definizione in uso), così l'allarme dice quale
variante si è rotta.

## Sul server

Il server dichiara il catalogo in `/v2/server` (`docs/server-api.md`): la
funzione `catalog` fra le `features` e il campo `catalog` con `engine` e
`serial` del catalogo adottato (`serial` `0` se non ne ha). L'app confronta:
se il server ha un `engine` più basso del suo, o un `serial` più vecchio di
quello del telefono per un sito che il telefono prende dal catalogo, quei lavori
li tiene sul telefono (`engineForSite`, `lib/src/data/user_sites.dart`), come
già fa per i siti degli utenti con un server che non li conosce.

## Norma di Google Play

Letta il 2026-11-15 a
<https://support.google.com/googleplay/android-developer/answer/9888379?hl=en>
(«Device and Network Abuse»). Il divieto:

> "An app distributed via Google Play may not modify, replace, or update itself
> using any method other than Google Play's update mechanism. Likewise, an app
> may not download executable code (such as dex, JAR, .so files) from a source
> other than Google Play."

L'eccezione:

> "This restriction does not apply to code that runs in a virtual machine or an
> interpreter where either provides indirect access to Android APIs (such as
> JavaScript in a webview or browser)."

E subito dopo, per i linguaggi interpretati caricati a runtime: "must not allow
potential violations of Google Play policies".

La pagina non parla di file di configurazione né di dati scaricati: riguarda il
codice eseguibile. Una definizione del catalogo non è codice: è un documento
JSON che dice dove stanno i dati nelle pagine, letto da un interprete senza cicli
né funzioni (`docs/siti.md`), quindi configurazione come i parametri remoti di
qualunque app; e anche letta come codice interpretato starebbe nell'eccezione,
perché non tocca le API di Android. Il rischio su Play resta il contenuto (i
siti a cui l'app accede, coperti dall'ultima frase citata), non il meccanismo.
Il motore di script (QuickJS) è rinviato anche per questo: sarebbe una libreria
nativa inclusa, ammessa, ma con codice scaricato da giustificare.

## Temi

Più siti dello stesso motore (stesso tema WordPress, stessa API) condividono quasi tutta la
definizione. Il catalogo non lo sa: i temi esistono **solo a tempo di build**, nel sorgente.

- `catalog/themes/<nome>.json` è una definizione parziale: tutto tranne `id`, `name`, `version`,
  `home`, `hosts` (e senza `extends`).
- Un sorgente in `catalog/sites/` può avere `"extends": "<nome>"` (uno solo, niente catene). `build`
  lo fonde col tema: oggetti in merge profondo, il sito vince, le liste si sostituiscono intere,
  `null` nel sito toglie la chiave del tema. `extends` sparisce dal risultato.
- Il risultato deve essere una definizione valida (stesso controllo dell'installazione) e **è la
  definizione piatta che si pubblica**: `sha256`, `minEngine` e lint si calcolano su di essa. Client,
  cache, firma ed engine non cambiano, e `extends` non è una chiave del formato (`docs/siti.md`).
- Un tema cambiato cambia lo sha di ogni sito che lo estende; il controllo «stessa `version` con
  sha diverso = errore» obbliga allora a `version`+1: `dart run tool/site.dart bump --theme <nome>
  [--sites catalog/sites]` lo fa riscrivendo solo il numero. `dart run tool/site.dart flatten <sito.json>
  [--themes dir]` stampa la definizione piatta; `check` e `lint` accettano anche il sorgente.
- `build --themes <cartella>` sostituisce la cartella dei temi (di norma `catalog/themes/` accanto a `sites/`).

## Fuori da qui

- Formato delle definizioni e tabella primitiva → `engine`: `docs/siti.md`.
- Funzione `catalog` di `/v2/server`: `docs/server-api.md`.
- Ospitalità: la fonte primaria è il bucket di Hestia; lo specchio è il ramo `catalog` del repo pubblico (solo la cartella pubblicata alla radice), verificato a ogni push da `.github/workflows/catalog.yml` con `CATALOG_KEYS`. `CATALOG_URLS` può elencare entrambi (per il ramo, l'indirizzo raw).
- Come si ripara un sito e si pubblica il catalogo: `docs/manutenzione-siti.md`
  (voce P6.3).
