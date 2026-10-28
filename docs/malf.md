# MALF — formato della libreria manga

Fonte di verità del formato con cui un archiviatore scrive una libreria manga e
con cui un client di lettura la legge. L'originale è questo documento, in
Kagami: chi cambia il formato cambia prima questo, poi chi scrive (in Kagami
`packages/kagami_archive/`) e chi legge (`lib/src/format/malf.dart`). Gli archiviatori
esterni che scrivono MALF, come MangaArchive, seguono questo documento; Kagami
non dipende da nessuno di loro.

`format: "malf"`, `formatVersion: 1`.

## Chi scrive

Nella stessa cartella di Drive possono scrivere più archiviatori: Kagami dal
telefono e dal suo server (`packages/kagami_archive/`), e archiviatori esterni che
seguono questo formato, come MangaArchive. Usano gli stessi nomi di cartella e
gli stessi manifest. Nessuno ha un lucchetto sugli altri, quindi ciascuno,
prima di riscrivere un derivato, prende dalla destinazione il lavoro degli
altri:

- una serie si allunga nella cartella in cui c'è già (per chiave in
  `library.json`, o per il suffisso `[provider-id]` del nome), anche se il
  titolo sul sito è cambiato;
- un capitolo si riconosce dal suo `chapter.json` con `complete: true`, le
  stesse tavole che il sito elenca adesso e i file della misura registrata:
  non si riscarica, chiunque l'abbia scritto. Un archiviatore che tiene
  ricevute dei caricamenti (MangaArchive) la scrive dall'elenco di Drive;
- `index.json` e `pages.json` si riscrivono partendo da tutte le cartelle di
  capitolo presenti sulla destinazione: chi tiene i manifest in locale
  (MangaArchive) copia prima i `chapter.json` che non ha, Kagami apre quelli che l'indice precedente non
  conosce;
- `library.json` si riscrive tenendo le righe degli altri: Kagami sostituisce
  solo la riga della serie che ha scritto, chi riscrive l'indice intero
  (MangaArchive) aggiunge le righe di Drive delle serie che non ha in locale;
- una serie si toglie spostando la sua cartella nel cestino di Drive e
  togliendo la sua riga da `library.json`. Chi riscrive l'indice intero non
  rimette la riga di una serie la cui cartella su Drive non c'è più, e chi
  la segue per i capitoli nuovi smette.

Scrivendo solo sul telefono, senza Drive, Kagami non tocca `library.json`
della cartella (che potrebbe essere la copia di una scritta altrove): le sue
serie vanno in `reading/downloads.json`, che il client unisce alla libreria.
Una cartella senza `library.json` è una libreria vuota, non un errore: è da lì
che parte chi archivia solo dal telefono.

## Perché esiste

L'archivio è già completo e verificabile (`series.json`, `chapter.json`, pagine
con SHA-256), ma percorrerlo costa una `open()` per capitolo: una libreria con
80 serie da 150 capitoli sono 12 000 file da aprire per disegnare una griglia di
copertine. Su telefono questo si paga in secondi e in batteria.

MALF aggiunge tre file **derivati** che rispondono alle tre domande del client
senza toccare l'archivio:

| Domanda del client | File | Costo |
| --- | --- | --- |
| Cosa c'è in libreria? | `library.json` (root) | 1 lettura |
| Cosa c'è in questa serie? | `<serie>/index.json` | 1 lettura |
| Quali pagine ha questo capitolo? | `<serie>/pages.json` | 1 lettura, solo entrando in lettura |

Derivati significa che possono essere cancellati senza perdere nulla: si
ricostruiscono dai manifest («reindex»; in MangaArchive `mangaarchive
reindex`). Kagami li riscrive solo per le serie che archivia lui.

## Struttura

```text
MangaArchive/
  library.json                    indice di libreria
  .nomedia                        tiene le tavole fuori dalla galleria Android
  reading/                        spazio del client, scritto solo da lui
    state.json                    stato utente storico, oggi di sola lettura
    collections.json              raccolte storiche, oggi di sola lettura
    backup/                       copie dei dati del client, compresse
  Dungeon Odyssey [mangak-KY55w5Y9]/
    series.json                   manifest completo (schemaVersion 3)
    index.json                    capitoli, senza pagine
    pages.json                    pagine per capitolo
    cover.webp
    cover.thumb.webp              miniatura ≤360×540, è ciò che legge la griglia
    chapters/
      0001 - Chapter 1 [WYXxOj6Y]/
        chapter.json
        0001.webp
```

