# Manutenzione dei siti — dall'allarme della sentinella al catalogo corretto

Questa è la procedura per chi riceve l'allarme che un sito si è rotto: il
manutentore o il suo agente. Lega i pezzi che esistono: la sentinella
(`kagami-server probe`, `docs/server.md` § «La sentinella dei siti»), lo
strumento delle definizioni (`packages/kagami_archive/tool/site.dart`), quello
del catalogo (`tool/catalog.dart`), le cassette
(`packages/kagami_archive/test/fixtures/sites/`) e il formato del catalogo
(`docs/catalogo.md`). Il formato delle definizioni è in `docs/siti.md`.

Il principio: una correzione arriva a tutti in pochi minuti, quindi un errore
pure. Ogni passo sotto esiste per fermare un catalogo sbagliato **prima** che
lo adotti un telefono, perché dopo l'unico rimedio è ripubblicare con un
`serial` più alto, e nel frattempo chi l'ha adottato ha un sito rotto.

Se `catalog/sites/` o i test non sono nel clone, i comandi sotto non girano:
si lavora dal repo con `packages/kagami_archive` come cartella corrente, salvo
dove è detto altro.

## In breve

```text
allarme (probe --json: status, phase, fault, degraded; cassetta del guasto con --capture)
  → triage offline: probe --definition, site.dart check --replay sulle cassette
      riprodotto offline → la causa è nella definizione
  → solo se la forma è cambiata: HAR da qualunque strumento → site.dart har
      → inventario + cassetta di scoperta; poi check --live --record per la cassetta dei test
  → correzione di catalog/sites/<id>.json (version+1, strategie che resistono, temi)
  → cancelli: check --replay su TUTTE le cassette del sito, check --live, lint,
      catalog.dart build --check (rilettura degli host nuovi)
  → sign → verify → pubblicazione (bucket, poi specchio) → sonda verde → nota
```

Se la correzione chiede tempo, prima di tutto si pubblica lo stato `broken`
(sotto, «Annuncio rapido»): costa cinque minuti e toglie agli utenti l'errore
generico.

## 1. Allarme

La sentinella è `kagami-server probe --json`. Pianificarla, mandare gli avvisi
e aprire una sessione dell'agente sono compito di **Iris** (voce P8.2 di
`handoff/provider-remoti/`, **non ancora fatta**: finché non c'è, la sonda si
lancia a mano e nessuno avvisa). Va lanciata da due punti di vista, un server in datacenter
e casa, perché da un IP di datacenter Cloudflare dà falsi `gated`.

L'immagine contiene `catalog/canaries.json`, il default di `--canaries`, quindi
dentro il contenitore non serve copiare niente:

```bash
docker exec kagami-server kagami-server probe --json
docker exec kagami-server kagami-server probe --site mangak --capture /data/guasti
```

`--capture <dir>` registra, per ogni sito non `ok`, il giro in
`<dir>/<id>/<data>-guasto/`: la pagina del guasto com'era in quel momento,
nel formato delle cassette (sotto, «Cassette»). Si ritira dal volume del server
e si porta sotto `test/fixtures/sites/<id>/`.

Come si legge l'esito di un sito:

| `status` | Vuol dire | Cosa si fa |
|---|---|---|
| `ok` | ricerca, serie, tavole e prima immagine tornano | niente; se `degraded` non è vuoto, vedi sotto |
| `changed` | il sito ha cambiato forma (`ProviderChanged`, risultati vuoti, 4xx, immagine inattesa, capitoli sotto il conteggio dichiarato) | questa procedura |
| `offline` | rete, timeout, 429, 5xx | aspettare: non si tocca una definizione per un sito spento |
| `gated` | verifica di Cloudflare o 403 | confrontare con l'altro punto di vista; se è `gated` da entrambi, la definizione probabilmente non c'entra (`browser`, `docs/siti.md`) |
| `skipped` | il sito non ha un canarino | aggiungerlo a `catalog/canaries.json` |

Gli altri campi dicono dove guardare:

- `phase` (`search`, `series`, `chapters`, `pages`, `image`): quale pagina
  serve.
- `fault`: `{phase, field, detail}`, il campo della definizione rimasto senza
  valore (`series.chapters.items`, `chapter.pages.url`; `docs/siti.md`
  § «Diagnosi»). È la prima cosa da leggere: dice quale riga del file toccare.
- `degraded`: lista delle alternative di `first`/`try` che hanno vinto senza
  essere le prime (`series.title#2`). Con `ok` è un preavviso: il sito va, ma
  la ridondanza si sta consumando; si corregge prima che cada anche l'ultima
  (`docs/siti.md` § «Traccia e sito degradato»). Un conteggio di capitoli entro
  il 5% sotto quello dichiarato dal sito (`series.chapters.expect`) è
  degradato, non guasto: i buchi nella numerazione sono del sito.
