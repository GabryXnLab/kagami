# Kagami — design

Cosa deve fare l'app, come deve comportarsi e perché le scelte tecniche sono
quelle che sono. È il documento da aggiornare quando una decisione cambia; il
formato dei dati sta invece in [malf.md](malf.md).

## Il problema

I lettori manga esistenti presuppongono di essere loro a scaricare i capitoli.
Qui i capitoli arrivano già pronti: l'estensione MangaArchive li scarica sul
server, Google Drive li porta fuori e FolderSync li deposita in una cartella del
telefono. Quello che manca è la parte che quei lettori danno per scontata —
sapere a che punto si è, cosa si sta seguendo, cosa è arrivato di nuovo.

L'app è quindi la metà "lettore" di un lettore musicale: la libreria è già lì,
il valore è in come la si percorre e in cosa ricorda.

Da quando legge e scrive Drive, l'app può anche fare la parte del server:
**Impostazioni → Scarica un manga** porta una serie dal sito alla libreria con lo
stesso motore di MangaArchive, portato in Dart, senza server in mezzo. Il
server resta dov'è, e i due scrivono nella stessa cartella (vedi «Scaricare
dai siti»).

Tre vincoli danno forma a tutto il resto:

1. **La libreria è grande e su memoria lenta.** Decine di migliaia di immagini
   su storage condiviso Android. Ogni file aperto inutilmente si paga in attesa
   e in batteria.
2. **La libreria cambia sotto i piedi.** La sincronizzazione arriva quando vuole
   e può essere a metà. L'app non può assumere che ciò che l'indice descrive sia
   già sul disco.
3. **Le serie sono quasi tutte in corso.** Un capitolo a settimana per serie. La
   domanda più frequente dell'utente non è "cosa ho?" ma "cosa è arrivato?".

## Funzionalità

### Libreria

Griglia di copertine — comoda, fitta, a elenco o a elenco dettagliato —
ordinabile per aggiornamento recente, titolo, avanzamento, data di aggiunta,
voto, capitoli da leggere, ultima lettura, numero di capitoli o a caso. Ogni
cella mostra copertina, titolo, capitoli disponibili e due segnali che devono
essere leggibili senza aprire nulla:

- **novità**: un pallino in alto a sinistra con il numero dei capitoli
  arrivati dopo l'ultima apertura della scheda e non ancora letti, solo sulle
  serie seguite;
- **in corso**: la serie riceve ancora capitoli — e, se il provider ne annuncia
  più di quanti ce ne siano in locale, quanti ne mancano.

Filtri per stato utente, stato di pubblicazione, genere, tag, autore, voto
minimo, presenza di capitoli non letti e di capitoli nuovi. Generi, tag e autori hanno **tre
stati** — indifferente, richiesto, escluso — perché "shonen ma non horror" è
una richiesta normale e con due stati si può solo elencare tutto il resto.

Ricerca per titolo e autore, con prefissi (`tag:`, `genere:`, `autore:`,
`stato:`, `tipo:`, `provider:`) per le domande che non vale la pena andare a
chiedere ai filtri.

Selezione multipla: le azioni della scheda — letti, da leggere, stato,
preferiti, raccolte — applicate a venti serie insieme.

### Capitoli nuovi e notifiche

MangaArchive controlla ogni giorno le serie in corso e scarica i capitoli
usciti; la catena li porta su Drive e sul telefono. L'app se ne accorge
rileggendo gli indici — all'avvio, tornando in primo piano se `library.json`
è cambiato, tirando giù la griglia — e per ogni serie **seguita** (stato,
voto, preferito o capitoli letti, e non abbandonata) con capitoli nuovi
mostra una notifica: una per serie, aggiornata se ne arrivano altri, tolta
aprendo la scheda. Toccarla apre la scheda.

Ogni serie si può silenziare dalla campanella sulla copertina della scheda:
tacciono le notifiche, il pallino resta. Il silenzio è una preferenza e
viaggia con backup e account.

Il numero viene da un conteggio di riferimento per serie (`SeriesArrivals`):
MALF dice quando è arrivato l'ultimo capitolo, non quanti ne sono arrivati da
una certa data, e leggere `index.json` di ogni serie per contarli è la
scansione che gli indici esistono per evitare. Il riferimento è di questo
telefono e non va nel backup — un telefono nuovo parte da ciò che trova,
invece di annunciare gli arrivi di un altro — mentre l'apertura della scheda
altrove, che viaggia con `lastOpenedAt`, basta a dire che quegli arrivi sono
già stati visti. Le regole:

- una serie vista per la prima volta prende come riferimento ciò che ha:
  installare o aggiornare l'app non annuncia tutta la libreria;
- ogni arrivo si annuncia una volta; per le serie silenziate o non seguite il
  riferimento avanza lo stesso, così cominciare a seguirne una non fa suonare
  gli arrivi vecchi;
- i conteggi non scendono mai, e si guarda solo una libreria letta per intero:
  con Drive scollegato, o prima che la sua cartella sia nota, la libreria ha
  meno capitoli di quella vera, e rileggendola intera quelli di Drive
  sembrerebbero arrivati adesso.

Il permesso di notificare (Android 13 in su) si chiede la prima volta che c'è
qualcosa da annunciare.

**Ad app chiusa** si guarda solo la cartella del telefono.
`LibraryWatchWorker.kt`, un lavoro di WorkManager, ogni ora rilegge
`library.json` della cartella scelta — un file, non una scansione — e fa gli
stessi conti. Lo stato utente non lo conosce: uscendo dall'app Dart gli lascia
in `arrivals/watch.json` le serie seguite e non silenziate, con riferimenti,
capitoli letti e ultima apertura, e lui scrive in `arrivals/record.json` ciò
che ha annunciato, che Dart rilegge prima di confrontare. Un file per verso,
così nessuno dei due scrive sopra l'altro. Drive ad app chiusa resta fuori:
servirebbe il token dell'account senza l'app, e i capitoli di Drive li
annuncia l'app alla prossima apertura.

### Raccolte

L'equivalente delle playlist: una serie può stare in più raccolte, l'ordine è
scelto dall'utente, ogni raccolta ha un nome e un colore. Sono il modo per dare
struttura a una libreria che cresce da sola.

Accanto a quelle create a mano, raccolte automatiche non modificabili: *In
lettura*, *Novità*, *Preferiti*, *Da iniziare*, *Finiti*.

### Scheda della serie

Copertina grande, descrizione, autori, artisti, generi, tag, stato di
pubblicazione, conteggi. Elenco dei capitoli con letto/non letto, avanzamento
parziale e capitoli annunciati ma non ancora scaricati, distinti visivamente:
non sono un difetto, sono la normalità di una serie in corso.

Da qui: voto (0–10), stato (*da leggere*, *in lettura*, *in pausa*, *finito*,
*abbandonato*), preferito, raccolte, segna tutti come letti, note, e togli
dal telefono i capitoli già letti.

I capitoli si cercano, si filtrano (solo da leggere, solo scaricati) e si
selezionano in blocco. Generi e tag sono toccabili e aprono la libreria già
filtrata; sotto all'elenco stanno le serie che condividono generi e tag.
Compaiono anche quanto resta da leggere, stimato a tre tavole al minuto, e
quando ci si aspetta il prossimo capitolo, dedotto dalla cadenza degli ultimi
dieci: su una serie settimanale è ciò che dice se vale la pena riaprire l'app
domani.

