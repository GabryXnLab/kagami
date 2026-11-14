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

| Campo | Obbligatorio | Cosa |
|---|---|---|
| `format` | sì | `1`. Un file con un `format` che il motore non conosce non si installa. |
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
  `width` e `height`. Ogni tavola è un link su `hosts` o `mediaHosts`; un
  capitolo senza tavole è un `ProviderChanged`.
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

Non si possono descrivere i siti che cifrano le tavole con codice proprio
(come Coffee Manga dal 2026-10-28): per quelli servirebbe un interprete, cioè
codice nel file, ed è escluso di proposito.

## Installare, aggiornare, togliere

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