- `version`, `origin`, `serial`: quale definizione era in uso. `origin` è
  `builtIn` per il provider Dart, altrimenti il catalogo con quella `version`.
  Un sito con `degraded` che include `layer:builtIn` ha ripiegato
  sull'incluso: il catalogo è già rotto e l'utente non se ne accorge (sotto,
  «Ripiego automatico»).
- Canarini multipli: i canarini falliti finiscono in `degraded` come
  `canary#<n>` e in `canaries`; un canarino solo è spesso una serie tolta, non
  un sito cambiato.

Con un DSN di Sentry configurato, i `ProviderChanged` degli utenti portano gli
stessi tag `site`, `version`, `phase` e `field` (`docs/catalogo.md` § «Quando si
ricontrolla»): servono a capire se il guasto è di tutti o di una variante sola.

Un `changed` isolato da un solo punto di vista si riprova prima di correggere:
i siti rispondono male per qualche minuto più spesso di quanto cambino.

## 2. Triage offline

Costa zero e risponde alla domanda che decide il resto: la definizione è
sbagliata, o il sito è cambiato?

```bash
cd packages/kagami_archive
# la cassetta del guasto (--capture), com'era quando la sonda ha fallito
dart run tool/site.dart check ../../catalog/sites/mangak.json --replay /percorso/<data>-guasto
# tutte le cassette già nel repo per quel sito
dart test test/catalog_cassette_test.dart --plain-name mangak
```

`check --replay` fa il giro della sonda sulla cassetta (nessuna rete) e lo
confronta con il suo `expect.json`; esce con 1 su guasto o differenza, e con
`--json` stampa l'esito per una macchina. La stessa prova si fa dal vivo, con
la definizione al posto di quella del registro, dal server:

```bash
docker cp catalog/sites/mangak.json kagami-server:/tmp/mangak.json
docker exec kagami-server kagami-server probe --json --site mangak --definition /tmp/mangak.json
```

(il `docker cp` qui serve perché la definizione corretta è nel clone, non
nell'immagine), e `--layers all` prova a parte ogni strato del sito (catalogo e
incluso): dice se l'auto-ripiego ha ancora un incluso che funziona.

Come si legge:

- **si riproduce offline** su una cassetta (anche quella del guasto): il sito
  non c'entra, la causa è nella definizione o nel motore, e `fault.field` dice
  dove. Si salta la cattura e si corregge;
- **la cassetta del guasto passa ma dal vivo fallisce**: il sito ha cambiato
  forma dopo o in modo non registrato, oppure serve un'altra pagina. Si va alla
  cattura;
- **passa dappertutto**: era un guasto passeggero o di rete; si ripete la sonda.

## 3. Cattura

Solo se la forma del sito è cambiata e serve capire dove stanno ora i dati.
L'obiettivo è un **inventario** delle richieste e una **cassetta di scoperta**.

Si parte da un HAR (HTTP Archive) di una navigazione sul sito: la ricerca, la
serie del canarino, un capitolo. Va bene qualunque strumento: «Save all as HAR
with content» dei DevTools di un browser, oppure Reverse API Engineering, un
progetto open source che fa navigare un browser da un agente e salva l'HAR. I
corpi possono stare dentro l'HAR o in file accanto.

```bash
cd packages/kagami_archive
dart run tool/site.dart har /percorso/sito.har --hosts mangak.io,api.mangak.io \
  [--definition ../../catalog/sites/mangak.json] --out /tmp/mangak-har [--json]
```

`har` tiene solo i GET sugli host dati, scrive una cassetta ripulita (stato,
tipo e corpo: niente header, cookie o token) e stampa l'inventario degli
endpoint, con `--json` per una macchina; con `--definition` lo confronta con ciò
che la definizione chiede già. Quella cassetta serve a capire, non entra nei
test: il browser ha un altro User-Agent e fa richieste diverse da quelle del
motore.

**L'HAR non entra mai nel repo**, né la sua cartella, né `--out`: contiene
cookie e token del browser. Si lavora fuori dal repo e si cancella alla fine.

La cassetta che entra nei test è un'altra, e la registra il motore (dopo la
correzione, passo 5): così contiene ciò che il motore chiede davvero.

Una pagina che arriva solo con il JavaScript (la cattura è vuota rispetto a
quello che si vede nel browser) è un segnale che la definizione ha bisogno
della pagina resa (`browser`, `docs/siti.md`) o di un `engine` nuovo: sotto,
«Engine nuovo».

## 4. Correzione in `catalog/sites/`

Si corregge `catalog/sites/<id>.json`, il sorgente della definizione, seguendo
`docs/siti.md`. Sempre:

- **`version` + 1**, anche per un ritocco di un carattere: il nome del file
  pubblicato è `<id>-<version>.json` e non si riscrive mai (sotto, «Cosa non
  fare»). Se il sito ha `extends`, cambiare il tema in `catalog/themes/` cambia
  lo sha di tutti i siti che lo estendono: `dart run tool/site.dart bump --theme
  <nome> [--sites ../../catalog/sites]` alza di 1 la `version` di ognuno,
  riscrivendo solo il numero; `dart run tool/site.dart flatten <sito.json>
  [--themes dir]` stampa la definizione piatta che verrà pubblicata
  (`docs/catalogo.md` § «Temi»);
- **strategie che resistono** (`docs/siti.md` § «Strategie che resistono»): API
  JSON prima del DOM, dati strutturati come alternative in `first`, niente
  classi con hash, identità da una fonte sola, `expect` col conteggio dei
  capitoli dove il sito lo dà. `site.dart lint` le controlla (passo 5);
- **niente `minEngine` a mano**: lo calcola `build` dalle chiavi usate; se la
  correzione usa una chiave di un `engine` più alto di quello delle app in
  giro, vedi «Engine nuovo»;
- l'`id` non cambia, e gli id delle serie nemmeno: un id di serie diverso è un
  cambio d'identità (`docs/malf.md`), non una correzione. Se proprio è
  inevitabile, `builtin: "off"` (sotto, «Ritorno indietro»).

Il provider Dart del sito (`packages/kagami_archive/lib/providers/<id>.dart`)
resta com'è: è il ripiego di chi non ha catalogo e dell'auto-ripiego. Se lo si
corregge anche lì, lo si fa in un commit a parte, e la correzione arriva con la
release.

## 5. Cancelli

Tutti, nell'ordine: ciascuno ferma qualcosa che il successivo non vede.

```bash
cd packages/kagami_archive
D=../../catalog/sites/mangak.json
# 1. la definizione nuova su TUTTE le cassette del sito (anche le vecchie)
dart run tool/site.dart check $D --replay test/fixtures/sites/mangak/<data>-<etichetta>
dart test test/catalog_cassette_test.dart test/catalog_parity_test.dart test/declarative_test.dart
# 2. dal vivo, e registrando la cassetta di oggi per i test futuri
dart run tool/site.dart check $D --live --record test/fixtures/sites/mangak/$(date +%F)-dopo-correzione
# 3. regole di robustezza
dart run tool/site.dart lint $D --canaries ../../catalog/canaries.json
# 4. analisi e test del pacchetto
dart analyze && dart test
```

- **Cassette.** `catalog_cassette_test.dart` prova ogni definizione di
  `catalog/sites/` su ogni cassetta del suo sito con un `expect.json`. Le
  cassette vecchie non si tolgono: la correzione deve leggere anche la forma di
  prima, perché il sito a volte serve le due forme a server diversi. Se la
  correzione non legge più una forma vecchia lo si decide e si scrive perché,
  nel commit che toglie quella cassetta.
- **Dal vivo.** `check --live` usa la definizione e l'User-Agent del motore,
  non quelli del browser; `--query` o `--url` scelgono la serie di prova.
  Con `--record <cartella>` salva la cassetta e scrive `expect.json` dall'esito:
  **si rilegge a mano prima del commit**, perché diventa la verità per tutte le
  definizioni che verranno. `--record` vale solo con `--live`.
- **Lint.** `lint` esce con 1 se c'è un errore (una sola strategia sui campi
  critici è un avviso, non un errore). `build` rifà lo stesso controllo e non
  scrive nulla se ci sono errori.
- **Prova a parte.** Se serve provare la correzione dal vivo con le stesse
  regole della sonda prima di pubblicarla: `kagami-server probe --definition`
  (passo 2).

Il test di parità (`test/catalog_parity_test.dart`) confronta le definizioni
con i provider Dart sugli stessi finti (`test/archive_fakes.dart`). Se il
provider Dart non è stato corretto, su una fixture nuova i due divergono per
forza: il caso confronta la definizione con l'esito atteso scritto a mano, non
con il provider, e un commento dice perché.

Commit della correzione e della cassetta insieme, prima di pubblicare: il
catalogo pubblicato deve sempre corrispondere a un commit.

### Build con controllo

Lo strumento costruisce la cartella da pubblicare dalle definizioni (con i
temi risolti) e dall'indice pubblicato adesso. `--previous` serve tre volte:
rifiuta un `serial` che non cresce, conserva le varianti di prima ancora
presenti per le app che non sanno leggere la nuova, e **blocca lo sha di ogni
`version`**: la stessa `version` con byte diversi è un errore, perché un file
pubblicato non si riscrive mai. `--check` lancia i comandi e, se falliscono,
non scrive niente.