### Lettura

Due modalità, scelte per serie e ricordate:

- **continua** (webtoon): tutte le tavole del capitolo una sotto l'altra,
  attaccate — nessun margine, nessun separatore, nessun riquadro: un capitolo
  è una striscia sola che si scorre dall'inizio alla fine, che è come sono
  fatti i manhwa da MangaK, ManhwaRead e Asura Scans;
- **paginata**: una tavola per volta, con direzione destra→sinistra o
  sinistra→destra.

Requisiti del lettore:

- ripresa esatta: si riapre dove si era smesso, tavola e punto dentro la
  tavola;
- passaggio al capitolo successivo senza tornare all'elenco, con precarico del
  primo capitolo seguente;
- zoom e doppio tocco, luminosità e modalità notturna, barra di avanzamento con
  salto rapido;
- adattamento della tavola (larghezza, altezza, originale) in paginata, colore
  di sfondo, due tavole affiancate quando lo schermo è sdraiato, numero di
  pagina, blocco della rotazione, scorrimento automatico per i webtoon,
  segnalibri di pagina;
- l'elenco dei capitoli **dentro** la lettura, con la sua ricerca: tornare alla
  scheda per cambiare capitolo significa perdere il posto;
- una pastiglia in basso con capitolo precedente e successivo, la barra di
  avanzamento del capitolo e il ritorno in cima; tutto il resto in un foglio
  solo, perché una fila di venti icone sopra una tavola è una fila di venti
  icone da leggere ogni volta;
- schermo che non si spegne mentre si legge;
- un capitolo si segna letto al 90%: l'ultima tavola è spesso una nota
  dell'autore che nessuno scorre;
- finito un capitolo con dei precedenti ancora da leggere, il lettore chiede
  se segnarli letti — una volta per lettura, perché chi ha detto di no al 21
  non vuole sentirselo richiedere al 22. Sono letture dedotte, non di oggi:
  cronologia e statistiche non le contano;
- immagini decodificate a schermo pieno solo per le pagine visibili e quelle
  immediatamente adiacenti.

### Stato di lettura e cronologia

Per ogni serie: stato, voto, preferito, capitoli letti **con la data in cui lo
sono diventati**, la posizione in ogni capitolo aperto, ultima apertura, note. In più il tempo
passato a leggere, registrato per sessioni, e i segnalibri di pagina.

Da questi dati si ricava la home — *riprendi*, *aggiornamenti*, *da iniziare*,
*arrivate di recente*, *lasciate a metà*, *altre così* — e la cronologia, che è
il rovescio della scheda: lì si guarda una serie e si cerca il capitolo, qui si
guarda il tempo e si ritrova la serie. Esiste anche una lettura in incognito,
che non registra nulla.

### Statistiche

Capitoli, tempo, tavole, giorni di fila, voto medio; capitoli per giorno o
settimana su trenta giorni, tre mesi o un anno; il calendario dell'attività;
torte per stato e per generi letti; l'istogramma dei voti; le serie più lette;
com'è fatta la libreria. Le serie storiche vengono dalla cronologia, quindi
partono da quando l'app la registra; la composizione della libreria viene dagli
indici e vale anche il primo giorno.

### Backup

Esportazione in un file compresso, con ripristino che dice cosa contiene prima
di toccare niente e lascia scegliere fra fondere e sostituire. Accanto, una
copia automatica al giorno dentro la libreria.

### Account

Accesso con Google, facoltativo. Serve a due cose: far seguire i dati
personali al lettore invece che al telefono — stato, voti, capitoli letti,
cronologia, raccolte, segnalibri e impostazioni — e, se lo si vuole, leggere
la libreria direttamente da Google Drive.

### Google Drive

La cartella che FolderSync porta sul telefono sta prima su Drive, e per
leggerla non serve portarla tutta sul telefono. Con l'account si sceglie la
cartella di Drive che contiene `library.json` — la propria o una condivisa —
e la libreria diventa **ibrida**: quello che è sul telefono si legge dal
telefono, il resto da Drive.

- **Una serie sola**, non due: le sorgenti si uniscono per chiave di serie e
  i capitoli per id. Una serie locale con capitoli in più su Drive li mostra
  nella sua scheda, marcati come Drive, e li legge da lì.
- **La stessa esperienza.** Griglia, scheda, lettore, ripresa, precarico:
  identici. L'unica differenza visibile è un'icona — sul telefono, su Drive,
  o entrambi — che compare solo quando Drive c'è; senza, la griglia è quella
  di sempre.
- **Scarica.** Un capitolo, una selezione o tutta la serie scendono sul
  telefono con un tocco. Vanno nella cartella della libreria se c'è; se non
  c'è, l'app chiede una volta se sceglierne una, e chi preferisce di no li ha
  nello spazio dell'app, che però se ne va disinstallandola.
- **Senza rete** la libreria di Drive si apre com'era l'ultima volta, e i
  capitoli ancora in cache si leggono lo stesso: di sicuro il seguito di
  quelli lasciati a metà.
- **La cache non cresce da sola.** Ha un tetto — un gigabyte, regolabile —
  e sa cosa si è letto: il lettore annota di quali tavole è fatto ogni
  capitolo aperto (`drive.chapters.json`, accanto alla cache). Un capitolo
  finito se ne va tre giorni dopo l'ultima apertura, e con lui le tavole già
  passate di quello a metà; un capitolo aperto e lasciato, dopo due
  settimane. Quello che resta sempre è ciò che serve a riprendere: le tavole
  di un capitolo a metà da dove si è arrivati in poi — la posizione vera sta
  nel database — e le miniature della griglia. Quando il tetto si raggiunge
  escono nello stesso ordine: prima il letto, poi il resto, per ultimo ciò
  che serve a riprendere. Gli elenchi delle cartelle di Drive non più
  rifatti da un mese si buttano; i testi degli indici tengono solo la
  versione in uso.

## Interfaccia

Navigazione a quattro destinazioni: **Home** (ripresa, aggiornamenti,
suggerimenti), **Libreria**, **Raccolte**, **Impostazioni** (profilo, scaricare,
cronologia, statistiche, incognito e le impostazioni vere, ognuna nella sua
pagina). La ricerca è sopra la libreria, non una destinazione a sé.

La barra di navigazione è **sospesa** sopra il contenuto, una pastiglia che
galleggia invece di una fascia opaca che taglia l'ultima riga della griglia;
l'etichetta ce l'ha solo la destinazione scelta, perché quattro etichette
insieme costringono a rimpicciolire tutto.

Direzione visiva: scuro come impostazione predefinita, perché si legge di sera e
una cornice chiara attorno a una tavola in bianco e nero abbaglia. Superfici
neutre separate per tono e non per linea, un solo accento; il colore
nell'interfaccia lo portano le copertine, non il tema. L'eccezione sono le
etichette — generi, tag, autori, tipo, lingua —, colorate ciascuna dal proprio
testo (`TagTint` in `ui/theme.dart`): la stessa parola ha lo stesso colore in
ogni scheda e nei filtri, ed è così che si riconosce senza leggerla. Tinta
dall'impronta del testo, saturazione e luminosità fisse per tema, perché
nessuna etichetta gridi più delle altre. Un carattere solo
(Figtree), titoli con spaziatura negativa, numeri a larghezza fissa dove
cambiano sotto gli occhi. Angoli larghi, nessuna onda d'inchiostro: il riscontro
al tocco lo dà la scala del componente, che risponde subito e non lascia una
scia sopra una copertina. Animazioni brevi e legate al gesto: transizione
condivisa dalla copertina alla scheda, dalla scheda alla lettura, e schede che
entrano una dopo l'altra invece di apparire tutte insieme.

