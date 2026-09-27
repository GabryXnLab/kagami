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
  (MangaArchive) aggiunge le righe di Drive delle serie che non ha in locale.

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

## `library.json`

Una riga per serie, con quanto basta a disegnare la griglia e a filtrare:
titolo, percorso, copertina e miniatura con dimensioni, `releaseStatus`,
autori, artisti, generi, tag, conteggi (`chapterCount` è quanto il provider
pubblica, `archivedChapterCount` quanto è scaricato e completo), ultimo capitolo
archiviato, `updatedAt` del provider, `archivedAt` locale e `signature`.

La descrizione non c'è di proposito: moltiplicata per le serie peserebbe più di
tutto il resto e serve solo alla scheda di dettaglio, che legge `series.json`.

`signature` è uno SHA-256 troncato a 16 caratteri dei capitoli della serie:
uguale in `library.json` e in `index.json`. Il client rilegge una serie solo
quando la firma cambia, senza confrontare capitolo per capitolo.

## `index.json` e `pages.json`

`index.json` elenca i capitoli con `id`, `number`, `title`, `order`, `sortKey`,
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
un errore.

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
tessere solo su una parte dei capitoli.

`schemaVersion` 3 dei manifest e MALF 1 arrivano insieme. Le librerie scritte
con lo schema 2 restano leggibili: non hanno gli indici né le miniature finché
non si esegue `reindex`, e i loro record di pagina acquistano le dimensioni alla
prima riesecuzione del download, che le misura mentre verifica i file.