```bash
cd packages/kagami_archive
PUB=/percorso/catalogo-pubblicato          # copia di ciò che sta nel bucket adesso
OUT=/tmp/catalogo-$(date +%Y%m%d-%H%M)     # cartella nuova, mai quella pubblicata
SERIAL=$(( $(jq .serial "$PUB/index.json") + 1 ))
dart run tool/catalog.dart build ../../catalog/sites "$OUT" --serial "$SERIAL" \
  --previous "$PUB/index.json" --check 'dart analyze && dart test'
```

Opzioni: `--status <file>` (default `catalog/status.json` accanto a `sites/`),
`--themes <cartella>` (default `catalog/themes/`).

Due cose da leggere sull'uscita prima di firmare:

- **Host nuovi.** `build` stampa gli host che la definizione nuova nomina
  (`hosts`, `mediaHosts`, host degli indirizzi composti) e che la variante
  pubblicata prima non nominava. Non è un errore, ma è la riga da guardare: un
  host nuovo è il modo in cui una definizione sbagliata o ostile manda il
  telefono altrove. Deve corrispondere a ciò che la cattura ha mostrato.
- **Il diff dell'indice**: `diff <(jq . "$PUB/index.json") <(jq . "$OUT/index.json")`
  deve mostrare solo il sito corretto, il `serial` e `issuedAt`. Un sito che
  sparisce o cambia variante senza motivo si ferma qui.

`state`, `message` e `builtin` li legge da `catalog/status.json`, non
dall'indice di prima: uno stato `broken` resta finché il file lo dice, e si
toglie con un commit che lo riporta a `ok` (vedi «Annuncio rapido»).

## 6. Firma

La chiave privata sta nei segreti di Hestia (decisione 1 dell'handoff), mai nel
repo né in un file che sopravviva alla sessione: si prende, si firma, si
cancella.

```bash
# KEY_FILE: il PEM preso dai segreti di Hestia, in una cartella temporanea con permessi 600
dart run tool/catalog.dart sign "$OUT" --kid <kid-attuale> --key "$KEY_FILE"
rm -f "$KEY_FILE"
```

`sign` controlla la firma con la chiave pubblica prima di scriverla, e aggiunge
o sostituisce la riga di quel `kid` in `index.sig`; durante una rotazione si
lancia una volta per chiave (sotto, «Chiavi»).

## 7. Verifica

La verifica è quella che faranno i clienti: firma con le chiavi delle build in
giro, sha256 di ogni file, lettura di ogni definizione, `minEngine` coerente.

```bash
dart run tool/catalog.dart verify "$OUT" --keys "$CATALOG_KEYS"
dart run tool/catalog.dart verify "$OUT" --keys "$CATALOG_KEYS" --engine 5   # come la vede un'app più vecchia
```

`CATALOG_KEYS` è lo stesso valore che `build.yml` passa alle build (le chiavi
pubbliche, non segrete). L'uscita elenca per ogni sito la variante scelta: con
`--engine` dell'app più vecchia ancora supportata si vede se quell'app riceve
qualcosa o tiene l'ultima buona.

## 8. Pubblicazione

L'ordine conta, perché un cliente può leggere a metà pubblicazione
(`docs/catalogo.md` § «I file»):

1. **`sites/`** nel bucket pubblico di Hestia: solo file nuovi, nessuno
   sovrascritto. Un cliente con l'indice vecchio trova ancora i suoi file.
2. **`index.sig` e `index.json` insieme**, con lo scambio atomico del bucket: un
   cliente vede la coppia vecchia o la nuova, mai l'indice nuovo con la firma
   vecchia (che lo farebbe scartare come falso).
3. **Specchio**: la stessa cartella, alla radice, sul ramo `catalog` del repo
   pubblico. Il push fa partire `.github/workflows/catalog.yml`, che riverifica
   firma e indice con `CATALOG_KEYS` dei secret: è il secondo paio d'occhi della
   decisione 1, e un suo rosso vuol dire ripubblicare subito con un `serial` più
   alto.

Il bucket, lo scambio atomico e l'indirizzo sotto `metisnet.dev` sono richieste
a Hestia (P8.1, `~/repos/hestia/richieste/`) e ancora non hanno un comando: il
passo 1-2 si scriverà qui quando esisteranno. Lo specchio:

```bash
cd <clone del repo pubblico>
git worktree add /tmp/catalog-branch catalog
rsync -a --delete --exclude .git "$OUT"/ /tmp/catalog-branch/
cd /tmp/catalog-branch && git add -A && git commit -m "catalogo serial $SERIAL: <sito> v<versione>"
git push origin catalog          # pubblicazione verso l'esterno: con l'assenso del proprietario
cd - && git worktree remove /tmp/catalog-branch
```

`--delete` è sicuro perché `$OUT` contiene già le varianti di prima (le ha
copiate `--previous`); i file di `sites/` che `build` ha lasciato fuori
(oltre le 8 varianti) escono anche dallo specchio, ma restano nel bucket finché
nessun indice adottabile li nomina più.

## 9. Sonda verde

Il server ricarica il catalogo prima di ogni controllo, e `probe` lo forza:

```bash
docker exec kagami-server kagami-server probe --json --site <id>
docker exec kagami-server kagami-server probe --json --site <id> --layers all
```

Si vuole `status: "ok"`, `origin` del catalogo, la `version` appena
pubblicata (e `serial` in testa all'esito) e `degraded` senza ciò che si è
appena corretto. Con `--layers all` si vede anche lo strato incluso, che deve
restare un ripiego valido. Se il server dice ancora la versione vecchia, il
bucket non serve il file nuovo (cache, ETag): non si ripubblica alla cieca, si
guarda cosa risponde `curl -sI <url>/index.json`. L'allarme si chiude quando
la sonda torna verde.

## 10. Nota

Una riga nell'handoff o nel documento del sito (`docs/siti.md` § «I siti inclusi
nel formato 2», se il sito è lì): data, che cosa era cambiato nel sito, versione
e `serial` pubblicati, cassetta aggiunta. Serve a riconoscere un sito che cambia
spesso, e a chi corregge la prossima volta.

## Coffee Manga: la chiave costante

`catalog/sites/coffeemanga.json` porta la chiave del manifest come costante (`hex` del primo passo
di `chapter.recipe`), perché il sito la calcola nel suo JavaScript. Quando la sentinella dà
`changed` sul manifest (`chapter.recipe[…]`: JSON non valido o `check` non soddisfatto), si ricava
la chiave nuova col codice del provider Dart, `dart run tool/site.dart coffeemanga-key --live` (o
`<bundle.js>` salvato), la si scrive nel file, si alza `version` di 1 e si riprende dal passo 5.
Se il comando dice che `TE()` non si trova, è cambiato il bundle: si corregge `coffeeMangaKey`.

## Ripiego automatico e `builtin: "off"`

Se la definizione del catalogo dà un `ProviderChanged` e sotto c'è un sito
incluso con lo stesso id, il registro ripete l'operazione una volta con
l'incluso (`docs/catalogo.md` § «Il registro: chi vince»). Per chi ripara vuol
dire due cose:

- una pubblicazione sbagliata non spegne subito un sito che il codice incluso
  sapeva ancora leggere: l'utente non vede il guasto, la sonda sì, come
  `degraded` con `layer:builtIn`. Il ripiego non è una correzione: va
  eseguita comunque, e finché l'incluso è rotto a sua volta (si vede con
  `probe --layers all`) il sito è giù per davvero;