I pezzi ricorrenti — scheda, etichetta di sezione, pastiglia, segmentato,
pulsante, stato vuoto, foglio, riga d'impostazione — stanno in un kit unico
(`lib/src/ui/widgets/kit.dart`). Chi scrive una schermata sceglie il contenuto,
non la forma: è quello che tiene la stessa cosa uguale a sé stessa in nove
schermate. Il vocabolario visivo è quello di **Streak**, l'app di abitudini
open source presa a riferimento; le icone sono quelle di Lucide, una famiglia
sola.

Il lettore non ha cornice: comandi nascosti, un tocco al centro li richiama, la
tavola tiene tutto lo schermo.

L'interfaccia si scrive a mano in Flutter, con questo documento come
riferimento. La skill `frontend-ui` non serve qui: delega a modelli
specializzati in front-end web — HTML, CSS, React — e quello che restituisce
andrebbe comunque tradotto in widget Material 3, che è il lavoro vero.

## Scelte tecniche

### Indici invece di scansione

Scandire l'albero significa una `stat()` per cartella e una `open()` per
capitolo. Gli indici MALF riducono la libreria a una lettura, la serie a una, il
capitolo a una. L'app non li ricostruisce: se mancano, lo dice e rimanda
all'archiviatore che ha scritto la libreria. Costruirli dal telefono sarebbe
fare proprio il lavoro che si voleva evitare.

Il campo `signature` dice se una serie è cambiata senza confrontarne i capitoli;
la data di modifica di `library.json` dice se vale la pena rileggere l'indice.

### Un database per i dati personali, non per la libreria

La libreria resta fuori dal database: gli indici MALF *sono* già la forma
indicizzata, li scrive l'estensione, e copiarli vorrebbe dire mantenere una
seconda versione da invalidare a ogni sincronizzazione.

I dati personali invece ci sono entrati, e la ragione è la cronologia. Un
capitolo letto senza data non risponde a nessuna domanda sul tempo: niente
"quanto ho letto questo mese", niente giorni di fila, niente grafici. Con la
data, una riga per capitolo, `state.json` diventerebbe un file da rileggere e
riscrivere per intero a ogni pagina voltata, e ogni statistica un ciclo su tutto
il file. È esattamente il problema per cui esistono gli indici, applicato ai
dati dell'utente.

Il prezzo è che la libreria non è più autosufficiente: `reading/` non viene più
scritto, quindi due dispositivi non si sincronizzano più da soli. Al suo posto
c'è il backup — esplicito e automatico — che è un meccanismo più lento ma
esplicito, e che in più porta via anche cronologia, sessioni, segnalibri e
impostazioni, che in `reading/` non ci sarebbero mai stati.

Il vecchio `reading/` viene importato una volta sola alla prima apertura. I
capitoli che conteneva non avevano una data: prendono quella dello stato e
restano marcati come dedotti, così le statistiche per giorno non li contano come
letture di quel momento.

### Accesso ai file su Android

La cartella sincronizzata sta fuori dallo spazio privato dell'app. Le due strade
sono il Storage Access Framework e `MANAGE_EXTERNAL_STORAGE`.

SAF è la via consigliata da Android, ma ogni file passa da una chiamata di
piattaforma: con decine di migliaia di immagini l'apertura di un capitolo
diventa percettibile. `MANAGE_EXTERNAL_STORAGE` dà accesso diretto con `dart:io`
ed è ciò che l'app usa. È un permesso che va chiesto bene: la schermata che lo
richiede deve dire che serve a leggere la cartella dei manga e che l'app non
scrive nulla fuori da `reading/`, se non i capitoli che l'utente scarica
da Drive, quelli già letti che chiede di togliere e, se l'ha accesa, ciò che
porta la sincronizzazione con Drive.

### Costo delle immagini

- la griglia legge `cover.thumb.webp`, generata all'archiviazione;
- una tavola non si decodifica intera: si decodifica **a fasce**. Una tavola di
  webtoon arriva a 16383 px di altezza — il massimo che WebP sappia scrivere —
  e intera sarebbe una bitmap da cinquanta megabyte e una texture più grande di
  quanto la GPU accetti. Tre o quattro tavole così vive nella lista sono
  esattamente l'app che sparisce mentre si scorre;
- ridurle non era una risposta: una tavola alta 9000 px chiesta dentro un
  riquadro alto 8192 non viene tagliata, viene rimpicciolita, e con l'altezza
  se ne va anche la larghezza, cioè la leggibilità. La risposta è chiedere solo
  il pezzo che si sta guardando;
- il pezzo lo dà il Kotlin
  (`android/app/src/main/kotlin/dev/local/kagami/PageDecoder.kt`, lato Dart
  `lib/src/data/page_decoder.dart`): decodifica la tavola una volta, la tiene
  in memoria nativa — fuori da Dart e dalla GPU, due tavole al massimo — e ne
  ritaglia le fasce. Ritagliare dal file con `BitmapRegionDecoder` sembrava
  più furbo, ma il decodificatore WebP non sa saltare le righe sopra il
  ritaglio: l'ultima fascia di una tavola costava quanto la tavola intera. Dal
  file si ritaglia solo una tavola troppo grande per tenerla (oltre 64 MB);
- una fascia è alta al più 512 px della sorgente, un terzo di schermata di
  webtoon: ogni fascia è una texture che la GPU carica in un colpo solo, e con
  fasce da una schermata intera il caricamento si vedeva come uno scatto a
  ogni cambio;