## Identità

La chiave di una serie è `"<provider>:<id>"` (`mangak:KY55w5Y9`), non il nome
della cartella: il titolo può cambiare o essere troncato e lo stato di lettura
deve sopravvivere. Un capitolo è identificato dal suo `id` di provider, e
`order` (posizione nell'elenco del provider) è l'ordine di lettura autorevole —
`number` è testo libero e `sortKey` è `null` per gli speciali.

`number` è il numero che l'autore dà al capitolo, letto dal suo nome
(«Chapter 70.5» → `70.5`), mai il contatore del sito: su MangaK il `number`
dell'API è il posto nell'elenco, e dopo un capitolo intermedio la serie
avrebbe due numerazioni. Un nome senza numero fa da numero a sé («Side Story
1»). Entra nel nome della cartella del capitolo, quindi va calcolato allo
stesso modo da tutti quelli che scrivono (`chapterNumber` in Kagami,
`chapter_number` in MangaArchive).

Il provider `manual` non è un sito: è quello delle schede manuali (vedi
[Schede](#schede)), con chiave `manual:<id>`.

### Cambi d'identità e riparazione

Un sito può rifarsi e smettere di dare gli id di prima (Coffee Manga, 2026:
la serie `7743` è diventata `the-house-without-time`, i capitoli `217607` …
sono diventati `chapter-1` …). La serie archiviata resta la stessa: stesso
`source`, stessi capitoli, stesse tavole. Chi archivia la **adotta** — prende
la chiave nuova e tiene memoria di quella vecchia — invece di farne una
seconda accanto alla prima, così chi legge sposta i dati personali invece di
perderli.

**Campi.** Tutti facoltativi; un client che non li conosce li ignora e vede
una serie nuova.

- `formerKeys` — in `series.json`, `index.json` e nella riga di
  `library.json`: le chiavi che la serie ha avuto, dalla più vecchia, senza
  doppioni e mai la chiave attuale. Una catena A → B → C dà `["A", "B"]` in C.
  Sta anche nella riga perché è lì che il lettore guarda a ogni giro: trova
  l'adozione senza aprire l'indice di ogni serie.
- `formerIds` — nella voce del capitolo in `series.json` e in `index.json`: gli
  id che il capitolo ha avuto, con le stesse regole. Non in `chapter.json`,
  che porta solo l'id attuale: è la ricevuta del capitolo, e chi la confronta
  (la ripresa di un download) deve trovarci l'id che il sito dà adesso.
- `listed: false` — nella voce del capitolo in `series.json` e in
  `index.json`: un capitolo archiviato che il sito non elenca più. Resta
  nell'elenco, subito dopo il capitolo che lo precedeva, con il suo id, e conta
  in `chapterCount` come gli altri: è un capitolo della serie che si può
  leggere. Un capitolo non archiviato che il sito non elenca più esce
  dall'elenco, perché non c'è niente da perdere.

**Chi legge.** Trovando una serie con `formerKeys`, porta i dati personali di
ogni chiave vecchia sulla nuova, una volta sola: dopo lo spostamento la chiave
vecchia non ha più dati, quindi rileggere la stessa riga non sposta niente.
Se anche la chiave nuova ha dati (la serie è stata aperta prima della
riparazione) si fondono come in un ripristino: vince il record con
`updatedAt` più recente e i capitoli letti si uniscono. I capitoli con
`formerIds` traducono letti, posizioni e segnalibri dall'id vecchio al nuovo.
Una riga di `library.json` con una chiave che compare nei `formerKeys` di
un'altra è un avanzo di un archiviatore che non conosce questi campi: si
ignora.

**Chi scrive.** Adozione, non sovrascrittura.

- Si adotta solo rileggendo la serie dal suo `source` archiviato e ottenendo
  dal provider un id diverso: è la stessa pagina, quindi la stessa serie. Un
  provider che legge un altro sito non adotta niente: quello è il cambio di
  sito, che fa il client.
- I capitoli si abbinano prima per link (lo stesso sito tiene spesso i link
  anche quando cambia gli id), poi per numero e, senza numero, per titolo
  (`matchChapters`). Ogni capitolo del sito prende al più un capitolo vecchio,
  il primo.
- Una lettura fallita — rete, sito rotto o cambiato, verifica del browser,
  Drive che non risponde, un `series.json` che non si legge — non è «la serie
  non esiste più»: la riparazione di quella serie si ferma prima di scrivere e
  le altre vanno avanti.
- Non si cancellano capitoli né cartelle perché il sito non li elenca più:
  restano con `listed: false`. Chi riscrive `series.json` più tardi (un
  download) tiene le voci con `listed: false` che il sito continua a non
  elencare, e i `formerKeys` e `formerIds` che trova.
- Le cartelle si rinominano, non si copiano: la cartella della serie prende il
  suffisso `[provider-id]` nuovo (`seriesFolderName`), quelle dei capitoli il
  nome di `chapterFolderName`, e il `chapter.json` di ogni capitolo l'id, il
  numero, il titolo e il link nuovi; le tavole non si toccano e non si
  riscaricano. Se il nome nuovo è già preso da un'altra cartella la serie non
  si tocca: due cartelle con lo stesso nome su Drive spezzano la libreria.
  Un cambio del solo titolo non rinomina la cartella della serie (vedi «Chi
  scrive»), ma quella di un capitolo sì: un download la cercherebbe col nome
  nuovo e ne farebbe una seconda.
- L'ordine delle scritture fa riprendere una riparazione interrotta: prima la
  cartella della serie, poi i capitoli, poi `series.json`, infine indici e riga.
  Una cartella che ha già il nome nuovo è una rinomina fatta; una serie che non
  si trova più al percorso della riga si cerca per il suffisso nuovo.
- La riga nuova di `library.json` prende il posto delle righe con le chiavi
  di `formerKeys`.
- Una riparazione che non trova niente da cambiare non scrive niente: né
  `series.json` (`fetchedAt` resta quello di prima), né gli indici, né la riga.

Una riparazione fa anche il resto del lavoro di manutenzione di una serie:
riscrive titolo, metadati, `releaseStatus`, copertina (riscaricata se cambia
la sorgente o il file manca), elenco, ordine, conteggi e firma, e indica i
capitoli archiviati a metà perché tornino in coda.

## `library.json`

Una riga per serie, con quanto basta a disegnare la griglia e a filtrare:
titolo, percorso, copertina e miniatura con dimensioni, `releaseStatus`,
autori, artisti, generi, tag, conteggi (`chapterCount` è quanto il provider
pubblica, `archivedChapterCount` quanto è scaricato e completo), ultimo capitolo
archiviato, `updatedAt` del provider, `archivedAt` locale e `signature`.

`source` è il link della pagina della serie sul sito, lo stesso di
`series.json` e di `index.json`: è da lì che un archiviatore la rilegge per i
capitoli nuovi, e che un client la apre nel browser. Può essere `null` solo
per una scheda manuale senza link; un client che non lo conosce lo ignora.

La descrizione non c'è di proposito: moltiplicata per le serie peserebbe più di
tutto il resto e serve solo alla scheda di dettaglio, che legge `series.json`.

`signature` è uno SHA-256 troncato a 16 caratteri dei capitoli della serie:
uguale in `library.json` e in `index.json`. Il client rilegge una serie solo
quando la firma cambia, senza confrontare capitolo per capitolo.

## `index.json` e `pages.json`

`index.json` porta in testa chiave, provider, titolo, `source`, `releaseStatus`,
copertina, conteggi e firma, ed elenca i capitoli con `id`, `number`, `title`, `order`, `sortKey`,
`path` relativo, `archived`, `complete`, `pageCount`, `bytes` e le date. Non
contiene le pagine: la lista capitoli si apre a ogni visita, le pagine no.

`pages.json` mappa `id` capitolo → pagine, ognuna con `file`, `width`, `height`
e `bytes`. Larghezza e altezza sono misurate dagli header dell'immagine (non
dichiarate dal provider, che spesso le omette) e permettono di impaginare un
capitolo e riservare lo spazio di scorrimento senza decodificare un pixel.

### Tessere delle tavole alte

Una pagina più alta di 1536 pixel ha anche `tiles`: la stessa tavola tagliata
dall'alto in basso in parti uguali alte al più 1024 pixel, ognuna un file WebP
con `file`, `height` e `bytes`. Le tessere hanno la larghezza della pagina e,
messe una sotto l'altra, la ricompongono esattamente: la somma delle `height` è
l'`height` della pagina. Stanno nella cartella del capitolo accanto alla
tavola, con il suo nome e un numero (`0003.webp` → `0003-01.webp`,
`0003-02.webp`, …).

```json
{"file": "0003.webp", "width": 720, "height": 3000, "bytes": 185000,
 "tiles": [{"file": "0003-01.webp", "height": 1000, "bytes": 61000},
           {"file": "0003-02.webp", "height": 1000, "bytes": 64000},
           {"file": "0003-03.webp", "height": 1000, "bytes": 60000}]}
```

Esistono per il client di lettura. Le tavole dei manhwa arrivano a 16383
pixel, il massimo che WebP sa scrivere: intera, una tavola così è una bitmap da
cinquanta megabyte e una texture più grande di quanto la GPU di un telefono
accetti, e ritagliarla sul telefono a ogni schermata è lavoro che si vede nello
scorrimento. Una tessera invece è un'immagine come un'altra, che il client
decodifica intera e fuori dal thread dell'interfaccia. È ciò che fanno i
lettori per Android con «split tall images», spostato a monte: lo si fa una
volta, archiviando, invece che a ogni lettura su ogni telefono.

Sono **derivate**, come la miniatura della copertina: la tavola originale resta
com'è ed è lei il dato archiviato e verificato con SHA-256. Le tessere sono una
ricodifica lossy ad alta qualità (WebP q92): senza perdita peserebbero tre o
quattro volte la tavola, e chi legge da Drive le scarica. Un client che non
trova una tessera — sincronizzazione a metà, capitolo archiviato prima che
esistessero — legge la tavola, e un client che non conosce `tiles` legge
`file` come ha sempre fatto.

I record di pagina in `chapter.json` portano le stesse tessere con `size` e
`sha256`, quindi `pages.json` resta ricostruibile da `reindex`. Le tessere dei
capitoli archiviati prima le aggiunge l'archiviatore (in MangaArchive,
`mangaarchive tiles`).

`complete: false` o `archived: false` sono normali: una serie ongoing ha
capitoli noti ma non ancora scaricati, chi archivia può aver chiesto di partire
da un capitolo preciso (i precedenti restano qui, senza `path` e con
`pageCount: 0`) e la sincronizzazione del telefono può essere a metà. Il client
mostra ciò che ha, segnala gli altri come non scaricati e non considera l'indice
un errore. Una serie può anche non avere **nessun** capitolo archiviato: è una
scheda (sotto).

## `.nomedia`

File vuoto nella radice, scritto insieme a `library.json` (quindi presente dopo
ogni download e ricreato da `reindex`). Senza di lui lo scanner multimediale di
Android indicizza ogni cartella di capitolo come un album e la galleria del
telefono si riempie di centinaia di raccolte di tavole.

Vale per tutto il sottoalbero, `reading/` compreso, e appartiene all'archivio e
non al client: nasce a monte, viaggia con la cartella sincronizzata e sopravvive
a una reinstallazione o a una sincronizzazione che rispecchia il remoto — che
invece cancellerebbe un file creato solo sul telefono. Un client non deve
crearlo né cancellarlo; se manca, la libreria è stata scritta da una versione
precedente e basta `reindex`. Quando è Kagami ad archiviare, fa la parte
dell'archivio: lo crea se manca, accanto a `library.json` su Drive o nella
cartella scelta sul telefono.

## Serie in corso

`metadata.releaseStatus` in `series.json` e `releaseStatus` negli indici valgono
`ongoing`, `completed`, `hiatus`, `cancelled` o `unknown`, normalizzati da
chi archivia (`releaseStatus()` in `packages/kagami_archive/lib/model.dart`). Il testo originale del sito resta in `metadata.status`
e in `metadata.source`: la normalizzazione è per l'interfaccia, non sostituisce
il dato archiviato.

Su una serie `ongoing` il confronto fra `chapterCount` e `archivedChapterCount`
dice quanti capitoli esistono ma non sono ancora stati scaricati.

## Schede

Una scheda è una serie salvata in libreria senza scaricarne i capitoli:
`series.json` completo, copertina e miniatura, `index.json` con tutti i
capitoli del sito e nessuno archiviato (`archivedChapterCount: 0`,
`pages.json` con `pages` vuoto) e la sua riga di libreria, con `source`. È uno
stato normale, non una serie rotta: i capitoli si possono archiviare dopo,
nella stessa cartella, e da quel momento è una serie come le altre. Kagami
aggiorna la scheda riscrivendo `series.json`, gli indici e la sua riga, mai
togliendo capitoli già archiviati; seguendo una scheda di una serie in corso
elenca i capitoli nuovi nell'indice senza scaricarli. Chi controlla tutta la
libreria per i capitoli nuovi riconosce una scheda perché nessun capitolo
dell'indice è `archived`, e ne aggiorna l'indice invece di scaricarli.

### Schede manuali

Una serie di un sito che nessun archiviatore sa leggere, o senza link, è una
scheda **manuale**: `provider` è `manual`, `id` sono i primi 12 esadecimali
dello SHA-256 del link normalizzato (schema e host minuscoli, senza frammento
e senza `/` finale) o, senza link, 12 esadecimali a caso; la cartella è
`<titolo> [manual-<id>]`. `series.json` ha `chapters` vuoto, `source` è il link
così come l'utente l'ha dato o `null`, `metadata` ha la forma consueta e la
copertina è facoltativa. Gli indici e la riga si scrivono come per ogni
altra serie, con zero capitoli, e con le stesse regole di «Chi scrive».

`manual` non è un sito da cui scaricare: un archiviatore non rilegge mai una
serie `manual`, né per i capitoli nuovi né per completarla, anche se il suo
`source` è di un sito che conosce. Un client o un archiviatore che non conosce
`manual` la tratta come una serie qualsiasi senza capitoli.

## `reading/` — spazio del client

Cartella riservata al client; nessun archiviatore la legge o la tocca. Il
formato dice che è sua e non cosa ci mette: quali file ci siano è una scelta del
client, e a oggi Kagami la usa per le copie di backup dei propri dati.

`state.json` e `collections.json` sono il suo passato, e restano descritti qui
perché le librerie esistenti li contengono ancora e un client li deve saper
**leggere**. `state.json` indicizza per chiave di serie: `status` (`reading`,
`planned`, `completed`, `paused`, `dropped`), `rating` 0–10 o `null`,
`favorite`, `readChapters` (id dei capitoli finiti), `progress` (`chapterId`,
`page`, `pageCount`, `updatedAt`), `notes`, `updatedAt`. `collections.json`
contiene le raccolte: `id`, `name`, `color`, `order` e le chiavi di serie.

Kagami non li scrive più. Lo stato utente ha smesso di stare in un JSON quando
gli è servita una cronologia: un capitolo letto con la sua data è una riga per
capitolo, e ogni statistica per periodo un raggruppamento per data — cioè
esattamente il lavoro per cui esistono gli indici, applicato ai dati
dell'utente. Quei file vengono importati una volta sola e poi lasciati dov'erano
(il client non cancella niente dalla libreria).

La conseguenza va detta: la libreria non porta più con sé lo stato di lettura, e
due dispositivi non si sincronizzano più da soli. Al loro posto c'è il backup
del client, che in `reading/backup/` scrive un archivio compresso dei propri
dati; è la stessa cartella sincronizzata, quindi viaggia con i manga, ma il
ripristino è un gesto esplicito. La vecchia regola di fusione resta valida ed è
quella che il ripristino applica: vince il record con `updatedAt` più recente,
tranne `readChapters`, che è l'unione dei due — un capitolo letto non torna mai
non letto.

## Compatibilità

`tiles` è un campo in più e facoltativo, quindi non cambia `formatVersion`:
una libreria senza tessere è una libreria MALF 1 valida, come una con le
tessere solo su una parte dei capitoli. Lo stesso vale per le schede e per il
provider `manual`: sono serie MALF 1 con zero capitoli archiviati, o zero
capitoli, che un lettore vecchio mostra come tali.

`formerKeys`, `formerIds` e `listed` (vedi [Cambi d'identità e
riparazione](#cambi-didentità-e-riparazione)) sono campi in più dello stesso
tipo: un lettore vecchio vede la serie adottata come una serie nuova, con i
dati personali rimasti sulla chiave di prima, e un capitolo con `listed: false`
come un capitolo qualunque.

`schemaVersion` 3 dei manifest e MALF 1 arrivano insieme. Le librerie scritte
con lo schema 2 restano leggibili: non hanno gli indici né le miniature finché
non si esegue `reindex`, e i loro record di pagina acquistano le dimensioni alla
prima riesecuzione del download, che le misura mentre verifica i file.