- se la correzione **cambia l'identità delle serie** (`docs/malf.md`
  § «Cambi d'identità»), l'incluso darebbe agli stessi capitoli gli id di
  prima e mescolerebbe due forme nella stessa libreria, peggio di un errore:
  si pubblica la variante con `"builtin": "off"` in `catalog/status.json` per
  quel sito (`build` lo scrive nell'indice). Errori di rete e di stato non
  fanno ripiegare, e i siti dell'utente non ripiegano mai.

## Annuncio rapido: `broken` con messaggio

Se la correzione non si chiude in poco, si pubblica subito lo stesso catalogo
con il sito in `broken` e un `message` (al più 300 caratteri, in italiano: non
si traduce). L'app mostra il messaggio al posto di «il sito è cambiato» e non
apre segnalazioni nuove; il sito resta usabile, con la variante che ha.

Si modifica `catalog/status.json` (un commit di una riga) e si rifà `build`,
che scrive `state` e `message` nell'indice:

```json
{"sites": {"mangak": {"state": "broken", "message": "MangaK è cambiato il 15 novembre: correzione in arrivo."}}}
```

```bash
cd packages/kagami_archive
dart run tool/catalog.dart build ../../catalog/sites "$OUT" --serial "$SERIAL" --previous "$PUB/index.json"
# poi sign, verify, pubblicazione come sopra
```

Un id che non ha una definizione in `catalog/sites/` fa fallire `build`. La
firma copre i byte dell'indice: non si ritocca dopo `build`.

La correzione vera, quando arriva, si pubblica togliendo la voce da
`status.json`: lo stato torna `ok`.

## Engine nuovo: la variante doppia

Una correzione che ha bisogno di una primitiva che le app in giro non hanno
(una chiave con un `engine` più alto, tabella in `docs/siti.md` § «Compatibilità
ed `engine`») non arriva a quelle app: la scartano e tengono l'ultima buona. Se
l'ultima buona è rotta, chi non aggiorna resta senza sito. Allora:

1. si implementa la primitiva nel pacchetto (specifica prima in `docs/siti.md`,
   `catalogEngine` + 1) e la si fa uscire con una release dell'app e
   un'immagine del server;
2. si pubblica la variante nuova (`version` più alta, che usa la primitiva);
3. se esiste un modo più povero di aggirare il guasto con le primitive vecchie,
   anche peggiore (meno metadati, una fase saltata), lo si pubblica come
   variante accanto, con `version` più bassa di quella nuova ma più alta della
   rotta.

`build` prende una variante per file, quindi per pubblicarne due dello stesso
sito servono due file: la variante povera si pubblica prima, da sola (un
catalogo con `serial` N), e la ricca dopo (`serial` N+1, con `--previous` che
conserva la povera). Il cliente sceglie da sé, fra le varianti con `minEngine ≤
engine`, quella con la `version` più alta. Si controlla con `verify --engine`
per i due `engine` (vecchio e nuovo) che ognuno prenda la sua.

Il server dichiara il suo `engine` in `/v2/server`: un server non aggiornato
non riceve la variante nuova, e l'app tiene quel sito sul telefono
(`engineForSite`). Non serve fare niente, ma l'aggiornatore del server
(`kagami-updater`) va lasciato acceso.

## Ritorno indietro

Una correzione pubblicata che peggiora le cose non si ritira abbassando il
`serial`: i clienti che l'hanno vista rifiutano un `serial` più basso
(anti-rollback, `docs/catalogo.md` § «Adozione»), e resterebbero sulla versione
rotta. Si ripubblica in avanti:

- si rimette in `catalog/sites/<id>.json` il contenuto buono di prima, con una
  **`version` nuova** (la più alta + 1), e si fa il giro completo con `serial`
  + 1;
- oppure, se la definizione nuova è appena uscita e la vecchia è ancora fra le
  varianti, si toglie la nuova dal sorgente: non basta, perché `--previous` la
  riporta dentro dal vecchio indice. Serve la `version` nuova come sopra.

Se la definizione sbagliata ha messo nel catalogo serie con id diversi e
qualcuno le ha già adottate, tornare indietro non basta: è un cambio
d'identità da trattare come tale (`docs/malf.md`), e `builtin: "off"` impedisce
che l'auto-ripiego mescoli le due forme mentre si decide.

## Chiavi

Una chiave per firmare, generata una volta e messa nei segreti di Hestia:

```bash
openssl genrsa -out catalogo.pem 3072
dart run tool/catalog.dart pubkey catalogo.pem --kid kagami-2026   # voce per CATALOG_KEYS
```

La voce pubblica va in `CATALOG_KEYS` di `build.yml`, del server (build-arg) e
nei secret del repo pubblico per `catalog.yml`. Il file PEM si cancella dalla
macchina dopo averlo messo nei segreti.

**Rotazione** (programmata, senza fretta): si genera la chiave nuova, si
aggiunge la sua voce a `CATALOG_KEYS` (separate da virgola) e la si fa uscire
con una release e un'immagine; finché girano versioni con la sola chiave
vecchia, ogni pubblicazione si firma con tutte e due (`sign` una volta per
`kid`, due righe in `index.sig`); quando quelle versioni non contano più, si
firma solo con la nuova e la vecchia esce da `CATALOG_KEYS` con un'altra
release.

**Compromissione** (la chiave è uscita dai segreti): non c'è revoca a distanza,
perché una firma valida è tutto ciò che un cliente controlla. Si toglie la
chiave da `CATALOG_KEYS`, se ne mette una nuova, e si fa uscire subito una
release e un'immagine; si pubblica un catalogo firmato con la nuova e con
`serial` molto più alto di quello attuale, così un catalogo falso con un
`serial` basso viene rifiutato da chi ha adottato il vero. Fino alla release
chi ha la chiave può pubblicare per le build vecchie: è il rischio accettato in
`docs/catalogo.md`. Si guarda nel bucket e sul ramo `catalog` se è stato
pubblicato qualcosa che non viene da un commit.

## Cosa non fare

- **Scrivere `minEngine` a mano**, nell'indice o nella definizione: un numero
  troppo basso fa fallire la lettura nelle app vecchie invece di farle saltare
  la variante. `build` lo calcola, `verify` lo ricontrolla.
- **Riusare un nome di file in `sites/`**, cioè pubblicare byte diversi con la
  stessa `id` e `version`: un cliente con l'indice di prima scarica il file
  nuovo, trova uno sha256 diverso e scarta il sito. Ogni modifica ha la sua
  `version`. `build --previous` lo rifiuta (sha256 bloccato per `version`) e chiede `version` + 1.
- **Abbassare o ripetere il `serial`**: un `serial` più basso è rifiutato, uno
  uguale con byte diversi pure. `build --previous` lo impedisce; senza
  `--previous` no, quindi non si costruisce mai senza.
- Costruire dentro la cartella pubblicata, o modificare un indice dopo `sign`.
- Pubblicare un catalogo che non corrisponde a un commit di `catalog/sites/`.
- Correggere un sito `offline` o `gated` da un solo punto di vista: la
  definizione non c'entra.

## Prova a secco

Eseguita il 2026-11-15 (prima di `status.json`, degli sha bloccati e degli host nuovi; il giro è invariato) in `/tmp/kagami-p63-prova` (fuori dal repo), con una
chiave di prova generata per l'occasione e cancellata alla fine, e una copia di
`catalog/sites/mangak.json`. Comandi da `packages/kagami_archive`, con
`T='dart run tool/catalog.dart'` e `K` la voce stampata da `pubkey`.

```bash
D=/tmp/kagami-p63-prova; mkdir -p $D/siti; cp ../../catalog/sites/mangak.json $D/siti/
openssl genrsa -out $D/prova.pem 3072
$T pubkey $D/prova.pem --kid prova-1 > $D/keys.txt; K="$(cat $D/keys.txt)"
$T build $D/siti $D/v1 --serial 1 --check 'dart analyze lib'
$T sign $D/v1 --kid prova-1 --key $D/prova.pem
$T verify $D/v1 --keys "$K"
# correzione simulata: version 1 → 2, serial 1 → 2
jq '.version = 2' $D/siti/mangak.json > $D/siti/m && mv $D/siti/m $D/siti/mangak.json
$T build $D/siti $D/v2 --serial 1 --previous $D/v1/index.json     # serial non crescente
$T build $D/siti $D/v2 --serial 2 --previous $D/v1/index.json
$T sign $D/v2 --kid prova-1 --key $D/prova.pem
$T verify $D/v2 --keys "$K"
```

Esito:

| Passo | Exit | Uscita |
|---|---|---|
| `pubkey` | 0 | `prova-1.<n>.AQAB` |
| `build` serial 1 con `--check` | 0 | `Indice serial 1: 1 siti, 1 varianti.` |
| `sign` | 0 | `Firmato index.json con «prova-1» (1 righe in index.sig).` |
| `verify` | 0 | `mangak [ok]: v1 (minEngine 5)` |
| `build` serial 1 su `--previous` serial 1 | 1 | `--serial 1 deve superare quello precedente (1).` |
| `build` serial 2 | 0 | `1 siti, 2 varianti`; `sites/` con `mangak-1.json` e `mangak-2.json` |
| `sign` + `verify` | 0 | `mangak [ok]: v2 (minEngine 5)` |

Prove dei guasti, sulla stessa cartella:

| Prova | Exit | Uscita |
|---|---|---|
| `build ... --check 'false'` | 1 | `Il controllo è fallito (exit 1), niente uscita.`; la cartella non viene creata |
| un byte aggiunto a `sites/mangak-2.json`, poi `verify` | 1 | `mangak v2: sha256 diverso da quello dell'indice.` |
| `state: broken` con `jq` dopo `sign`, poi `verify` | 1 | `Firma assente o falsa.` |
| lo stesso, rifirmato, poi `verify` | 0 | `mangak [broken]: v2 (minEngine 5)` |
| byte diversi con la stessa `version` 1, `build --previous` nella cartella di prima | 1 | rifiutato: lo sha256 di una `version` pubblicata è bloccato (aggiunto dopo questa prova) |

## Cassette

Una cassetta è ciò che un sito ha risposto al motore durante un giro intero
(ricerca, serie, tavole del primo capitolo, prima immagine), salvato in modo da
poterlo riprodurre senza rete. Serve a provare una definizione sulla forma che
il sito aveva quel giorno, sempre, anche dopo che il sito è cambiato di nuovo:
è il test di regressione dei siti, e il triage del passo 2. **Si tengono**: una
cassetta vecchia non si cancella perché «il sito è cambiato», si cancella solo
con un commit che dice perché quella forma non torna più.

### Cartella

```text
packages/kagami_archive/test/fixtures/sites/<id>/<data>-<etichetta>/
  cassette.json
  expect.json
  <hash>.html
  <hash>.json
  …
```

`<id>` è l'id del sito, `<data>` il giorno della registrazione (`2026-11-16`),
`<etichetta>` dice perché esiste (`canarino`, `guasto`, `dopo-correzione`),
in `[a-z0-9-]`. `cassette.json` lega ogni indirizzo chiesto alla sua risposta:

```json
{
  "recordedAt": "2026-11-16T10:12:00Z",
  "entries": {
    "https://mangak.io/solo-leveling": {"status": 200, "contentType": "text/html; charset=utf-8", "file": "64b90014e917.html"},
    "https://api.mangak.io/titles/123/chapters": {"status": 200, "contentType": "application/json", "file": "2e32a8db606f.json"},
    "https://rx.qvzr2.org/123/1/001.webp": {"status": 200, "contentType": "image/webp"}
  }
}
```

La chiave è l'indirizzo intero, perché `ProviderHttp` chiede solo in GET e il
referer è un header. Un indirizzo chiesto due volte ha una risposta sola. Senza
`file` il corpo è vuoto: è il caso di `imageExists`, che guarda solo lo stato,
e delle risposte d'errore. Il corpo è ciò che `get` ha restituito, quindi è già
dentro i tetti del motore (la prima immagine, per esempio, è solo nei byte che
la sonda legge).

`expect.json` dice da dove parte il giro e cosa deve uscirne:

```json
{
  "query": "solo leveling",
  "seriesId": "123",
  "title": "Solo Leveling",
  "minChapters": 200,
  "firstPage": "https://rx.qvzr2.org/123/1/001.webp"
}
```

`query` (o `url`) è il canarino usato per registrarla; il resto è l'esito
atteso: id della serie, titolo, numero minimo di capitoli (minimo e non
esatto, perché una cassetta registrata dopo deve poter avere più capitoli
senza riscrivere quelle di prima), indirizzo della prima tavola.

### Pulita per costruzione

Una cassetta contiene solo ciò che `ProviderHttp` restituisce: stato, tipo e
corpo. Header, cookie e `Set-Cookie` non ci sono perché l'interfaccia non li
dà, non perché qualcuno li toglie dopo; così una cassetta si può mettere in un
repo pubblico senza rileggerla in cerca di segreti. Il motore non accede a
nessun account, quindi nemmeno i corpi ne portano.

### Riprodurre e registrare

- `ReplayHttp` risponde da una cassetta. Un indirizzo che la cassetta non
  contiene è un errore che lo nomina («richiesta non prevista: https://…»),
  distinto da `ProviderChanged` e da `ProviderOffline`: vuol dire che la
  definizione chiede una cosa diversa da quella registrata, e il test deve
  dirlo, non passare per un sito cambiato. Uno stato da 400 in su diventa
  `HttpStatusError`, come dal vivo.
- `RecordingHttp` avvolge il `ProviderHttp` vero e annota ogni risposta,
  errori di stato compresi; la cassetta si scrive alla fine del giro.

`catalog_cassette_test` prova ogni definizione di `catalog/sites/` su ogni
cassetta del suo sito che ha un `expect.json`. Le cassette vecchie restano: una
correzione deve leggere anche la forma di prima, perché il sito a volte serve
le due forme a server diversi e perché le alternative di `first` esistono per
questo. Togliere una cassetta è una scelta, in un commit che dice perché quella
forma non torna più.

### Come nasce

Due strade, per due scopi diversi.

**Per scoprire**, da un HAR:

```bash
dart run tool/site.dart har <cartella HAR> --hosts mangak.io,api.mangak.io --out /tmp/mangak-har
```

L'HAR viene da qualunque strumento (passo 3); i corpi possono
stare dentro l'HAR o in file accanto. Lo strumento tiene solo gli host dati,
scrive una cassetta ripulita e un inventario delle richieste. Quella cassetta
serve a capire dove stanno i dati, non entra nei test: il browser ha un altro
User-Agent e fa richieste diverse da quelle del motore. **L'HAR non entra mai
nel repo**, né la sua cartella: contiene cookie e token. Per questo `--out`
punta fuori dal repo.

**Per i test**, dal motore:

```bash
dart run tool/site.dart check ../../catalog/sites/mangak.json --live \
  --record test/fixtures/sites/mangak/2026-11-16-canarino
```

`check --live` fa il giro dal vivo con la definizione e l'User-Agent del
motore, attraverso `RecordingHttp`, e scrive la cassetta ed `expect.json`
dall'esito. `expect.json` si rilegge a mano prima del commit: è l'esito di
quel giorno, e diventa la verità per tutte le definizioni che verranno. Anche
la sonda scrive una cassetta, quella del guasto, con `probe --capture`
(`docs/server.md` § «La sentinella dei siti»).

## Buchi noti

Nessuno è corretto qui.

- **Pubblicazione** (P8.1, `~/repos/hestia/richieste/`): il bucket pubblico di
  Hestia, lo scambio atomico di `index.sig` e `index.json` e il segreto con la
  chiave di firma non hanno ancora un comando; i passi 6 e 8 descrivono il
  risultato voluto, non uno script.
- **Sentinella pianificata** (P8.2, Iris): niente esecuzione periodica da due
  punti di vista, niente avvisi su Telegram, niente sessione dell'agente
  all'allarme. Oggi la sonda si lancia a mano.
- **Ripiego e identità**: se la definizione prende l'id della serie dalla
  pagina (`series.id`) e non dal link, l'id non si conosce prima di leggerla e
  il ripiego non può verificare che l'incluso dia lo stesso: a tenere separate
  le due forme resta solo `builtin: "off"`, deciso a mano da chi ripara.