- il ritaglio nativo però è l'ultima fonte di una fascia, non la prima. Da
  Flutter 3.29 il thread di Dart è il thread principale di Android e non se
  ne può separare (l'engine rifiuta il flag che lo faceva), quindi tutto ciò
  che passa di lì — la copia dei pixel di ogni fascia, il raccoglitore di
  Dart che conta quei megabyte, le bitmap native da cinquanta megabyte —
  toglie tempo ai fotogrammi, anche quando nessun fotogramma risulta lento:
  è un fotogramma che non parte. Il browser, che su MangaK mostra le stesse
  tavole con un `<img>`, non ha il problema perché scorre su un thread suo;
  Mihon lo evita tagliando le tavole alte al download ("split tall images").
  Il magazzino prova quindi, nell'ordine: la **tessera dell'archivio** (MALF
  `tiles`, tagliate da MangaArchive: sono le fasce stesse, coi loro bordi),
  la **tavola intera** se è bassa (fino a 2048 px), la **tessera del
  telefono** (`lib/src/data/phone_tiles.dart`: le tavole alte senza tessere
  il Kotlin le taglia una volta in JPEG nella cache, in ordine di lettura e
  quando non ha fasce da dare — è anche la decodifica anticipata della tavola
  seguente) e solo alla fine il **ritaglio nativo**. Le prime tre sono file
  interi per il codec di Flutter, che decodifica fuori dal thread
  dell'interfaccia e senza far passare i pixel da Dart. Le righe di una fascia
  sono le stesse da qualunque fonte arrivino, quindi una fonte che manca —
  una tessera non ancora sincronizzata, una cartella di tessere buttata per
  spazio — lascia il posto alla seguente senza muovere la striscia;
- il ritaglio nativo non alloca a ogni fascia (tavole decodificate dentro
  bitmap già esistenti, fasce in una bitmap riusata) e, con l'interruttore
  «Fasce native come texture», non manda i pixel a Dart: li disegna su una
  superficie nativa che il lettore mostra con un `Texture`. È una prova,
  spenta di default e non salvata, perché va giudicata a occhio su un
  telefono vero;
- le fasce sono **gli elementi della lista**, non le tavole: è questo che fa
  dipendere la memoria del lettore dallo schermo invece che dall'altezza delle
  tavole. Quello che passa, la lista lo costruisce e lo butta;
- il magazzino delle fasce (`lib/src/ui/page_bands.dart`) le tiene finché c'è
  posto — sei schermate — e butta per prime quelle che non guarda più nessuno.
  Quelle sullo schermo non si toccano. Serve a poter tornare indietro di due
  tavole senza ridecodificare niente, che è il modo in cui si risparmia
  batteria: non decodificando due volte la stessa cosa;
- niente di tutto questo ingrandisce una tavola: una tavola larga 720 px si
  decodifica a 720 px anche su uno schermo da 1080, e a portarla a schermo ci
  pensa il disegno;
- dove il decodificatore a ritagli non c'è — la build Linux, i test — si ricade
  sul codec di Flutter, che la tavola la prende intera: lì non si taglia
  niente (le tessere dell'archivio sì, sono file) e un tetto agli otto
  megapixel evita il disastro. È la stessa rete che prende una tavola di cui
  `pages.json` non dichiara le dimensioni;
- la griglia legge `cover.thumb.webp`, generata all'archiviazione;
- lo spazio di scorrimento è riservato dalle dimensioni in `pages.json`, prima
  che le immagini esistano in memoria.

### La striscia non ha giunture

In modalità continua ogni tavola occupa **esattamente** l'altezza che le tocca
alla larghezza dello schermo: il bordo inferiore dell'una è il bordo superiore
dell'altra. Lo spazio va però riservato prima che l'immagine sia decodificata,
altrimenti la posizione salta mentre si legge, e per riservarlo servono le
dimensioni.

Vengono da tre posti, in quest'ordine: il rapporto misurato sull'immagine
appena decodificata, quello dichiarato in `pages.json`, e una proporzione
plausibile per il tempo di un fotogramma. Contano tutti e tre perché l'indice
può essere vecchio, incompleto o sbagliato, e uno spazio riservato male è
esattamente ciò che apre un buco fra due tavole. Quando una misura corregge una
fascia già superata, lo scorrimento si sposta di altrettanto: senza compenso il
capitolo scivolerebbe via da solo. Una correzione che non muoverebbe mezzo
pixel si scarta: costerebbe una ricostruzione della lista per non vedersi.

Il taglio in fasce non apre giunture perché le fasce di una tavola sommano
esattamente l'altezza della tavola, e perché ognuna disegna mezzo pixel sotto
il proprio bordo: alla larghezza dello schermo quel bordo cade a metà di un
pixel del dispositivo, e senza sovrapposizione ci si vedrebbe lo sfondo
attraverso.

La geometria sta in `lib/src/ui/reader_metrics.dart`, fuori dal lettore, perché
è l'unica parte che si possa provare senza uno schermo — ed è quella che decide
se il capitolo si legge o no.

### Dove si è arrivati

La ripresa è al punto, non alla tavola. Su un webtoon una tavola è dieci
schermate: riaprire il capitolo alla tavola voleva dire tornare indietro di un
minuto di lettura. La posizione è quindi la tavola **più quanto se n'è già
scorso**, un numero fra zero e uno che sta nel database (`progresses.offset`),
nel backup e quindi nell'account.

Ce n'è una per capitolo, non una per serie: chi lascia a metà un capitolo e ne
apre un altro ritrova il primo dove l'aveva lasciato. La serie riprende dalla
più recente; fondendo due copie, per ogni capitolo vince la più recente.

Il ritmo con cui la si registra conta quanto la precisione. Scorrendo, la
posizione cambia a ogni fotogramma:

- il numero di pagina e la barra di avanzamento sono valori osservabili, non
  stato del lettore: cambiarli non ricostruisce la striscia;
- una posizione che non si discosta dalla precedente — stessa tavola, meno di
  un ventesimo scorso — non è una notizia e non si propaga;
- la riga va su disco dopo una pausa di un secondo e mezzo, non a ogni
  movimento;
- la fotografia in memoria dei dati personali si aggiorna **una volta sola**,
  uscendo dal lettore. Pubblicarla prima voleva dire ricalcolare segnali,
  filtri e ordinamenti di tutta la libreria — che resta montata sotto il
  lettore — al ritmo dello scorrimento: era metà degli scatti.

### Quando una tavola non si vede

Il lettore distingue tre stati, e li dice. Una tavola che si sta ancora
aprendo ha il suo posto con un indicatore in alto — da una scheda SD una
tavola di quindici megabyte ci mette dei secondi, e il nero in attesa si legge
come un guasto. Una tavola il cui file non c'è dice che non è sincronizzata;
una il cui file c'è e non si apre dice che è illeggibile. Sono due problemi di
due persone diverse: il primo è della cartella sincronizzata, il secondo
dell'app.

Se manca la **prima** tavola del capitolo il lettore non apre sessanta
riquadri vuoti: dice una volta sola che le tavole non sono ancora arrivate.
Gli indici pesano qualche centinaio di kilobyte e arrivano per primi, le
immagini sono gigabyte e arrivano dopo — un capitolo annunciato e vuoto è uno
stato normale della catena, non un errore dell'app.

### L'account è il backup che va e torna da sé

Quello che l'app manda in rete è esattamente il file che esporta: gli stessi
byte compressi, in un `Blob` dentro `readers/{uid}` su Firestore, dove le
regole di sicurezza non lasciano nessuna strada verso il documento di
qualcun altro. Non è pigrizia, è la conseguenza di una cosa già vera — le
regole con cui due copie dei dati si fondono esistono, sono quelle del backup,
e sono provate: i capitoli letti si sommano (un capitolo letto non torna mai da
leggere) e sul resto vince il record con `updatedAt` più recente. Rispecchiare
campo per campo avrebbe voluto dire tenere lo schema in due posti e riscrivere
quelle regole una seconda volta, cioè una seconda occasione di perdere
qualcosa.

Sincronizzare è quindi: prendi il documento remoto, fondilo con quello locale,
rimanda su il risultato. Succede all'avvio, uscendo dall'app e quando lo si
chiede, e non a ogni pagina girata: la radio accesa per tutta una lettura è un
prezzo che si paga in batteria e che non compra niente.

L'accesso passa dal token d'identità di Google, non dal browser: il sistema
dice chi è l'utente, Firebase verifica la firma e apre la sessione. Per conto
di quale client OAuth chiedere il token lo dice `google-services.json`, che il
plugin Gradle di Google trasforma in risorse dell'APK: nel codice non resta
nessun identificativo da tenere aggiornato.

Il permesso su Drive, riaprendo l'app, si chiede per l'indirizzo che
Firebase ricorda, senza rifare l'accesso: `attemptLightweightAuthentication`
di `google_sign_in` passa da Credential Manager, che a ogni avvio mostrava il
foglio «Accesso come…» o la scelta dell'account.

### Drive: stessi indici, stesso lettore

Drive è una **sorgente** accanto alla cartella del telefono e allo spazio
privato dell'app (`data/library.dart`). Legge gli stessi indici MALF con gli
stessi modelli; cambia solo il prezzo di un file, che è una richiesta di rete.
Il lavoro sta tutto nel pagarlo una volta sola (`data/drive_library.dart`):

- **all'apertura, due richieste.** L'elenco della cartella radice, e una
  ricerca sola che trova `index.json`, `pages.json`, `series.json` e le
  copertine di tutte le serie insieme. Elencare le cartelle una per una
  sarebbe una richiesta per serie prima di poter disegnare la griglia;
- **i testi si tengono per impronta**: `library.json` non cambiato non si
  riscarica. Insieme agli elenchi, un'istantanea su disco apre la libreria:
  **sempre**, non solo senza rete. La griglia si disegna subito con le serie
  dell'ultima volta — le copertine arrivano dopo, ciascuna nel suo posto
  già vuoto — e le due richieste si fanno dietro; la griglia si rifà solo
  se `library.json` è cambiato. Sul telefono resta l'elenco, non le
  immagini;
- **Drive non ha percorsi, ha identificativi**: `Serie/chapters/0001/0001.webp`
  è una catena di cartelle da elencare. Gli elenchi si tengono su disco e si
  rifanno solo quando manca un nome — un capitolo arrivato dopo —, e le
  richieste identiche in volo si fondono;
- **le tavole diventano file prima di arrivare al decodificatore.** Una tavola
  di Drive è un indirizzo `drive:…`; `PageDecoder` lo porta in cache e da lì
  in avanti è un file come gli altri — `BitmapRegionDecoder`, fasce,
  geometria e ripresa non sanno la differenza. Aprendo un capitolo le sue
  tavole si scaricano in ordine di capitolo, dalla prima all'ultima, e una
  fascia la cui tavola non è ancora scesa la aspetta **fuori** dal
  decodificatore: con un decodificatore solo, farla aspettare lì dentro
  fermava dietro a un download anche le tavole già sul telefono, ed era lo
  scorrimento a scatti.

Un capitolo si legge dal telefono solo se la sua cartella è sul telefono: con
Drive l'indice locale non si prende più in parola — una lettura della
cartella dei capitoli per serie — perché un capitolo annunciato ma non ancora
sincronizzato deve leggersi da Drive, non dire che manca.

Lo scope chiesto è `drive.readonly`: le cartelle le scrive rclone dal server,
quindi `drive.file` non le vedrebbe. È uno scope "restricted" e va dichiarato
nella schermata di consenso del proprio progetto Firebase, insieme a quello
completo.
Quello completo si chiede solo a chi sceglie una sincronizzazione che carica
su Drive (sotto): chiederlo a tutti vorrebbe dire poter cancellare il Drive
dell'utente per mostrargli delle tavole.

### Quando la rete manca, o va a scatti

La rete è una sorgente come il disco, ma va e viene. Le regole:

- **Quello che è in cache si vede sempre.** Tavole già scese, copertine,
  indici e l'istantanea della libreria stanno sul telefono, e senza rete si
  aprono senza chiedere niente a nessuno — nemmeno un timeout d'attesa.
- **Quello che manca lo dice, sulla tavola.** Una tavola che la rete non ha
  portato mostra un avviso al posto suo — le altre intorno restano visibili —
  e se ne va da sola: tornata la rete, il magazzino delle fasce riprova quelle
  sullo schermo e al posto dell'avviso ricompare l'attesa, poi la tavola.
  Il precarico riparte, le copertine si ricaricano, e gli indici letti
  offline si rileggono.
- **Senza rete non si prova.** Lo stato della rete (`data/network.dart`)
  viene dal sistema — `NetworkWatcher.kt`, la rete che Android ha verificato
  — e da una sonda da zero byte a Google, che fa da conferma e da sola dove
  il sistema non c'è. Offline una richiesta fallisce subito, ed è ciò che fa
  comparire l'avviso invece di un cerchio che gira. Una richiesta fallita da
  connessi chiede conferma alla sonda: su una rete a scatti una tavola persa
  non fa dichiarare l'app offline, si riprova.
- **Niente byte buttati.** Una tavola interrotta riprende dal byte dove si
  era fermata (`Range`), in cache come nei download; una connessione che resta
  aperta senza portare niente si chiude dopo venti secondi di silenzio e si
  riprende da lì.
- **Il capitolo scende in ordine.** Le tavole del lettore arrivano dalla
  prima all'ultima, qualunque cosa ci sia sullo schermo: chiedere urgente la
  tavola sotto il dito riempiva il capitolo a buchi, con decine di download
  iniziati da chi scorreva veloce. Solo riprendendo a metà si parte dalla
  tavola dove si era rimasti. Quanti download corrono insieme dipende dalla
  velocità misurata: sotto i 150 kB/s uno solo, perché quattro insieme
  dividerebbero la banda in quattro. Urgenti restano le copertine.
- **La striscia è lunga quanto il capitolo fin dall'inizio.** La lista
  conosce l'altezza di ogni fascia prima di costruirla, da `pages.json`, e
  sotto le tavole non ancora arrivate c'è nero: si scorre fino in fondo
  mentre le immagini riempiono il posto che le aspetta.
- **I download aspettano.** Un capitolo che perde la rete resta in testa alla
  coda, «in attesa della rete», e riparte da solo da dove era.

### Il pulsante «Scarica»

Un capitolo scaricato finisce nello stesso albero MALF dove l'avrebbe messo
FolderSync, così la sorgente locale lo trova da sé. Scende in `<capitolo>.part`
e prende il suo nome solo quando è completo. Accanto l'app mette gli indici e
le copertine di Drive — la versione più recente di ciò che FolderSync
porterebbe comunque — ma **non riscrive `library.json`**: con FolderSync in
entrambe le direzioni salirebbe su Drive al posto di quello del server. Le
serie scaricate si ricordano in `reading/downloads.json`, lo spazio dell'app
per contratto.

### Tolleranza alla sincronizzazione parziale

Un file mancante è un riquadro con un avviso, non un errore; un capitolo
incompleto si apre per le pagine che ci sono; un indice più vecchio dei file si
rilegge alla prossima apertura. Un capitolo che l'indice dice leggibile ma la
cui cartella non c'è si legge da Drive, o si mostra come non scaricato: la
cartella dei capitoli si elenca una volta per serie. L'app non cancella niente
dalla libreria se non glielo chiede l'utente, dal foglio «Libera spazio» o
eliminando una serie.

### Eliminare una serie

Dalla selezione della libreria (tocco lungo) o dal cestino sulla copertina
della scheda, una o più serie si tolgono per intero: la cartella sparisce
dal telefono — cartella scelta e spazio dell'app — e su Drive va nel
cestino, da cui si recupera per trenta giorni, con la sua riga di
`library.json`. Smette anche tutto quello che la riporterebbe: il controllo
dei capitoli nuovi, i lavori in coda (fermando quello che gira), lo scarico
man mano e, se c'è un server collegato, il suo controllo. Come per «Libera
spazio» la sincronizzazione di Kagami annota le cartelle tolte, e mentre un
giro è in corso il foglio aspetta.

Una copia locale di `library.json` rimasta indietro elencherebbe ancora la
serie finché la sincronizzazione non porta quella nuova: l'app ricorda le
serie tolte con la firma della loro riga (`library.removed`, fra le
impostazioni e quindi nel backup) e non le mostra. Riscaricata, una serie ha
un'altra firma e torna. Lo stato di lettura resta: cronologia e statistiche
sono letture fatte.

### Liberare spazio dai capitoli letti

Aprendo la scheda di una serie con capitoli già letti ancora sul telefono —
nella cartella scelta, nello spazio dell'app, nella cache di Drive — un
foglio propone di toglierli, dicendo quanti sono e quanto occupano, con una
voce per ciascun posto e «Non chiedere più per questa serie», che sta fra le
impostazioni e quindi nel backup. La stessa proposta resta sotto la ricerca
dei capitoli, «Libera spazio», finché c'è qualcosa da togliere.

Nel foglio c'è anche Drive stesso: «Capitoli su Drive» sposta nel cestino
i capitoli letti che vi stanno ancora. È spento di partenza, perché è
l'unica voce che non si rimedia riscaricando, e da solo non fa comparire la
proposta aprendo la scheda — su Drive c'è tutto ciò che si è letto, e la si
vedrebbe per ogni serie —, ma tiene visibile «Libera spazio». `index.json`
lo scrive il server e continua a elencarli: la sorgente di Drive ricorda
cosa ha tolto e non lo serve più, e se il server li ricarica — rclone li
ricopia dall'archivio, che li ha ancora — lo si vede elencando la cartella
dei capitoli, e tornano a leggersi da lì.

La cartella scelta è compresa per scelta esplicita dell'utente, anche se è
sincronizzata con Drive. Con la sincronizzazione di Kagami il foglio decide
per sé: ciò che toglie da una parte si annota, e il giro seguente non lo
riporta — nemmeno il primo, se la sincronizzazione si accende dopo — e non
lo toglie dall'altra, anche con le cancellazioni propagate, che valgono per
ciò che si toglie fuori dall'app. Mentre un giro è in corso il foglio
aspetta: potrebbe riscrivere proprio quelle cartelle. Con FolderSync, che
l'app non vede, avvisa che in entrambe le direzioni la cancellazione può
arrivare su Drive e in sola discesa i capitoli possono tornare. Il foglio
dice anche se la serie non è su Drive — i capitoli tolti non si rileggono
finché la sincronizzazione non li riporta. Lo spazio si stima dai `bytes` dell'indice:
sommare i file di cento capitoli a ogni apertura della scheda sarebbe
migliaia di letture.

### Scaricare dai siti

Impostazioni → Scarica un manga fa dal telefono quello che il pannello MangaArchive
di Cobalt fa dal server: si cerca un titolo o si incolla il link di una
serie (MangaK, ManhwaRead, Asura Scans), la si verifica — titolo,
copertina, autori, generi, capitoli — e la si scarica.

La ricerca dà, mentre si scrive, quello che darebbe la barra di ricerca di
ogni sito: MangaK con la sua API (`titles/search`), Asura Scans con la sua
(`api/search`, senza i romanzi), ManhwaRead con la pagina dei risultati
(`/?s=…`), letta da una WebView invisibile perché Cloudflare
non risponde al client HTTP dell'app nemmeno dopo la verifica, e blocca a
parte la ricerca rapida di `admin-ajax.php`. Se la verifica chiede un tocco,
al posto dei risultati compare la riga che la apre. Scegliere un risultato
è incollarne il link. Letta la serie si apre una pagina sua, con la
copertina e quello che il sito ne dice, in cui si sceglie:

- **tutta**, **man mano**, **dal capitolo scelto in poi** o **solo i
  capitoli toccati**, quattro schede con quello che fanno scritto sotto.
  L'elenco dei capitoli scorre con la pagina, si filtra per numero o titolo
  (Invio sceglie il capitolo con quel numero), si gira dal più recente,
  segna quelli già in libreria e, scegliendoli uno per uno, prende un
  intervallo col tocco lungo. In ogni caso `series.json` ha l'elenco
  completo: gli altri restano visibili come non scaricati;
- **dove**: nella cartella di Drive della libreria, e le tavole lasciano il
  telefono appena Drive le ha; su Drive e anche sul telefono; o, senza
  Drive, sul telefono;
- **con una pausa** fra le richieste, da niente a due secondi, perché i siti
  bloccano chi scarica a raffica. Sta fra le «Avanzate»: quella di partenza
  va bene quasi sempre.

In fondo alla pagina resta il riepilogo — quanti capitoli, dove — con il
pulsante. Chiudendola senza scegliere, la serie resta sotto la ricerca e la
pagina si riapre da lì.

**Man mano** scarica cinque capitoli dal capitolo scelto (di partenza il
primo non letto) e poi tiene sempre cinque capitoli da leggere davanti
all'ultimo letto o aperto: uscendo dal lettore, o quando la libreria si
rilegge, l'app mette in coda quelli che mancano (`data/read_ahead.dart`).
I capitoli prima del primo che si ha non arrivano da soli: chi parte dal 40
non vuole i primi trentanove. Arrivati in fondo all'elenco che si
conosceva, i capitoli nuovi li porta il controllo delle serie seguite, solo
quanti ne servono, e una serie man mano resta seguita anche conclusa,
finché non si smette. Con un server collegato è lui a scaricare e a
seguire la serie, ma i capitoli glieli chiede l'app, che sa cosa si legge:
quelli dell'indice li mette nella sua coda, quelli nuovi del sito glieli fa
cercare (`docs/server-api.md`, `PUT /v2/ongoing/{key}`). Un server di
prima, che non elenca `ahead` fra le sue `features`, non lo offre: man
mano allora scarica il telefono. Non c'è con i siti dietro la verifica del
browser, che né il telefono né il server superano da soli.

La pausa è un ritmo, non una fila: le tavole di un capitolo scendono su più
corsie, e la pausa separa l'inizio di una richiesta dal seguente. Quando il
sito o Drive rispondono «troppe richieste», aspettano tutte le corsie
insieme, quanto chiede `Retry-After` o con un'attesa che raddoppia. Su Drive
il capitolo finito sale mentre il seguente scende, i file piccoli in una
richiesta sola (multipart), perché Drive conta le richieste e non i byte.

Il download finisce in una coda che continua a schermo spento, con la
notifica che dice a che punto è; la schermata mostra la serie in corso e le
altre in attesa, e sotto le **serie scaricate di recente**, una per riga
con l'esito più recente e quante volte è scesa (man mano ogni capitolo è un
lavoro): la riga apre la serie se è in libreria, e un download fallito si
riprova dal suo link. Rifare lo stesso download porta solo ciò che manca o
è rovinato.

Le **serie in corso** scaricate da qui si ricontrollano, a mano o ogni
giorno a un'ora (solo col Wi-Fi, se si vuole), e arrivano solo i capitoli
nuovi, nella stessa destinazione. Una serie esce da sola solo quando il sito
la dà per conclusa o cancellata, dopo aver messo in coda gli ultimi
capitoli, che spesso escono proprio insieme a «concluso»; in pausa, o con
uno stato che il sito scrive in un modo che non si riconosce, resta seguita.
Un lavoro messo in coda dal controllo aggiunge i suoi capitoli a quello
chiesto dall'utente per la stessa serie, invece di prenderne il posto. Se
all'ora del controllo manca la rete si riprova mezz'ora dopo, e aprendo
l'app la catena dei controlli si rimette in piedi se si era spezzata.
Quelle del server le segue il suo timer.

ManhwaRead sta spesso dietro la verifica di Cloudflare: sul server la passa
Chromium; qui la pagina si apre in una WebView, la verifica la supera chi
usa il telefono, e appena compare l'elenco dei capitoli l'app se lo prende
e torna indietro da sola.

Asura Scans dà tutto dalla sua API (`api.asurascans.com`): serie, elenco
completo dei capitoli e tavole con le misure. I capitoli in accesso
anticipato, che senza abbonamento non hanno tavole, restano fuori
dall'elenco finché non si liberano, e allora arrivano come capitoli nuovi.
I link del sito portano un suffisso che cambia (`/comics/nano-machine-bd5bdaf8`):
in libreria resta quello senza, che il sito ridirige.

### Scaricare dal proprio server

Una serie sono ore di download, e il telefono deve restare acceso e in rete
per tutto il tempo. Chi ha un computer sempre acceso può farlo fare a lui:
**Kagami Server** (`server/`, guida in [server.md](server.md)) è lo stesso
motore, e l'app gli parla con l'API di [server-api.md](server-api.md).

- **Crearlo** non chiede niente sul server. Da *Crea il tuo server* l'app
  fa i passi che mancano — accesso con Google, cartella della libreria su
  Drive, permesso di scriverci — e ne esce un comando `docker run` solo, con
  l'immagine pubblicata dal progetto e tutto il resto in `KAGAMI_SETUP`:
  progetto Firebase, client «Web» del progetto e permesso duraturo del
  proprietario sul suo Drive. Chi lo incolla su un computer con Docker ha
  finito; poi scrive nell'app l'indirizzo del computer. Il comando contiene
  un segreto, e l'app lo dice.
- **Chi lo usa lo dice l'account Google**, non una chiave: ogni richiesta
  porta il token d'identità di Firebase, che Firebase rinnova da sé, e il
  server lo verifica con le chiavi pubbliche di Google. Il server ha un
  proprietario (quello del comando) e un elenco di account ammessi; gli
  altri ricevono `403`. Il collegamento salvato è solo l'indirizzo, fra le
  impostazioni del database: viaggia con backup e account, e su un telefono
  nuovo il server è già lì, per lo stesso account.
- **Ognuno sul suo Drive.** Ogni account ha sul server il suo permesso di
  Drive, la sua cartella, la sua coda e le sue serie in corso: i lavori di
  uno vanno nella cartella della libreria di quell'account, e nessuno vede
  la coda di un altro. La cartella è quella che legge l'app; se non ce n'è
  una, collegando il server la si sceglie prima.
- **Il permesso duraturo** è un refresh token per il client «Web» del
  progetto Firebase: Android dà all'app un codice per quel client
  (`serverAuthCode`) e l'app lo riscatta col segreto del client, che mette
  chi compila (`GOOGLE_SERVER_CLIENT_SECRET`). Senza, la build non può
  collegare server e lo dice. Il server rinnova i permessi con lo stesso
  client, che riceve nel comando. Chi dà il suo Drive al server di un altro
  si fida di chi lo gestisce, e il foglio lo scrive prima di chiederlo.

### Server e utenti

- **Il proprietario aggiunge gli account dall'app** (*Chi può usarlo*):
  scrive un indirizzo, il server lo ammette, e l'app scrive un invito su
  Firestore (`serverInvites`, un documento per server e indirizzo; le
  regole lo lasciano scrivere solo a nome proprio e leggere solo a mittente
  e destinatario). Il server non manda email e non conosce Firebase oltre
  ai token: l'invito serve solo a dire all'altro dov'è il server.
- **Chi è stato aggiunto lo scopre nell'app**: gli inviti per il suo
  indirizzo si ascoltano finché l'app è aperta, e ognuno dà una notifica
  una volta sola (canale «Server condivisi»; gli id già annunciati stanno
  fra le impostazioni, così un secondo telefono non la ripete). Toccarla
  apre *Scarica un manga*, dove l'invito è in cima alla sezione Server:
  collegarlo chiede il permesso sul proprio Drive e la cartella, se manca.
- **Togliere un account** lo chiude fuori dalla richiesta seguente, ferma il
  suo lavoro e cancella dal server permesso, coda e serie seguite; ciò che è
  già sul suo Drive resta. **Scollegare** il server, per chi non è il
  proprietario, gli fa dimenticare il proprio permesso e la propria coda.
- **La destinazione «Server»** compare per prima quando il server ha il
  permesso di Drive e una cartella di chi usa l'app, e scarica solo su
  Drive: il telefono gli manda il link con le stesse scelte (tutta, dal
  capitolo, i capitoli scelti, la pausa). Il telefono verifica la serie
  come sempre, perché mostrarla è suo compito; per ManhwaRead gli manda
  anche la pagina passata dalla verifica, perché il server non ha un
  browser.
- **La coda del server** si vede sotto quella del telefono, con avanzamento,
  esiti e serie in corso, e un lavoro si toglie da lì. L'app la chiede ogni
  tre secondi solo mentre la schermata è aperta: niente canale sempre
  aperto, che terrebbe accesa la radio.
- **La cartella**: se il server scrive in una cartella di Drive diversa da
  quella che legge l'app, la sezione lo dice, e un tocco gli fa usare quella
  dell'app.
- **In chiaro** va bene solo in casa o dentro Tailscale. Su un `http://`
  pubblico l'app avvisa che il token dell'account viaggia leggibile. Il
  chiaro è permesso a tutta l'app (`usesCleartextTraffic`), perché gli
  indirizzi sono dell'utente e non si possono elencare.

Il server resta un'aggiunta: senza, «Scarica un manga» è quello di prima.

### La sincronizzazione della cartella

Fino a qui l'ultimo tratto della catena — Drive → cartella del telefono — lo
faceva FolderSync, un'app a parte da impostare a parte. Ora lo può fare
Kagami, con l'account con cui già legge Drive (Impostazioni → Google Drive →
Sincronizzazione della cartella):

