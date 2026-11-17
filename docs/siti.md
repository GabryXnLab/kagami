# Siti degli utenti — formato di un provider caricabile

Un sito che Kagami non conosce si aggiunge dall'app, senza ricompilarla, con
un file JSON che dice **dove** stanno serie, capitoli e tavole nelle pagine del
sito. Il file non contiene codice: è una descrizione che il motore
(`packages/kagami_archive/lib/declarative.dart`) interpreta, uguale sul telefono
e sul server. Un sito che cambia forma si ripara aggiornando il suo file, senza
aspettare una release.

Lo stesso file serve anche a **sostituire** un sito incluso: un provider con
l'id di uno di quelli di Kagami (`coffeemanga`) prende il suo posto finché resta
installato **e confermato dall'utente** (Siti, «Sostituisci …»): finché non conferma, quel file
sta in elenco ma vale ancora il sito incluso, anche per i giri ad app chiusa. La conferma è per id e
impronta (sha-256 del file), in `archive/site-replacements.json`: un file cambiato la richiede di nuovo.
Il server legge `providers/` per conto suo e non conosce questa conferma (rischio aperto, F8.4 T10). Le chiavi delle serie restano `<id>:<id serie>`: se il file nuovo dà
alle serie un id diverso, la riparazione (`docs/malf.md` § Cambi d'identità) le
adotta come per un sito che ha cambiato forma.

Oltre ai siti inclusi e a quelli degli utenti c'è un terzo strato, il
**catalogo** firmato da chi compila: definizioni in questo stesso formato,
pubblicate a un indirizzo che app e server ricontrollano da soli, che stanno
sopra i siti inclusi e sotto quelli confermati dall'utente. Indice, firma,
varianti per `engine` e adozione: [catalogo.md](catalogo.md).

## Dove vive

Nella cartella della libreria, accanto a `library.json`:

```text
MangaArchive/
  library.json
  providers/
    examplescans.json
```

Un file per sito, con il nome uguale all'`id`. Sta nella libreria perché la
libreria è ciò che sopravvive: la vedono il telefono (cartella locale o Drive),
il server (che lavora sulla cartella di Drive dell'account) e una
reinstallazione. Un client che non conosce `providers/` la ignora; un
archiviatore che non sa interpretarla non può aggiornare le serie di quei siti,
ma le legge come tutte le altre. Kagami la scrive solo quando l'utente installa,
aggiorna o toglie un sito, e non la cancella mai per intero.

## Il file

```json
{
  "format": 1,
  "id": "examplescans",
  "name": "Example Scans",
  "version": 3,
  "update": "https://raw.githubusercontent.com/someone/sites/main/examplescans.json",
  "home": "https://examplescans.com",
  "hosts": ["examplescans.com"],
  "mediaHosts": ["cdn.examplescans.com", "*.examplecdn.net"],
  "icon": "https://examplescans.com/favicon.png",
  "series": {
    "path": "^/manga/([a-z0-9-]+)/?$",
    "url": "https://examplescans.com/manga/{id}",
    "title": "h1.entry-title",
    "cover": {"css": "div.thumb img", "attr": ["data-src", "src"]},
    "description": "div.summary",
    "status": "div.status span",
    "authors": {"css": "div.author a", "all": true},
    "genres": {"css": "div.genres a", "all": true},
    "alternativeTitles": {"css": "div.alternative", "split": "[,;/]"},
    "chapters": {
      "items": "ul.chapters li",
      "url": {"css": "a", "attr": "href"},
      "title": "a span.title",
      "date": "span.date",
      "id": {"from": "url", "regex": "/chapter-([a-z0-9-]+)/?$"}
    }
  },
  "chapter": {
    "path": "^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$",
    "pages": {"items": "div.reader img", "url": {"attr": ["data-src", "src"]}}
  },
  "search": {
    "url": "https://examplescans.com/?s={query}",
    "items": "div.result",
    "title": "h3 a",
    "link": {"css": "h3 a", "attr": "href"},
    "cover": {"css": "img", "attr": "src"},
    "latest": "span.latest"
  }
}
```

### Campi della radice

`extends` non è una chiave del formato: vive solo nei sorgenti di `catalog/sites/` e `build` la
risolve prima di pubblicare (`docs/catalogo.md`, «Temi»): l'interprete non la conosce.

| Campo | Obbligatorio | Cosa |
|---|---|---|
| `format` | sì | `1` o `2` ([formato 2](#formato-2)). Un file con un `format` che il motore non conosce non si installa. |
| `id` | sì | `[a-z0-9]+`, al più 32 caratteri. Prima metà della chiave MALF e suffisso delle cartelle (`[<id>-<id serie>]`): non si cambia mai. |
| `name` | sì | Il nome che l'app mostra. |
| `version` | sì | Intero ≥ 1. Un aggiornamento si applica solo se è più alto. |
| `update` | no | Link https da cui rileggere il file per aggiornarlo. |
| `home` | sì | Pagina principale, su uno degli `hosts`. |
| `hosts` | sì | Gli host delle pagine (serie, capitoli, ricerca). |
| `mediaHosts` | no | Gli host di copertine e tavole. `*.dominio` vale per ogni sottodominio. |
| `icon` | no | Link dell'icona, su uno degli host dichiarati. |
| `series`, `chapter`, `search` | `series` e `chapter` sì | Vedi sotto. |

**Sicurezza.** Il motore chiede qualcosa solo in https, senza porta né
credenziali, e solo agli host dichiarati: ogni link letto dalle pagine passa
dallo stesso `allowedHost` dei siti inclusi. Un host deve essere un nome di
dominio con almeno un punto: niente indirizzi IP, `localhost`, né nomi che
finiscono in `.local`, `.lan`, `.internal`, `.home`, `.arpa` — il file arriva da
chiunque e il server gira nella rete di casa di qualcuno. Il nome non basta: per
i siti degli utenti `SiteHttp` (`publicOnly`) risolve l'host prima di ogni
richiesta, salti di redirect compresi, e rifiuta se uno qualsiasi degli indirizzi
è privato o riservato (loopback, 10/8, 172.16/12, 192.168/16, 169.254/16,
100.64/10, 0/8, multicast, 240/4 e blocchi di documentazione; IPv6 `::1`, `fc00::/7`,
`fe80::/10`, multicast, e gli IPv4 dentro `::ffff:` o `64:ff9b::/96`). **Limite
noto:** fra la risoluzione e la connessione il DNS può rispondere altro (DNS
rebinding); la connessione non è ancorata all'IP verificato, perché farlo senza
perdere SNI e verifica del certificato sul nome non ha una via pulita in
`dart:io`. I siti inclusi non sono controllati. Il Chromium dei controlli del
server (sezione [`browser`](#browser)) applica la stessa regola a ogni sua
richiesta, reindirizzamenti compresi, per tutti i siti, e restituisce la pagina
solo se è finita su uno di `browser.hosts`: i limiti rimasti sono in
`docs/server.md`. Ogni operazione di un sito (serie, tavole di un capitolo, ricerca) ha tre tetti: al più 8 richieste, 2 MB per risposta, 120 s in tutto; oltre è un errore dichiarato (`maxSite*` in `declarative.dart`). Il file è al più 64 KB,
ogni espressione regolare al più 300 caratteri. Il `RegExp` di Dart va in
backtracking, quindi ogni regex (`regex`, `split`, `path`) vede al più i primi
64 KB del testo, e all'installazione si rifiutano le backreference e i
quantificatori annidati: un gruppo seguito da `+`, `*` o `{n,}` che contiene a
sua volta `+`, `*` o `{n,}` (`(a+)+`, `(\w*)*`, `(.*a){2,}`). È un controllo
euristico sul sorgente, non una prova: un'espressione lenta in altri modi (per
esempio alternative che si sovrappongono, `(a|a)*`) può passare, e a limitarne il
danno resta il taglio a 64 KB. Un sito dietro la verifica del
browser (Cloudflare) dichiara la sezione [`browser`](#browser): senza, il motore
lo tratta come un sito incluso senza browser e fallisce con la verifica.

### Estrattori

Ogni campo da leggere è un **estrattore**, applicato a un nodo: la pagina intera
o un elemento di un elenco (`items`). Una stringa è un selettore CSS di cui si
prende il testo; un oggetto combina, in quest'ordine:

| Chiave | Cosa |
|---|---|
| `css` | selettore CSS dal nodo corrente (il primo elemento; con `all` tutti) |
| `json` | percorso in un JSON, con `.` e indici: `props.pageProps.manga.title`, `data.items`. Se il nodo è HTML o testo, prima si legge come JSON il testo selezionato (es. `{"css": "script#__NEXT_DATA__", "json": "props.pageProps"}`) |
| `attr` | attributo da prendere al posto del testo; una lista prova in ordine e prende il primo non vuoto |
| `html` | `true` per il contenuto HTML ridotto a testo a paragrafi (descrizioni) |
| `regex` | espressione da cercare nel valore: vale il primo gruppo se c'è, altrimenti tutta la corrispondenza; nessuna corrispondenza = nessun valore |
| `split` | espressione con cui dividere il valore in una lista (titoli alternativi) |
| `all` | `true` per una lista di valori invece del primo |
| `from` | `url` per partire dal link del nodo già letto (solo negli `items` dei capitoli), `page` per partire dall'indirizzo della pagina |
| `value` | un testo fisso, per un sito che non lo scrive (`"status": {"value": "ongoing"}`) |

I testi si ripuliscono dagli spazi; i link si risolvono rispetto alla pagina
(`/manga/x` → `https://host/manga/x`). Un campo facoltativo che non trova niente
resta vuoto; uno obbligatorio vuoto è un `ProviderChanged` («il sito ha cambiato
forma»), così la salute del sito (`health.dart`) lo dichiara rotto per intero.

### `series`

- `path` (obbligatorio): espressione sul percorso del link; il primo gruppo è
  l'**id della serie**. Il link di una serie è accettato se è https, su uno degli
  `hosts` e il suo percorso corrisponde.
- `url`: il link canonico della serie, con `{id}`; senza, il link accettato
  senza query né frammento.
- `json`: `true` se la pagina della serie è un JSON (un'API) invece di HTML;
  in quel caso `url` è l'indirizzo dell'API e gli estrattori usano `json`.
- `id`: estrattore che legge l'id dalla pagina invece che dal link (siti il cui
  link cambia mentre l'id resta).
- `title` (obbligatorio), `cover`, `description`, `status`, `authors`,
  `artists`, `genres`, `tags`, `alternativeTitles`, `type`: finiscono nei
  metadati normalizzati di MALF come per i siti inclusi.
- `chapters` (obbligatorio): `items` (estrattore di `all` implicito: gli
  elementi dell'elenco), `url` e `title` (obbligatori), `id` (default: l'ultimo
  segmento del percorso del link), `number` (default: il numero letto dal
  titolo, come per i siti inclusi), `date`, `order` (`auto` | `newest-first` |
  `oldest-first`, default `auto`: decide il numero nei titoli), `api`: un
  indirizzo con `{id}` da cui leggere l'elenco al posto della pagina della serie
  (un JSON; `items` allora usa `json`).

Due capitoli con lo stesso id, o un elenco vuoto, sono un `ProviderChanged`.

### `chapter`

- `path` (obbligatorio): espressione sul percorso del link di un capitolo; serve a
  riconoscere un link di capitolo incollato. Il primo gruppo è l'id della serie,
  da cui il link della serie si rifà con `series.url`.
- `json`: come in `series`, se la pagina del capitolo è un JSON.
- `api`: indirizzo da cui leggere le tavole, con `{url}` (il link del capitolo,
  codificato) o `{id}` (l'id del capitolo).
- `pages` (obbligatorio): `items` e `url` come per i capitoli; facoltativi
  `width` e `height`. Ogni tavola è un link su `hosts` o `mediaHosts`; una
  tavola senza `url` o un capitolo senza tavole è un `ProviderChanged`.
- Le tavole si chiedono col link del capitolo come referer, come per i siti inclusi.

### `search`

Facoltativa: senza, il sito non compare nella ricerca né in «Su altri siti», ma
accetta i link incollati.

- `url` (obbligatorio): indirizzo con `{query}` (codificata).
- `json`: `true` se la risposta è un JSON.
- `items`, `title`, `link` (il link della serie; obbligatori), `cover`, `latest` (il nome o il
  numero dell'ultimo capitolo), `status`. Un risultato il cui link `series.path`
  non accetta si scarta. Si tengono i primi 10.

### `browser`

Facoltativa, per un sito dietro una verifica del browser (Cloudflare): fa
seguire al sito la stessa strada dei siti inclusi con `Provider.browser` —
WebView sul telefono (anche invisibile per la ricerca), pagina mandata al server
(`snapshot`), Chromium senza schermo nei controlli del server, salto nei
controlli automatici quando la verifica chiede un tocco.

```json
"browser": {
  "hosts": ["examplescans.com"],
  "seriesReady": "ul.chapters li",
  "searchReady": "form.search-form"
}
```

- `hosts` (obbligatorio): gli host di cui portarsi dietro i cookie della
  verifica, fra gli `hosts` del sito.
- `seriesReady` (obbligatorio): selettore CSS che c'è solo sulla pagina vera di
  una serie, non su quella della verifica (di solito l'elenco dei capitoli).
- `searchReady` (obbligatorio): lo stesso per la pagina principale o dei
  risultati.

Il file dà solo selettori: il JavaScript che la WebView e il Chromium valutano
lo scrive il motore (`!!document.querySelector(<selettore>)`, come nei siti inclusi), con il
selettore codificato come stringa JSON. Un motore che non conosce `browser` lo
ignora e tratta il sito come prima: fallisce con la verifica, come un sito
incluso senza browser. Per questo non cambia `format`.

#### Pagina resa (`pages`)

Per un sito che costruisce serie, tavole o risultati solo col JavaScript (la
pagina scaricata è vuota rispetto a quella del browser), `pages` dice quali
pagine si leggono dal DOM reso da un browser invece che dalla risposta HTTP.
Chiede `"format": 2` ed è dell'`engine` 16.

```json
"browser": {
  "hosts": ["examplescans.com"],
  "seriesReady": "ul.chapters li",
  "searchReady": "div.result",
  "chapterReady": "div.reader img",
  "pages": ["series", "chapter"]
}
```

- `pages`: da uno a tre valori diversi fra `series` (la pagina della serie,
  `series.url` o il link stesso), `chapter` (la pagina del capitolo) e `search`
  (la pagina dei risultati, `search.url`). Solo pagine HTML: con `json` o
  `chapter.api` nella stessa parte (riserve comprese) il file si rifiuta.
- `chapterReady`: selettore della pagina del capitolo pronta (di solito le
  tavole); obbligatorio se `pages` contiene `chapter`.

Per ognuna di quelle pagine il motore apre l'indirizzo nel browser, aspetta
che il selettore `*Ready` corrispondente trovi qualcosa
(`!!document.querySelector(<selettore>)`, scritto dal motore come sopra) e
prende `document.documentElement.outerHTML`, anche quello scritto dal motore:
dal file non arriva mai JavaScript. Da lì gli estrattori lavorano come su una
pagina scaricata. Le richieste di `chapters.api`, della ricetta (`fetch`) e
delle tavole restano HTTP.

Se la pagina della serie è già in mano (lo snapshot di `SnapshotHttp`, preso
dal browser dopo la verifica di Cloudflare o mandato dal telefono al server),
l'interprete usa quella e non la rende di nuovo: vale per `series` come per
una serie scaricata.

Tetti: una pagina resa conta come una richiesta; il browser ha al più 60 s per
pagina (dentro i 120 s dell'operazione), e oltre la pagina è «non pronta», un
errore dichiarato; l'HTML reso ha al più 2 MB anche per i siti del catalogo;
l'indirizzo dev'essere `https` su un host di `browser.hosts`, e il browser
scarta la pagina finita altrove (nell'app l'host si ricontrolla a ogni redirect: `hostAllowed` in
`PageBrowser.kt`, stessa regola di `pageHostAllowed` in `page_browser.dart`, che la applica anche su iOS e macOS).

Il browser lo dà chi ospita il motore, per interfaccia (`PageRenderer` in
`renderer.dart` del pacchetto, installato con `installPageRenderer`): sul
server il Chromium senza schermo dei controlli, nell'app quello di
`platformPageBrowser` (`lib/src/archive/page_browser.dart`): su Android la
WebView invisibile del giro ad app chiusa (`PageBrowser.kt`), su iOS e macOS
una WKWebView di `webview_flutter` senza widget, con lo stesso contratto
(solo `https` su un host dichiarato, redirect della pagina altrove = `null`,
attesa a passi di 1 s, host finale ricontrollato). iOS non ha giri ad app
chiusa: lì vale solo ad app aperta. Dove non c'è (Linux, Windows, un server
senza Chromium) quelle pagine falliscono con un errore dichiarato, «serve il
browser», non con un sito cambiato.

I siti che cifrano le tavole con codice proprio si descrivono solo se il codice
si riduce alle trasformazioni della ricetta del [formato 2](#formato-2) (base64,
xor, HMAC, aritmetica intera) con chiavi che stanno nella pagina o nel file. Se
la chiave la calcola il JavaScript del sito, come per Coffee Manga dal
2026-10-28, nel file entra solo come costante da ripubblicare quando cambia: un
interprete di quel codice vorrebbe dire codice nel file, ed è escluso di
proposito (vedi [Coffee Manga](#coffee-manga-cosa-entra-e-cosa-no)).

## Formato 2

Il formato 1 sa dire **dove** sta un valore, non **come** ricavarlo: un id che
serve a chiedere l'API dei capitoli, un link che il sito non scrive ma si
compone, un elenco di tavole codificato in base64 dentro uno script. I siti
inclusi che oggi non si possono descrivere lo fanno con poche righe di Dart
sempre uguali, e il formato 2 dà un nome a quelle righe. Resta una
descrizione: nessun ciclo libero, nessuna funzione definita da chi scrive il
file, ogni costrutto ha un tetto che si conosce all'installazione. Così un
file del catalogo può riparare un sito che ha cambiato forma senza una
release, e il motore resta in Dart puro senza un interprete di script (scelta
del piano dei provider remoti: QuickJS è rinviato).

Il formato 2 è un'estensione del formato 1: un file `"format": 2` che usa solo
chiavi del formato 1 vuol dire esattamente la stessa cosa. Le chiavi nuove
valgono solo con `"format": 2`; in un file `"format": 1` restano chiavi
sconosciute e il file si rifiuta, così un file di formato 1 ha lo stesso
significato su ogni motore.

### Variabili e modelli

Ogni operazione (serie, tavole di un capitolo, ricerca) ha le sue
**variabili**: nomi `[a-z][A-Za-z0-9]*` di al più 32 caratteri, al più 64 per
operazione, ognuna scritta una volta sola. Ci sono già `id` (il primo gruppo
di `path`), `url` (il link della serie o del capitolo), `query` (la ricerca) e,
nelle tavole, `chapterId`; le altre le dichiara il file:

- `linkVars` (in `series` e `chapter`): estrattori sul solo link, prima di ogni
  richiesta (`{"from": "page", "regex": …}`). Servono quando l'indirizzo da
  chiedere non è il link così com'è.
- `vars`: estrattori sulla pagina appena letta, valutati in ordine, ognuno
  vede i precedenti. In `chapters` e `pages` valgono per ogni elemento.
- `keep` (in `chapters`): variabili dell'elemento che viaggiano col capitolo
  (`Chapter.metadata`, come `series_slug` per Asura o `manga_id` per ManhwaRead)
  e che le tavole ritrovano col loro nome. Solo variabili di `chapters.vars`, e
  mai `date`, che è già un dato del capitolo.

Un modello o un `var` che nomina una variabile che in quel punto non c'è (di un
elemento fuori dall'elemento, della pagina in un indirizzo chiesto prima di
leggerla) non si installa. Dopo `series.id`, `id` è l'id letto, come per
`{id}` in `chapters.api` del formato 1; nelle tavole `id` resta l'id del
capitolo, come in `chapter.api` del formato 1, uguale a `chapterId`. Una
variabile tiene il JSON o gli elementi HTML così come sono se il suo
estrattore si limita a selezionarli (`css`, `json`, `all`), così un `var`
può proseguire da lì; altrimenti tiene il testo. Un `var` su byte dà il valore intero (un solo
elemento), mai un numero per byte. In un modello una lista o un
oggetto non hanno un testo e contano come vuoti.

Un **modello** è un testo con `{nome}`. Ogni campo indirizzo del formato 1
(`series.url`, `chapters.api`, `chapter.api`, `search.url`) accetta in formato
2 una stringa con qualsiasi variabile, o un oggetto con i parametri a parte:

```json
"api": {
  "template": "https://api.mangak.io/titles/{mangaId}/chapters",
  "query": {"cv": "{cv}"}
}
```

In un indirizzo ogni variabile si codifica come componente (`/` diventa
`%2F`), e un parametro di `query` con valore vuoto non si scrive: il `?cv=` di
MangaK c'è solo quando la pagina lo dà. Una variabile non può stare
nell'host, come nel formato 1, perché deciderebbe lei a chi chiedere; l'host
di un indirizzo composto si controlla all'installazione su `hosts`. Al posto
di `{id}` del formato 1, `series.url` e `chapters.api` vogliono almeno una
variabile qualsiasi; `search.url` vuole sempre `{query}`. Una variabile vuota
nel percorso di un indirizzo è un `ProviderChanged`: il sito non ha dato il
valore che serviva. `canonical` e `seriesOfChapter` non chiedono niente:
`seriesOfChapter` rifà la serie solo se `series.url` usa soltanto `{id}`, o
da `series.link` se c'è ([Link canonico](#link-canonico)).

Un estrattore può anche **comporre** un valore: `{"template": "Chapter {n}"}`
dà il testo con le variabili sostituite, senza codifica. Se una variabile
del modello è vuota il risultato è vuoto, così un `first` (sotto) passa
all'alternativa. Altre chiavi nuove dell'estrattore:

| Chiave | Cosa |
|---|---|
| `var` | parte da una variabile invece che dal nodo (`{"var": "images"}`, poi `json` come sempre) |
| `template` | compone un testo, come sopra |
| `base` | modello del link rispetto a cui risolvere un link relativo, al posto della pagina: `{"json": "url", "base": "https://mangak.io"}` per un'API che dà percorsi del sito |
| `jsonAt` | espressione che segna dove comincia un valore JSON dentro un testo (`"\\bchapterData\\s*=\\s*"`): si legge l'oggetto o la lista che segue, a parentesi bilanciate, al più 2 MB. Fra più elementi selezionati vale il primo in cui l'espressione si trova |
| `first` | lista di estrattori: vale il primo non vuoto |
| `filters` | trasformazioni del valore letto, in ordine (sotto) |

`jsonAt` si applica dopo `css` e prima di `json`. Dove la specifica taceva:
l'espressione vede i primi 64 KB del testo, come ogni espressione, mentre il
JSON si legge dal testo intero; il testo è quello dell'elemento (il contenuto
di uno `script`) o di un valore che è già testo. Dopo la corrispondenza si
saltano gli spazi e deve cominciare `{` o `[`; se lì non c'è un JSON valido
(un oggetto JavaScript con le chiavi senza virgolette, una parentesi mai
chiusa) non c'è valore, senza passare all'elemento dopo. Un JSON che arriva ai
2 MB senza chiudersi è un errore dichiarato. Con `all` e senza `json` il valore
resta uno solo: `all` dice fra quali elementi cercare.

### Ripieghi

`first` vale ovunque ci sia un estrattore, `items` compresi (il primo che dà
un elenco non vuoto), al più 8 alternative. Serve dove il Dart ha un `??` o un
«se non c'è, prova questo»: il titolo nell'`h1` con una classe nota, poi in un
`h1` qualsiasi; `cover` oppure `cover_url`. Un estrattore con `first` non ha
altre chiavi, e `var` e `template` non stanno con `from`, `value` né fra loro.

Un indirizzo può avere ripieghi fra richieste: `{"try": [modello, modello],
"on": [404]}` chiede il primo e passa al successivo solo su uno degli stati
di `on` (default `[404]`); due modelli che danno lo stesso indirizzo si
chiedono una volta. Al più 4, e ognuno conta fra le 8 richieste
dell'operazione. È lo slug di Asura: prima senza il suffisso che il sito
appende ai link, poi com'era. Gli stati di `on` vanno da 400 a 599, e una
variabile vuota non fa passare all'alternativa (vale la regola sopra). Senza
`series.link`, il link canonico della serie è la prima alternativa, uguale per
ogni forma del link.

### Filtri e condizioni

`filters` trasforma un valore: `{"replace": [espressione, sostituto]}` (tutte
le corrispondenze; `$1` nel sostituto è il gruppo), `"lower"`, `"trim"`,
`"number"` (un numero JSON o di testo nella forma corta: `12.0` → `12`,
`12.5` resta), `{"prefix": testo}`, `{"suffix": testo}`. Le espressioni hanno
le regole e i tetti di quelle del formato 1. Un filtro su una lista vale per
ogni voce.

Una **condizione** è un estrattore più uno fra `equals` (un valore JSON o un
modello; si confronta il testo, quindi `12` e `"12"` sono uguali), `matches`
(espressione), `exists` (`true`/`false`), con `not` per negarla. Si usano in:

- `skip` (in `chapters`, `pages` e `search`): lista; un elemento per cui una
  condizione vale si scarta. I capitoli in accesso anticipato di Asura,
  `{"json": "is_premium", "equals": true}`; i romanzi nella sua ricerca.
- `require` (in `series`, `chapter` e `search`): lista; se una non vale, è un
  `ProviderChanged`. Serve ai controlli di coerenza dei provider Dart: la
  pagina del capitolo è proprio quella chiesta (`{"json": "data.chapter.id",
  "equals": "{chapterId}"}`).
- `locked` (in `chapter`): se vale, il capitolo è riservato agli abbonati del
  sito e il motore lo dice con il suo messaggio, non con «il sito ha cambiato
  forma».

Dove la specifica taceva, il motore legge così. I filtri valgono su ogni valore
già ripulito dagli spazi e prima che diventi un link (`base` o un campo link);
un filtro che dà un testo vuoto, o `"number"` su un testo che non è un numero
decimale (`0x1F` e `Extra` no), toglie il valore, così un `first` passa
all'alternativa. `replace` vede i primi 64 KB come ogni espressione, `$1`…`$9`
sono i gruppi (uno che non c'è vale vuoto), e nessun filtro fa crescere un
valore oltre i 2 MB. `filters` è una lista non vuota, e ogni filtro un nome o
un oggetto con una chiave sola. In `equals` un letterale è un testo, un numero
o un booleano (né `null`, né liste, né oggetti); due testi che sono lo stesso
numero sono uguali (`12` e `12.0`), un modello che non si compone non è uguale
a niente, e con `all` basta che un valore superi la prova (vale anche per
`matches`). `exists` guarda se l'estrattore dà un valore qualsiasi: un `false`
del JSON esiste. `require` e `locked` si provano sulla pagina appena letta,
dopo `vars` e prima dei campi, `require` per primo; `skip` su ogni elemento,
dopo le sue `vars`. `locked` è una condizione sola, non una lista, e dà un
`ProviderError` «riservato agli abbonati».

### Schemi di host

`mediaHosts` accetta, oltre a `*.dominio`, il carattere `?` per una lettera o
cifra qualsiasi, al più 4 per host e mai nell'ultima etichetta: MangaK serve
le tavole da `rx.qvzr?.org`, con la lettera che cambia. Il nome con `?`
sostituito deve restare un dominio pubblico, con le regole di
[Sicurezza](#campi-della-radice); per le pagine (`hosts`) gli schemi non
valgono, perché lì si chiede solo ciò che il file nomina. Un `?` sta per un
solo carattere fra `a-z` e `0-9` (non un trattino, non zero caratteri), si
combina con `*.` (`*.img??.net`), e all'installazione lo schema si prova con
una lettera e con una cifra al posto di ogni `?`: tutte e due devono essere un
dominio pubblico.

### Link canonico

Con `"json": true`, `series.url` è l'indirizzo dell'API e, senza altro, fa
anche da link della serie: Asura Scans uscirebbe con un link su
`api.asurascans.com`, che il suo stesso `series.path` rifiuta. `series.link`
separa le due cose: è il **modello del link canonico** della serie (una
stringa, senza `query` né `try`), mentre `series.url` resta solo l'indirizzo
da chiedere.

```json
"series": {
  "path": "^/comics/([a-z0-9-]+)/?$",
  "linkVars": {"slug": {"from": "page", "regex": "…", "filters": [{"replace": ["-[0-9a-f]{8}$", ""]}]}},
  "url": {"try": ["https://api.asurascans.com/api/series/{slug}", "…"]},
  "json": true,
  "link": "https://asurascans.com/comics/{slug}"
}
```

- **Variabili:** solo `id` e quelle di `linkVars`, mai le `vars` della pagina,
  perché il link deve potersi comporre senza richieste. Si compone due volte:
  prima di chiedere, con `id` letto dal link (è `canonical`, che riconosce lo
  stesso link incollato in due forme), e dopo aver letto la serie, con `id`
  dato da `series.id` se c'è (è `Series.url`). Le variabili di `linkVars`
  restano quelle del link in tutte e due.
- **Host:** fisso e fra gli `hosts`, controllato all'installazione come per
  ogni indirizzo composto.
- **Percorso:** il link composto deve essere accettato da `series.path`, e
  ricomporlo dal suo stesso risultato deve dare lo stesso link (`canonical` è
  idempotente). All'installazione si prova sul link di prova, a runtime su ogni
  link: un link che `series.path` rifiuta è un `ProviderChanged` con guasto
  `series.link`; per `canonical`, che non solleva, resta il link così come
  è arrivato.
- **`seriesOfChapter`:** con `series.link` rifà la serie da `series.link`, con
  `id` dal primo gruppo di `chapter.path` e `linkVars` valutate sul link del
  capitolo; se una resta vuota il link del capitolo non dà la serie. Senza
  `series.link` vale la regola di sopra (solo se `series.url` usa soltanto
  `{id}`).

Senza `series.link` tutto resta com'era: link e indirizzo coincidono, e il
canonico è la prima alternativa di `try`. Un file con `"json": true` e senza
`series.link` resta valido; `tool/site.dart lint` lo segnala.

### Conteggio dichiarato

Un'API che taglia l'elenco (un `limit` cambiato, una pagina sola di una lista
paginata) dà capitoli validi, solo meno: senza un controllo passa per buono,
e l'archivio perde capitoli in silenzio. Molti siti scrivono quanti capitoli
ha la serie; `expect` in `chapters` è l'estrattore di quel numero:

```json
"chapters": {
  "api": "…",
  "expect": {"var": "data", "json": "initialManga.stats.chaptersCount"}
}
```

- Si valuta una volta, sulla pagina della serie, dopo le sue `vars` (vede le
  variabili della serie, non quelle degli elementi). Il valore deve essere un
  intero decimale ≥ 0, letto come `"number"`; un testo che non lo è conta come
  assente.
- Il confronto è sugli elementi di `items` **prima di `skip`**: i capitoli che
  il file scarta per scelta (in accesso anticipato, romanzi) il sito li conta,
  e toglierli darebbe un falso allarme. Gli elementi senza `url` o `title`
  sono già un errore loro.
- **Tolleranza del 5% verso il basso:** i buchi nella numerazione sono del
  sito (MangaK ne ha 5 su 270), un taglio vero (paginazione, `limit`) toglie
  molto di più. Con `mancano = dichiarati - elementi`, è un `ProviderChanged`
  con guasto `series.chapters.expect` e `detail` «265 capitoli, il sito ne
  dichiara 270» solo se `mancano > ceil(0.05 * dichiarati)` (almeno 1:
  `chaptersTolerance` in `model.dart`, la usa anche il Dart di MangaK). Uno
  scarto entro la soglia non blocca ma la traccia segna `series.chapters.expect`
  in `degraded`, e la sonda lo dà come sito degradato. Uno più lungo va bene: il
  conteggio sta spesso in una pagina che il sito tiene in cache, e per un po'
  dopo l'uscita di un capitolo l'elenco ne ha uno in più.
- Se `expect` non dà un valore il controllo si salta e la traccia lo segna in
  `degraded` come `series.chapters.expect`, senza numero d'alternativa: il
  sito funziona, ma ha smesso di dire il conteggio e la sonda lo fa vedere.

### Blocchi di riserva

`first` e `try` ripiegano su un campo o su un indirizzo; `fallback` ripiega su
una **strategia** intera, come da un'API alla pagina HTML o viceversa. Sta in
`chapters` (in `series`), `chapter` e `search`: è una lista di al più 2
blocchi della stessa forma del blocco che la contiene.

```json
"chapter": {
  "path": "…",
  "vars": {"data": {"css": "script#__NEXT_DATA__", "json": "props.pageProps"}},
  "pages": {"items": {"var": "data", "json": "initialChapter.pages"}, "url": {"json": "url"}},
  "fallback": [
    {
      "api": "https://api.mangak.io/titles/{titleId}/chapters/{chapterId}/images",
      "json": true,
      "pages": {"items": {"json": "…"}, "url": {"json": "url"}}
    }
  ]
}
```

- **Quando:** il blocco principale finisce con un `ProviderChanged` o con uno
  stato fra 400 e 499 che non sia 403 o 429. Un 403 è quasi sempre una
  verifica anti-bot e un 429 un limite di frequenza: un'altra strada sullo
  stesso sito li peggiorerebbe. Gli errori di rete, i 5xx e `locked` (che dà
  un `ProviderError`) non passano alla riserva. Se una riserva fallisce si
  prova la successiva, alle stesse condizioni.
- **Forma:** un blocco di riserva ha le chiavi del blocco che lo contiene
  tranne `path`, che riconosce i link ed è uno solo, e `fallback`: **niente
  riserve annidate**. Ha `linkVars`, `vars`, `recipe`, `require`, i suoi
  `first` e `try`, e non eredita niente dal principale: si legge da solo.
  In `chapters` una riserva senza `api` legge la pagina della serie già letta,
  senza richieste nuove.
- **Variabili:** vede quello che vedeva il principale al suo inizio (le
  variabili della serie per `chapters`, `id`, `chapterId`, `url` e quelle
  tenute per `chapter`, `query` per `search`), mai quelle che il principale
  aveva letto prima di fallire. Le riserve di `chapters` devono dichiarare in
  `keep` gli stessi nomi del principale, controllato all'installazione: le
  tavole ritrovano i loro valori qualunque strategia abbia dato l'elenco.
- **Richieste:** ogni richiesta di una riserva conta fra le 8
  dell'operazione, comprese quelle già fatte dal principale; se il bilancio è
  finito la riserva non si prova.
- **Esito:** se una riserva riesce vale il suo risultato e la traccia lo segna
  (sotto). Se falliscono tutte, l'errore è quello del blocco principale, con il
  suo guasto: è la forma che chi ha scritto il file considera giusta, e da lì
  si ripara.
- **Stessa identità:** gli id che una riserva dà (dei capitoli, delle serie
  nella ricerca) devono essere gli stessi del principale, e le tavole lo stesso
  numero; un id diverso è un cambio d'identità silenzioso (`docs/malf.md`). Il
  motore non può confrontarli a runtime, perché ha in mano un solo risultato:
  lo prova `tool/site.dart check`, che sui canarini esegue ogni strategia e
  confronta gli esiti.

### Ricetta

Quello che non è una lettura né una composizione (decodificare, decifrare,
fare un conto) sta in una **ricetta**: `recipe` in `series`, `chapter` o
`search`, una lista di passi eseguiti una volta, in ordine, dopo `vars` e
prima dei campi. Ogni passo dà una variabile:

```json
{"let": "images", "json": "{decoded}"}
```

Un ingresso che è esattamente `{nome}` passa il valore com'è (byte compresi);
un altro testo è un modello. I valori sono testo, byte, interi o JSON, e ogni
passo ha un tipo d'uscita fisso, quindi un passo che riceve il tipo sbagliato
si rifiuta all'installazione, non a metà di un capitolo. Ogni passo ammette
`check` (espressione che il testo del risultato deve soddisfare, altrimenti
`ProviderChanged`) e `when` (un'espressione `intExpr`: se è 0 il passo si salta
e la variabile resta vuota).

| Passo | Ingresso → uscita |
|---|---|
| `get` | un estrattore (di solito `var` più `json`) → testo o JSON |
| `template` | modello → testo |
| `json` | testo o byte (UTF-8) → JSON |
| `base64` | testo → byte; `"url": true` per l'alfabeto `-_`, il riempimento `=` mancante si aggiunge; `"encode": true` per il verso opposto |
| `hex` | testo esadecimale → byte; `"encode": true` per il verso opposto |
| `utf8` | byte → testo (sequenze non valide: errore) |
| `hmacSha256` | `{"key": testo o byte, "message": modello}` → 32 byte |
| `xor` | `{"data": byte, "key": byte}` → byte lunghi come `data`; la chiave si ripete se è più corta |
| `intExpr` | espressione → intero |
| `switch` | `"switch": modello, "cases": {"0": ingresso, …}, "default": ingresso` → il valore del caso; senza caso né `default`, `ProviderChanged` |
| `range` | `{"count": intExpr, "max": n, "as": "b"}` più `do`: un solo passo (né `range` né `fetch`) ripetuto con `b` da 0 a count−1 → byte concatenati, o lista se `do` dà testo o JSON |
| `fetch` | indirizzo (modello, `query`, `try`) più `json` → la risposta come JSON o testo; conta fra le richieste dell'operazione |

`intExpr` è un'espressione su interi: costanti decimali, variabili intere (o
testo che è un intero), `len(x)` (byte di un valore, voci di una lista),
parentesi, `+ - * / %` (divisione intera, troncata; per zero è un
`ProviderChanged`), `& | ^ ~ << >>` sui 32 bit con segno come in JavaScript,
confronti `== != < <= > >=`, `&& || !` (valgono 1 o 0). Gli interi sono a 64
bit. L'espressione sta nel file: il motore non valuta mai espressioni lette
dalle pagine.

Dove la specifica taceva (R4.4): una variabile di `vars` o di `get` vale
«testo o JSON» e si controlla solo leggendola; `json` accetta testo o byte,
`base64`/`hex` decodificano un testo e codificano byte o testo (in UTF-8);
`utf8` vuole byte; in un modello e in `intExpr` i byte si rifiutano, e
`intExpr` rifiuta anche il JSON (`len` no); `check` su un passo che dà byte si
rifiuta; i casi di `switch` danno un tipo solo (testo e «testo o JSON» si
uniscono nel secondo). Un ingresso vuoto (una variabile saltata da `when` o
mai letta) dà un risultato vuoto senza errore, salvo in `intExpr`, dove è un
`ProviderChanged`; `check` su un risultato vuoto prova il testo vuoto. I
modificatori di `base64` sono senza mescolanze: senza `url` `-` e `_` sono un
errore, con `url` lo sono `+` e `/`. La ricetta corre dopo `require` (e dopo
`locked` nelle tavole), così una pagina sbagliata dà il guasto di `require`.

Decisi in R4.5: il passo di `do` non ha `let`, `check` né `when` (il
`check` va sul `range`), e vede `as` come intero; una ripetizione che dà vuoto
non aggiunge byte, mentre in una lista resta un `null` al suo posto. Un
`count` senza variabili si controlla all'installazione (fuori da 0…`max` il
file non si installa), altrimenti a ogni esecuzione (`ProviderChanged`); ogni
ripetizione conta fra i 2048 passi eseguiti, il risultato fra i 2 MB. La
chiave di `hmacSha256` è byte o testo (in UTF-8); `xor` vuole byte da tutte e
due le parti, e una chiave di zero byte è un guasto. `fetch` chiede solo gli
`hosts` del sito (controllati come gli altri indirizzi), dà il corpo come
testo senza `json` e, se manca una variabile dell'indirizzo, un risultato
vuoto senza richiesta.

Non ci sono cicli liberi né passi che ne chiamano altri: l'unica ripetizione è
`range`, con un `max` dichiarato, e il suo `do` non si annida. Così il lavoro
massimo di un file si conosce leggendolo.

Le tavole di ManhwaRead, che stanno in base64 dentro `chapterData` di uno
script, sono una ricetta di tre passi:

```json
"chapter": {
  "path": "^/manhwa/([a-z0-9-]+)/[a-z0-9-]+/?$",
  "vars": {
    "data": {"css": "script", "all": true, "jsonAt": "\\bchapterData\\s*=\\s*"},
    "cdn": {"var": "data", "json": "base", "filters": [{"replace": ["/+$", ""]}]}
  },
  "recipe": [
    {"let": "encoded", "get": {"var": "data", "json": "data"}, "check": "^[A-Za-z0-9+/=]+$"},
    {"let": "bytes", "base64": "{encoded}"},
    {"let": "images", "json": "{bytes}"}
  ],
  "pages": {
    "items": {"var": "images"},
    "url": {"json": "src", "base": "{cdn}/"},
    "width": {"json": "w"},
    "height": {"json": "h"}
  }
}
```

### Tetti del formato 2

Si aggiungono a quelli del formato 1 (8 richieste, 2 MB per risposta, 120 s per
operazione, file di 64 KB, espressioni di 300 caratteri), che restano.

| Cosa | Tetto | Perché |
|---|---|---|
| passi di una `recipe` | 32 | Coffee Manga, il caso più lungo, ne usa 31 |
| `range` | `max` obbligatorio, ≤ 256 iterazioni | 256 blocchi da 32 byte coprono 8 KB di manifest cifrato, molto più di un capitolo |
| passi eseguiti in un'operazione | 2048 | 32 passi più i `range`, con margine; oltre è un errore dichiarato |
| un valore (testo, byte, JSON letto) | 2 MB | come una risposta: niente cresce oltre ciò che è arrivato |
| tutte le variabili di un'operazione | 8 MB | quattro risposte intere |
| messaggio di `hmacSha256`, testo di un modello | 64 KB | sono chiavi e indirizzi, non dati |
| indirizzo composto | 4 KB | |
| `intExpr` | 200 caratteri | |
| `first` / `try` | 8 / 4 alternative | |
| `fallback` | 2 blocchi, non annidati | ogni strategia in più è una definizione in più da tenere viva |
| `?` in un host | 4, mai nell'ultima etichetta | |

### Compatibilità ed `engine`

Il motore che precede il formato 2 (`siteFormat = 1`) rifiuta un file
`"format": 2` in `_Spec.read` con «Formato del sito 2 non supportato»; quello
di oggi (`siteFormat = 2`, `catalogEngine = 16`) rifiuta allo stesso modo un
file che usa una chiave oltre il suo `engine`, con `SiteEngineError`. Le
conseguenze sono quelle di un file non valido, e nessuna perde dati: l'app non lo installa;
in `providers/` `loadSites` lo segnala e lo salta, e il server tiene la
versione di prima di quel sito; dal catalogo non arriva nemmeno, perché la
variante ha un `minEngine` più alto dell'`engine` di quell'app
([catalogo.md](catalogo.md#engine-e-varianti)), e l'app tiene l'ultima buona o
il sito incluso. Un motore del formato 2 legge anche il formato 1.

`engine` cresce di uno per ogni primitiva, nell'ordine in cui il pacchetto le
implementa: una release contiene sempre tutte le primitive fino al suo
`engine`. Se una primitiva arriva fuori dall'ordine qui sotto prende il primo
numero libero, e la voce che la implementa corregge la tabella. Un motore che
trova una chiave di un `engine` più alto rifiuta il file nominando la chiave;
per i file dei siti degli utenti, che non dichiarano `engine`, l'app traduce
questo errore in «serve Kagami più nuovo».

`minEngine` di un file è il massimo `engine` delle chiavi che usa. Lo calcola
una funzione del pacchetto, la stessa per `tool/catalog.dart build`, per
l'app che decide se un sito può andare al server (`engineForSite`) e per i
file installati a mano: `siteMinEngine` in `site_engine.dart`, che dà anche la
chiave che lo chiede. Le chiavi dentro `vars`, `linkVars`, `query` e `cases`
sono nomi, e il valore di `equals` è un letterale: non contano.

| `engine` | Primitiva | Chiavi | Voce |
|---|---|---|---|
| 1 | formato 1, compreso `browser` | — | oggi |
| 2 | variabili e modelli | `"format": 2`, `linkVars`, `vars`, `keep`, `var`, `template`, `query`, `base`, segnaposto diversi da `{id}`/`{url}`/`{query}` | P4.2 |
| 3 | ripieghi | `first`, `try`, `on` | P4.2 |
| 4 | filtri e condizioni | `filters`, `skip`, `require`, `locked` | P4.2 |
| 5 | schemi di host | `?` in `mediaHosts` | P4.2 |
| 6 | JSON dentro un testo | `jsonAt` | P4.2 |
| 7 | link canonico | `link` in `series` (in `search` è del formato 1) | R4.2 |
| 8 | conteggio dichiarato | `expect` | R4.3 |
| 9 | blocchi di riserva | `fallback` | R4.3 |
| 10 | ricetta | `recipe`, `let`, `get`, `json`, `utf8`, `check` | R4.4 |
| 11 | codifiche | `base64`, `hex` | R4.4 |
| 12 | aritmetica e scelta | `intExpr`, `switch`, `when` | R4.4 |
| 13 | ripetizione | `range` | R4.5 |
| 14 | crittografia | `hmacSha256`, `xor` | R4.5 |
| 15 | richieste nella ricetta | `fetch` | R4.5 |
| 16 | pagina resa | `pages` e `chapterReady` in `browser` | R8.2 |

La pagina resa (P7, poi R8.2) ha preso il 16, il primo libero dopo la ricetta. La ricetta aveva i
numeri 7-12 e li ha lasciati a link canonico, `expect` e `fallback`:
rinumerare è stato sicuro perché il catalogo non era ancora in produzione
(nessuna app pubblicata conosceva un `engine` oltre il 6 e nessuna variante
firmata lo chiedeva). Da quando il catalogo è pubblicato i numeri non
cambiano più.

### Diagnosi

Un `ProviderChanged` dice che il sito ha cambiato forma, non dove. Chi ripara
deve sapere quale campo della definizione è rimasto senza valore, e la
sentinella deve poterlo scrivere in un avviso senza che qualcuno riapra la
pagina. Per questo l'errore porta un **guasto**, `SiteFault`:

| Campo | Cosa |
|---|---|
| `phase` | `search`, `series`, `chapters`, `pages` o `image`: l'operazione in cui il valore mancava. Sempre presente |
| `field` | il percorso del campo nella definizione, dalla radice del file: `series.title`, `series.chapters.items`, `chapter.pages.url`, `chapter.recipe[3]`. Facoltativo |
| `detail` | cosa mancava o cosa è arrivato al suo posto: «elenco vuoto», «atteso un oggetto, arrivata una lista», «due capitoli con id 12». Al più 200 caratteri |
| `url` | l'indirizzo dell'ultima risposta letta prima del guasto. Facoltativo |

Il percorso usa le chiavi del file separate da punto e l'indice fra quadre per
le liste (`first[1]`, `recipe[3]`, contati da 0 come nel JSON), così si ritrova
nel file a colpo d'occhio. Punta al campo che è rimasto vuoto, non
all'alternativa: un `first` fallisce quando falliscono tutte, e il guasto è del
campo.

`detail` può citare ciò che è arrivato (l'inizio di una pagina di verifica, un
messaggio d'errore dell'API) ma non oltre i 200 caratteri in tutto, con gli a
capo ridotti a spazi: il guasto finisce in un avviso e nei log, e il contenuto
di una pagina è un dato, che non deve arrivare intero a chi legge l'avviso, né
a un agente come se fosse un'istruzione. Nell'app `phase` e `field` vanno a
Sentry come tag; `detail` e `url` restano sul telefono (la prova di un file
nella pagina Siti), perché un indirizzo di ricerca contiene ciò che l'utente
ha cercato.

Il guasto è facoltativo su `ProviderChanged` (un errore senza guasto resta
valido) e non è una chiave del formato: nessuna definizione lo scrive, quindi
non chiede un `engine`. Un motore che non lo conosce semplicemente non lo dà.
Lo compilano:

- l'interprete, in ogni punto in cui solleva `ProviderChanged`: campo
  obbligatorio vuoto, elenco vuoto, id doppi, variabile vuota nel percorso di
  un indirizzo, `require`, `expect`, `check` e `switch` della ricetta;
- i provider Dart, almeno con la fase; quando il valore che manca ha un
  equivalente nel formato usano quel percorso (`series.title`), così sonda e
  avvisi parlano la stessa lingua per un sito incluso e per uno del catalogo.

Un errore di rete o di stato HTTP (`ProviderOffline`, `HttpStatusError`) non è
un guasto della definizione e non porta `SiteFault`: chi lo riceve sa già
l'indirizzo e lo stato.

#### Traccia e sito degradato

Durante un'operazione il motore tiene una **traccia**, `SiteTrace`: per ogni
`first`, ogni `try` e ogni blocco con `fallback` quale alternativa ha dato il
valore. La traccia non cambia l'esito; la leggono la
sonda e `tool/site.dart check`, l'app no.

Un sito è **degradato** quando almeno uno di questi punti ha vinto con
un'alternativa che non è la prima. L'elenco si scrive col percorso del campo
che contiene `first` o `try` e il numero dell'alternativa, contato da 1:

```json
"degraded": ["series.title#2", "series.url#2", "series.chapters.title#3"]
```

Un blocco con `fallback` segue la stessa regola: il percorso è quello del
blocco, il principale è l'alternativa 1 e `fallback[i]` è la `i + 2`. Le tavole
lette dalla prima riserva sono `chapter#2`, l'elenco dei capitoli dalla seconda
`series.chapters#3`, la ricerca dalla prima `search#2`. Dentro una riserva i
campi con `first` o `try` hanno il percorso del file
(`chapter.fallback[0].pages.url#2`). `series.chapters.expect` senza numero
dice che il conteggio non c'era ([Conteggio dichiarato](#conteggio-dichiarato)).

Un campo valutato per ogni elemento (capitoli, tavole) compare una volta per
alternativa usata, non una per elemento; l'elenco è ordinato e senza doppioni.
La prima alternativa è la forma che chi ha scritto il file considera
principale: se vince la seconda, la ridondanza ha già assorbito un cambio del
sito e la sonda risponde `ok` ma con `degraded`. È un preavviso: si corregge
prima che cada anche l'ultima alternativa.

### Strategie che resistono

Un sito cambia più spesso l'aspetto che i dati, e una definizione dura di più
quanto più legge da ciò che il sito stesso usa per funzionare.

- **API JSON prima del DOM.** Se la pagina chiede i dati a un'API, la
  definizione chiede la stessa API: i nomi dei campi li usa il codice del sito,
  le classi solo il suo foglio di stile.
- **Dati strutturati come alternative.** `__NEXT_DATA__`, JSON-LD e i meta
  `og:` stanno in quasi ogni pagina per i motori di ricerca, e cambiano poco.
  Nei campi che servono (titolo, copertina, id) si mettono come alternative di
  `first`, dalla fonte più ricca al testo visibile:

  ```json
  "title": {"first": [
    {"css": "script#__NEXT_DATA__", "json": "props.pageProps.manga.title"},
    {"css": "script[type=\"application/ld+json\"]", "json": "name"},
    {"css": "meta[property=\"og:title\"]", "attr": "content"},
    "h1"
  ]}
  ```

- **Niente classi con hash** (`.styles_title__x7Qa2`, `.css-1q2w3e`): cambiano
  a ogni build del sito. Meglio un elemento (`h1`), un attributo con un
  significato (`[itemprop=name]`, `[data-chapter-id]`) o un id.
- **Niente `_next/data/<buildId>/` scritto in un modello.** Il `buildId` cambia
  a ogni pubblicazione del sito; se serve quella strada lo si legge da
  `__NEXT_DATA__` in un `var` e lo si compone.
- **L'identità da una fonte sola.** Ogni alternativa per l'id della serie deve
  dare lo stesso id: una che ne dà un altro è un cambio d'identità silenzioso
  (`docs/malf.md`). Un `require` sull'id lo ferma.

Queste regole le controllerà `tool/site.dart lint`.

### I siti inclusi nel formato 2

Misura sui provider Dart di `packages/kagami_archive/lib/providers/`, per
sapere se le primitive bastano; la parità sulle fixture la provano le voci P5.

- **MangaK** (`engine` 9): `vars` da `__NEXT_DATA__` (`initialManga.id` e
  `cv`), `chapters.api` composto con `query`, elenco `newest-first` dall'API,
  link dei capitoli con `base`, tavole da `initialChapter.pages` della pagina
  del capitolo, `require` sull'id del capitolo, ricerca sull'API con `query`,
  tavole su `rx.qvzr?.org`. Il controllo «elenco più corto di
  `chaptersCount`» del Dart è `expect` su `initialManga.stats.chaptersCount`
  (la sonda ha visto «265/270»: scarto entro il 5%, quindi sito degradato e non
  guasto). Le tavole hanno una riserva sull'API
  `api.mangak.io/titles/{id}/chapters/{chapterId}/images`, trovata con una
  cattura di Reverse API Engineering il 2026-11-16: la pagina del capitolo
  resta il principale, l'API serve quando `__NEXT_DATA__` cambia forma. L'id
  del titolo non sta nel link del capitolo, quindi i capitoli lo tengono con
  `keep` (`titleId`). La risposta è `data.images`, gli indirizzi delle tavole
  in ordine e senza misure. L'elenco dei capitoli si chiede senza `limit`,
  come il Dart: l'API dà tutto, e un taglio lo ferma `expect`.
- **Asura Scans** (`engine` 7): `linkVars` con `replace` per togliere il
  suffisso dallo slug, `try` sull'API della serie, `skip` dei capitoli
  `is_premium` e dei romanzi nella ricerca, titolo con `first` fra due
  `template`, numero con `"number"`, `keep` di `series_slug` e `slug` per l'API
  delle tavole, `require` sull'id e `locked` su `is_locked`.
  `series.link` (`https://asurascans.com/comics/{slug}`) dà il link della
  serie sul sito, mentre `series.url` resta l'API: senza, `Series.url` usciva su
  `api.asurascans.com` e `accepts` lo rifiutava. `chapterKeyOf`/`canonical`
  (lo slug senza suffisso nei link incollati) vengono da `linkVars` e
  `series.link`.
- **ManhwaRead**, percorso principale (`engine` 11): pagina della serie con
  `browser`, titolo e capitoli con `first` fra i contenitori che il Dart prova,
  `keep` di `manga_id` (da `postid-(\d+)` sulla pagina) e `data-id`, tavole
  con la ricetta qui sopra. Restano fuori il ripiego sul CDN quando anche il
  capitolo è dietro Cloudflare (`_probeCdn`: provare `mr_001.jpg`, `mr_002.jpg`…
  finché uno manca è un ciclo che si ferma su un esito, non un `range`), e la
  lettura euristica delle etichette dei metadati (`_labels`), che diventa un
  selettore per campo.

#### Coffee Manga: cosa entra e cosa no

Il manifest delle tavole entra: `hmacSha256` della chiave su
`rk|coffeemanga.net|{chapterId}`, un `range` di blocchi (`(len(cipher)+31)/32`)
che concatena `hmacSha256` su `ks|{b}`, `xor` col cifrato letto con `base64`
`url`, `json`; poi i controlli su `e`, `q`, `p` (`check`), la richiesta che il
manifest indica (`fetch`, con nomi dei parametri presi dal manifest), la busta
scelta da `v / 3` e la decodifica da `v % 3` (`intExpr`, `when`, `switch`,
`base64`, `hex` e `xor` con la chiave che si ripete). Fa una trentina di passi,
`engine` 15.

Non entra la **chiave**. Il Dart la ricava dal bundle JavaScript del sito
(`coffeeMangaKey`): cerca `TE()` con nomi che il minificatore cambia, valuta
32 espressioni con indici in un array definito altrove nel bundle e
`charCodeAt` su `HTML`, e il bundle pesa fino a 8 MB. Mancherebbero tre cose,
tutte escluse di proposito: valutare espressioni lette dalla pagina invece che
scritte nel file, espressioni regolari composte da valori letti, e risposte
oltre i 2 MB. Le vie restano due: la chiave scritta nel file come costante,
da ripubblicare nel catalogo ogni volta che il sito cambia bundle (la
sentinella lo vede come `changed`, perché il manifest non si decifra più),
oppure il provider Dart, che la ricava da solo.

Decisi in R8.1: `catalog/sites/coffeemanga.json` è la variante a chiave
costante (`hex` col valore nel primo passo della ricetta, 31 passi su 32), e il
provider Dart resta incluso, ripiego quando la costante invecchia. La chiave la
ricava `tool/site.dart coffeemanga-key` col codice del Dart
([manutenzione-siti.md](manutenzione-siti.md)). Le differenze dal Dart:

- **Capitoli da `/manga/{id}/chapters.json`**, l'elenco intero in una
  richiesta, invece della prima pagina più `chapters/N.json` (20 per pagina:
  una serie di 231 capitoli ne vuole 12, oltre le 8 richieste e senza un
  ciclo nel formato). Quel JSON non ha `url`, `number` né la data: il link si
  compone dallo slug, il numero si legge dal titolo come fa il Dart quando
  manca, la data di pubblicazione (`publishedAt` del capitolo) si perde. Il
  totale della pagina è `expect`, con la tolleranza del 5% invece del
  controllo esatto del Dart.
- **La risposta del manifest si legge come testo** e ogni campo con
  `jsonAt: "^"`: un `var` su una lista ne scorre gli elementi, quindi la busta
  a lista (`v / 3 == 1`) non si indicizzerebbe con `[2]`. La busta e il
  controllo dell'id (`c`) passano da `when` e `switch` su `v / 3`, non da
  `first`, che segnerebbe il sito degradato per ogni capitolo.
- **La tavola**: una sola espressione su `srcset` prende la voce `raw:1` o,
  senza, l'ultima (il sito le ordina per larghezza; il Dart prende la più
  larga), poi `src`. Il controllo `n == indice + 1` del Dart non c'è; il
  numero di tavole uguale a `total` sì (`intExpr`).
- Metadati: gli autori scritti come testo (non `{name}`), il voto e l'anno
  non ci sono.

## Installare, aggiornare, togliere## Installare, aggiornare, togliere

Dall'app, in **Impostazioni → Scarica un manga → Siti**: un link al file o il
testo incollato. Prima di installare l'app mostra nome, versione, host a cui il
sito chiederà le pagine e se sostituisce un sito incluso, e prova il file: una
ricerca o il link di una serie, a scelta di chi installa.

Un sito con `update` si ricontrolla al più una volta al giorno all'apertura della
pagina dei siti e del giro del telefono; il server lo rilegge dalla cartella a
ogni giro, quindi segue il telefono. Un file che non si legge o non è valido
lascia installato quello di prima (adozione, non sovrascrittura). Togliere un
sito cancella solo il suo file: le serie restano in libreria, senza
aggiornamenti finché il sito non torna.

## Sul server

Il server legge `providers/` dalla cartella di Drive di ogni account all'inizio
di ogni giro e di ogni controllo, e usa quei siti **solo per quell'account**: due
account possono avere file diversi con lo stesso `id`. Lo dichiara con la
funzione `userProviders` di `/v2/server` (`docs/server-api.md`); un server che
non la elenca non sa scaricare dai siti degli utenti e l'app quei lavori li tiene
sul telefono.