- **tre direzioni**: da Drive al telefono, dal telefono a Drive, o entrambe;
- **un giro a mano**, con l'avanzamento, e **uno ogni giorno a un'ora**,
  anche ad app chiusa, se si vuole solo col Wi-Fi;
- **le cancellazioni si propagano solo se lo si chiede.**

Il confronto non legge i contenuti: calcolare le impronte di gigabyte di
tavole dal telefono a ogni giro è il costo che gli indici esistono per
evitare. Ogni file ha un ricordo di com'era all'ultimo giro in cui le due
parti erano d'accordo — misura e data sul telefono, impronta su Drive —, e
il piano (`planSync`, una funzione che non tocca niente e si prova da sola)
è una tabella:

- cambiato da una parte sola: si copia dall'altra, se la direzione lo
  lascia fare;
- cambiato da tutt'e due: vince il più recente;
- mai visto, presente da tutt'e due con la stessa misura: si prende per
  uguale. È ciò che rende istantaneo il primo giro su una cartella che
  FolderSync aveva già riempito;
- sparito da una parte: con le cancellazioni si toglie anche dall'altra —
  da Drive solo nel cestino, recuperabile per trenta giorni —; senza, resta
  dove è e **non torna indietro**, finché non ne arriva una versione nuova;
- tolto da «Libera spazio»: resta tolto da quella parte sola, qualunque
  cosa dicano le cancellazioni (vedi «Liberare spazio dai capitoli
  letti»). Con FolderSync in sola discesa i capitoli tornavano al giro
  seguente; qui no.

Gli indici — `library.json`, `index.json`, `pages.json`, `series.json`,
`chapter.json` — scendono e basta, in qualunque direzione: li scrive
MangaArchive, e uno scritto dal telefono che salisse al posto suo
confonderebbe il server.

Il giro programmato è lo stesso codice Dart: `FolderSyncWorker.kt` accende
un motore Flutter senza schermo, che fa il giro e dice quando ha finito.
Riscriverlo in Kotlin avrebbe voluto dire due motori con le stesse regole.
Gira in primo piano con una notifica, perché un lavoro in background ha
dieci minuti e una libreria sono gigabyte; se il sistema non lo concede,
riprende al giro seguente da dove era, perché i ricordi si salvano mentre
si copia. Ogni giro è un lavoro singolo che accoda il successivo: un lavoro
periodico conterebbe le ventiquattr'ore da quando è partito davvero, e
l'ora scivolerebbe.

### L'archivio sul telefono

`packages/kagami_archive/` è nato come porting di `mangaarchive` (provider,
motore, indici, serie in corso) con le fixture dei suoi test, e scrive gli
stessi file:
stessi nomi di cartella — NFKC compresa —, stessi manifest con SHA-256 per
tavola, stessi indici con la stessa firma. Non è un secondo formato: è un
secondo archiviatore dello stesso, e le regole con cui i due convivono
nella stessa cartella stanno in MALF («Chi scrive»). In breve: una serie si
allunga nella cartella che ha già; un capitolo con `chapter.json` completo e
le tavole della misura giusta non si riscarica, chiunque l'abbia scritto;
gli indici si rifanno da tutte le cartelle di capitolo che ci sono;
`library.json` si riscrive cambiando una riga sola.

Il motore lavora sempre in una cartella del telefono, un capitolo alla
volta; la destinazione decide cosa vuol dire finire (`stores.dart`). Sul
telefono il capitolo si prepara in `<capitolo>.part` e si rinomina intero,
come i download da Drive. Su Drive le tavole si caricano, l'MD5 che Drive
risponde si confronta col file, e solo allora se ne vanno: fino a lì
restano nello spazio dell'app, e un giro interrotto riprende da loro. Drive
accetta due cartelle con lo stesso nome, quindi una cartella si crea solo
dopo averne elencato il genitore.

Sul telefono l'app non tocca `library.json`: la cartella potrebbe essere una
copia di quella del server. Le sue serie vanno in `reading/downloads.json`,
che la libreria unisce già per i download da Drive. Una cartella di Drive
senza `library.json` è una libreria vuota: è da lì che parte chi non ha il
server.

Miniature e tessere le fa Android (`ArchiveImages.kt`): una tavola da 16383
pixel decodificata in Dart sarebbe una bitmap da decine di megabyte nella
sua memoria. Dove il Kotlin non c'è non si fanno, e MALF lo permette.

La coda gira in `ArchiveWorker.kt`, un lavoro WorkManager in primo piano che
accende un motore Dart senza schermo, come la sincronizzazione: una serie
intera sono ore, e un'app in secondo piano Android la congela. Coda,
avanzamento, storico e serie da seguire sono file in `archive/` nello
spazio dell'app, che l'interfaccia rilegge ogni secondo mentre è aperta.
Senza rete il lavoro resta in coda e il giro riparte quando torna. Da
Android 15 un servizio `dataSync` ha sei ore al giorno: il lavoro si ferma
prima, e ricomincia da dove era.

## Percorso di sviluppo

1. **Fondamenta** — fatto: formato, lettura degli indici, stato su disco,
   permessi, griglia di base.
2. **Scheda della serie** — fatto: elenco capitoli, metadati, stato e voto.
3. **Lettore** — fatto: continuo e paginato, ripresa, capitolo successivo,
   precarico, zoom, luminosità, salto rapido.
4. **Libreria vera** — fatto: ricerca, filtri, ordinamenti, raccolte automatiche.
5. **Raccolte** — fatto: creazione, colore, ordinamento, assegnazione.
6. **Home** — fatto: riprendi, novità, da iniziare.
7. **Rifinitura** — transizioni, stati vuoti e schermata dei permessi fatti.
8. **Dati personali su database** — fatto: cronologia con le date, sessioni di
   lettura, ultima apertura, segnalibri, importazione dal vecchio `reading/`.
9. **Home, cronologia, statistiche, impostazioni e backup** — fatti.
10. **Libreria e scheda** — fatti: filtri a tre stati, ricerca con prefissi,
    disposizioni, selezione multipla, filtri e ricerca sui capitoli, simili,
    cadenza di pubblicazione.
11. **Lettore** — fatto: schermo acceso, adattamento, sfondo, doppia pagina,
    scorrimento automatico, segnalibri, blocco rotazione.
12. **Linguaggio visivo e striscia continua** — fatto: kit di componenti unico
    sul modello di Streak, barra sospesa, elenco capitoli e impostazioni del
    lettore in due fogli, avanzamento e ritorno in cima, e soprattutto la
    striscia senza giunture (sotto).

13. **Libreria ibrida con Google Drive** — fatto: sorgenti unite per serie e
    capitolo, streaming con cache, navigatore delle cartelle, download nella
    cartella o nello spazio dell'app. Da verificare su telefono: la latenza
    della prima tavola di un capitolo mai aperto e la durata dell'autorizzazione
    con l'app in stato *Testing*.

**Resta l'icona dell'app**, che è il solo punto aperto del percorso, e il
ritaglio automatico dei bordi bianchi delle tavole, che richiede di guardare i
pixel di ogni pagina e va deciso su un telefono vero.

Dopo la prima prova su telefono andranno guardate due cose che non si possono
misurare senza uno schermo: la fluidità della griglia
su una libreria vera e il consumo di memoria del lettore su capitoli lunghi.

### Novità, adesso con una data sua

Il segnale "novità" vuole sapere quando l'utente ha aperto la serie l'ultima
volta. MALF non lo registra e per un po' ci si è dovuti accontentare di
`updatedAt` dello stato, che cambia anche solo mettendo un voto. Ora quella data
la scrive il database (`lastOpenedAt`) e il backup se la porta dietro. Da
quando la novità ha un numero (vedi «Capitoli nuovi e notifiche») la data non
basta più a dirla da sola, ma resta ciò che la spegne quando la scheda è stata
aperta su un altro telefono. Su una serie mai aperta non c'è novità, c'è tutto
da iniziare.

### Ricerca sui titoli alternativi

La ricerca prende titolo, autori e artisti. I **titoli alternativi** restano
fuori perché `library.json` non li porta: stanno in `series.json`, che è un file
per serie e leggerli tutti per digitare in una casella di ricerca è
esattamente la scansione che il formato esiste per evitare. Per averli va
aggiunto un campo agli indici, prima in `malf.md` e in chi scrive gli indici.

## Fuori ambito

L'app non parla con il server Cobalt e non ne dipende: conosce i siti solo
attraverso i provider di `packages/kagami_archive/` e gli indici li scrive solo per
le serie che archivia lei. Un sito nuovo si aggiunge lì.
