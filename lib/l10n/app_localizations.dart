import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('ja'),
    Locale('pt'),
    Locale('zh'),
  ];

  /// Voce delle impostazioni che apre la scelta della lingua dell'interfaccia
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get settingsLanguage;

  /// Scelta della lingua: segue quella del telefono
  ///
  /// In it, this message translates to:
  /// **'Come il sistema'**
  String get settingsLanguageSystem;

  /// Stato di lettura di una serie: nessuno scelto
  ///
  /// In it, this message translates to:
  /// **'Nessuno stato'**
  String get seriesShelfNone;

  /// Stato di lettura di una serie: in programma, non ancora cominciata
  ///
  /// In it, this message translates to:
  /// **'Da leggere'**
  String get seriesShelfPlanned;

  /// Stato di lettura di una serie: la sto leggendo
  ///
  /// In it, this message translates to:
  /// **'In lettura'**
  String get seriesShelfReading;

  /// Stato di lettura di una serie: lettura sospesa dall'utente
  ///
  /// In it, this message translates to:
  /// **'In pausa'**
  String get seriesShelfPaused;

  /// Stato di lettura di una serie: l'utente l'ha finita
  ///
  /// In it, this message translates to:
  /// **'Finito'**
  String get seriesShelfCompleted;

  /// Stato di lettura di una serie: l'utente ha smesso di leggerla
  ///
  /// In it, this message translates to:
  /// **'Abbandonato'**
  String get seriesShelfDropped;

  /// Stato di pubblicazione della serie: escono ancora capitoli
  ///
  /// In it, this message translates to:
  /// **'In corso'**
  String get seriesReleaseOngoing;

  /// Stato di pubblicazione della serie: terminata dall'autore
  ///
  /// In it, this message translates to:
  /// **'Conclusa'**
  String get seriesReleaseCompleted;

  /// Stato di pubblicazione della serie: sospesa dagli autori (hiatus)
  ///
  /// In it, this message translates to:
  /// **'In pausa'**
  String get seriesReleaseHiatus;

  /// Stato di pubblicazione della serie: cancellata, non uscirà altro
  ///
  /// In it, this message translates to:
  /// **'Interrotta'**
  String get seriesReleaseCancelled;

  /// Stato di pubblicazione della serie: non noto
  ///
  /// In it, this message translates to:
  /// **'Stato ignoto'**
  String get seriesReleaseUnknown;

  /// Schermata della scheda quando la serie non esiste più nella libreria
  ///
  /// In it, this message translates to:
  /// **'Serie non trovata.'**
  String get seriesNotFound;

  /// Titolo dell'avviso sulla scheda quando non c'è rete e l'elenco dei capitoli sta su Google Drive
  ///
  /// In it, this message translates to:
  /// **'Capitoli su Drive'**
  String get seriesOfflineTitle;

  /// Avviso sulla scheda senza rete: l'elenco dei capitoli non è disponibile
  ///
  /// In it, this message translates to:
  /// **'Senza connessione non si vede l\'elenco dei capitoli di questa serie. Compare da solo appena torna la rete.'**
  String get seriesOfflineMessage;

  /// Titolo dell'avviso quando la serie non ha il file index.json
  ///
  /// In it, this message translates to:
  /// **'Nessun indice'**
  String get seriesNoIndexTitle;

  /// Avviso quando manca index.json: rimanda al programma che ha creato la libreria
  ///
  /// In it, this message translates to:
  /// **'Questa serie non ha un index.json: vanno rigenerati gli indici con l\'archiviatore che l\'ha scritta.'**
  String get seriesNoIndexMessage;

  /// Titolo dello stato vuoto dell'elenco capitoli quando i filtri escludono tutto
  ///
  /// In it, this message translates to:
  /// **'Nessun capitolo'**
  String get seriesNoChaptersTitle;

  /// Stato vuoto dell'elenco capitoli: nessun capitolo corrisponde a ricerca e filtri
  ///
  /// In it, this message translates to:
  /// **'Nessuno passa la ricerca e i filtri scelti.'**
  String get seriesNoChaptersMessage;

  /// Titolo del foglio di conferma per scaricare da Drive sul telefono i capitoli indicati
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Scaricare un capitolo?} other{Scaricare {count} capitoli?}}'**
  String seriesDownloadAllTitle(int count);

  /// Testo del foglio di conferma del download di tutti i capitoli da Drive
  ///
  /// In it, this message translates to:
  /// **'Tutti i capitoli che ora si leggono da Drive finiscono sul telefono, e da lì si leggono anche senza rete.'**
  String get seriesDownloadAllMessage;

  /// Pulsante di conferma del download dei capitoli sul telefono
  ///
  /// In it, this message translates to:
  /// **'Scarica'**
  String get seriesDownload;

  /// Riga sopra l'elenco capitoli: capitoli già letti che stanno ancora su Google Drive e si possono togliere
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Un capitolo letto è ancora su Drive} other{{count} capitoli letti sono ancora su Drive}}'**
  String seriesCleanupRemote(int count);

  /// Riga sopra l'elenco capitoli: capitoli già letti che occupano spazio sul telefono; size è già formattata (es. 12 MB)
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Un capitolo letto occupa {size}} other{{count} capitoli letti occupano {size}}}'**
  String seriesCleanupLocal(int count, String size);

  /// Descrizione del pulsante su un capitolo il cui download è fallito; toccandolo si riprova
  ///
  /// In it, this message translates to:
  /// **'Download non riuscito: {error}. Riprova'**
  String seriesDownloadFailed(String error);

  /// Descrizione del pulsante su un capitolo in attesa di rete; toccandolo si annulla il download
  ///
  /// In it, this message translates to:
  /// **'In attesa della rete: riparte da solo. Annulla'**
  String get seriesDownloadWaiting;

  /// Descrizione del pulsante su un capitolo in coda di download; toccandolo si annulla
  ///
  /// In it, this message translates to:
  /// **'In coda. Annulla'**
  String get seriesDownloadQueued;

  /// Descrizione del pulsante su un capitolo in scaricamento; toccandolo si annulla
  ///
  /// In it, this message translates to:
  /// **'Annulla il download'**
  String get seriesDownloadCancel;

  /// Pastiglia della scheda: la serie sta solo nella memoria del telefono
  ///
  /// In it, this message translates to:
  /// **'Sul telefono'**
  String get seriesPlaceLocal;

  /// Dove sta la serie o il capitolo: solo su Google Drive
  ///
  /// In it, this message translates to:
  /// **'Su Drive'**
  String get seriesPlaceDrive;

  /// Pastiglia della scheda: la serie sta in parte sul telefono e in parte su Drive
  ///
  /// In it, this message translates to:
  /// **'Telefono e Drive'**
  String get seriesPlaceMixed;

  /// Descrizione del pulsante a forma di campana sulla copertina quando la serie è silenziata
  ///
  /// In it, this message translates to:
  /// **'Notifiche dei capitoli nuovi silenziate'**
  String get seriesMuteTooltipOn;

  /// Descrizione del pulsante a forma di campana sulla copertina quando le notifiche sono attive
  ///
  /// In it, this message translates to:
  /// **'Notifiche dei capitoli nuovi attive'**
  String get seriesMuteTooltipOff;

  /// Messaggio temporaneo dopo aver riattivato le notifiche dei capitoli nuovi di una serie
  ///
  /// In it, this message translates to:
  /// **'Notifiche dei capitoli nuovi riattivate.'**
  String get seriesMuteUnmuted;

  /// Messaggio temporaneo dopo aver silenziato le notifiche dei capitoli nuovi di una serie
  ///
  /// In it, this message translates to:
  /// **'Notifiche dei capitoli nuovi silenziate.'**
  String get seriesMuteMuted;

  /// Riquadro di ripresa: tutto ciò che è sul telefono è letto, ma alcuni capitoli annunciati non sono stati scaricati
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{In pari con quello che c\'è sul telefono: manca un capitolo annunciato.} other{In pari con quello che c\'è sul telefono: mancano {count} capitoli annunciati.}}'**
  String seriesCaughtUpMissing(int count);

  /// Riquadro di ripresa: la serie è stata letta per intero
  ///
  /// In it, this message translates to:
  /// **'Letta tutta.'**
  String get seriesCaughtUpAll;

  /// Etichetta in maiuscolo del riquadro di ripresa: la serie è cominciata e il prossimo capitolo è da leggere
  ///
  /// In it, this message translates to:
  /// **'DA CONTINUARE'**
  String get seriesResumeToContinue;

  /// Etichetta in maiuscolo del riquadro di ripresa: la serie non è ancora cominciata
  ///
  /// In it, this message translates to:
  /// **'DA INIZIARE'**
  String get seriesResumeToStart;

  /// Etichetta in maiuscolo del riquadro di ripresa: un capitolo è stato lasciato a metà
  ///
  /// In it, this message translates to:
  /// **'LASCIATO A METÀ'**
  String get seriesResumeHalfway;

  /// Riga sotto la barra di avanzamento del capitolo lasciato a metà
  ///
  /// In it, this message translates to:
  /// **'pagina {page} di {total}'**
  String seriesResumePage(int page, int total);

  /// Pulsante della scheda: prosegue la lettura col capitolo successivo
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get seriesContinue;

  /// Pulsante della scheda: comincia a leggere la serie
  ///
  /// In it, this message translates to:
  /// **'Inizia'**
  String get seriesStart;

  /// Pulsante della scheda: riprende il capitolo lasciato a metà
  ///
  /// In it, this message translates to:
  /// **'Riprendi'**
  String get seriesResume;

  /// Descrizione del pulsante che salta al capitolo dopo quello proposto
  ///
  /// In it, this message translates to:
  /// **'Capitolo successivo'**
  String get seriesNextChapter;

  /// Numero in evidenza sulla scheda: quanti capitoli ha la serie
  ///
  /// In it, this message translates to:
  /// **'Capitoli'**
  String get seriesFigureChapters;

  /// Numero in evidenza sulla scheda: quanti capitoli sono stati letti
  ///
  /// In it, this message translates to:
  /// **'Letti'**
  String get seriesFigureRead;

  /// Numero in evidenza sulla scheda: percentuale di lettura
  ///
  /// In it, this message translates to:
  /// **'Avanzamento'**
  String get seriesFigureProgress;

  /// Numero in evidenza sulla scheda: voto dato alla serie
  ///
  /// In it, this message translates to:
  /// **'Voto'**
  String get seriesFigureRating;

  /// Titolo della sezione con stato, preferito, voto, raccolte e note della serie
  ///
  /// In it, this message translates to:
  /// **'Il mio scaffale'**
  String get seriesMyShelf;

  /// Pulsante della scheda quando la serie è già fra i preferiti
  ///
  /// In it, this message translates to:
  /// **'Preferita'**
  String get seriesFavoriteOn;

  /// Pulsante della scheda per aggiungere la serie ai preferiti
  ///
  /// In it, this message translates to:
  /// **'Preferiti'**
  String get seriesFavoriteOff;

  /// Pulsante della scheda che apre la scelta del voto, quando non ce n'è uno
  ///
  /// In it, this message translates to:
  /// **'Voto'**
  String get seriesRatingButton;

  /// Pulsante della scheda col voto dato, su dieci
  ///
  /// In it, this message translates to:
  /// **'{rating}/10'**
  String seriesRatingOutOfTen(int rating);

  /// Descrizione del pulsante che aggiunge la serie a delle raccolte
  ///
  /// In it, this message translates to:
  /// **'Raccolte'**
  String get seriesCollections;

  /// Note personali sulla serie: descrizione del pulsante e titolo del foglio
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get seriesNotes;

  /// Titolo del foglio di scelta del voto
  ///
  /// In it, this message translates to:
  /// **'Che voto le dai?'**
  String get seriesRatingSheetTitle;

  /// Testo suggerito nel campo delle note personali
  ///
  /// In it, this message translates to:
  /// **'Dove eri rimasto, cosa ne pensi…'**
  String get seriesNotesHint;

  /// Pulsante che salva le note
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get seriesSave;

  /// Parola che descrive il voto 1 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Pessimo'**
  String get seriesRatingWord1;

  /// Parola che descrive il voto 2 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Brutto'**
  String get seriesRatingWord2;

  /// Parola che descrive il voto 3 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Scarso'**
  String get seriesRatingWord3;

  /// Parola che descrive il voto 4 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Mediocre'**
  String get seriesRatingWord4;

  /// Parola che descrive il voto 5 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Sufficiente'**
  String get seriesRatingWord5;

  /// Parola che descrive il voto 6 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Discreto'**
  String get seriesRatingWord6;

  /// Parola che descrive il voto 7 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Buono'**
  String get seriesRatingWord7;

  /// Parola che descrive il voto 8 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Ottimo'**
  String get seriesRatingWord8;

  /// Parola che descrive il voto 9 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Eccellente'**
  String get seriesRatingWord9;

  /// Parola che descrive il voto 10 su 10 nel foglio del voto (1 pessimo, 10 capolavoro)
  ///
  /// In it, this message translates to:
  /// **'Capolavoro'**
  String get seriesRatingWord10;

  /// Foglio del voto: nessun voto scelto
  ///
  /// In it, this message translates to:
  /// **'Senza voto'**
  String get seriesRatingNone;

  /// Suggerimento sotto la fila delle dieci celle del voto
  ///
  /// In it, this message translates to:
  /// **'Tocca o scorri'**
  String get seriesRatingHint;

  /// Foglio del voto: il voto che la serie aveva prima della modifica
  ///
  /// In it, this message translates to:
  /// **'Prima: {rating}'**
  String seriesRatingBefore(int rating);

  /// Pulsante del foglio del voto: toglie il voto dato alla serie
  ///
  /// In it, this message translates to:
  /// **'Togli'**
  String get seriesRatingRemove;

  /// Pulsante del foglio del voto: conferma il voto scelto
  ///
  /// In it, this message translates to:
  /// **'Salva il voto'**
  String get seriesRatingSave;

  /// Titolo della sezione con la trama della serie
  ///
  /// In it, this message translates to:
  /// **'Sinossi'**
  String get seriesSynopsis;

  /// Titolo della sezione con i generi della serie
  ///
  /// In it, this message translates to:
  /// **'Generi'**
  String get seriesGenres;

  /// Titolo della sezione con le etichette (tag) della serie
  ///
  /// In it, this message translates to:
  /// **'Tag'**
  String get seriesTags;

  /// Titolo della sezione con autori e disegnatori della serie
  ///
  /// In it, this message translates to:
  /// **'Chi l\'ha fatta'**
  String get seriesCreators;

  /// Pastiglia che mostra gli altri tag nascosti; count è quanti sono
  ///
  /// In it, this message translates to:
  /// **'Altri {count}'**
  String seriesMoreTags(int count);

  /// Titolo della scheda con il tempo stimato per leggere i capitoli non letti
  ///
  /// In it, this message translates to:
  /// **'Da leggere'**
  String get seriesPaceToRead;

  /// Sotto il tempo stimato di lettura: quanti capitoli e quante tavole restano; le tavole sono le pagine del manga
  ///
  /// In it, this message translates to:
  /// **'{chapters, plural, =1{un capitolo} other{{chapters} capitoli}}, {pages, plural, =1{una tavola} other{{pages} tavole}}'**
  String seriesPaceCaption(int chapters, int pages);

  /// Titolo della scheda con la data attesa del prossimo capitolo
  ///
  /// In it, this message translates to:
  /// **'Prossimo capitolo'**
  String get seriesPaceNext;

  /// Sotto la data attesa: spiega che è una stima dalla cadenza di uscita degli ultimi capitoli
  ///
  /// In it, this message translates to:
  /// **'dalla cadenza degli ultimi'**
  String get seriesPaceNextCaption;

  /// Durata stimata di lettura, in minuti
  ///
  /// In it, this message translates to:
  /// **'{count} min'**
  String seriesDurationMinutes(int count);

  /// Durata stimata di lettura, in ore
  ///
  /// In it, this message translates to:
  /// **'{count} h'**
  String seriesDurationHours(int count);

  /// Durata stimata di lettura, in giorni
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 giorno} other{{count} giorni}}'**
  String seriesDurationDays(int count);

  /// Data attesa del prossimo capitolo: da più di due settimane
  ///
  /// In it, this message translates to:
  /// **'in ritardo'**
  String get seriesWhenLate;

  /// Data attesa del prossimo capitolo: dovrebbe essere già uscito
  ///
  /// In it, this message translates to:
  /// **'atteso'**
  String get seriesWhenExpected;

  /// Data attesa del prossimo capitolo: oggi
  ///
  /// In it, this message translates to:
  /// **'oggi'**
  String get seriesWhenToday;

  /// Data attesa del prossimo capitolo: domani
  ///
  /// In it, this message translates to:
  /// **'domani'**
  String get seriesWhenTomorrow;

  /// Data attesa del prossimo capitolo, in giorni
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{fra 1 giorno} other{fra {count} giorni}}'**
  String seriesWhenInDays(int count);

  /// Data attesa del prossimo capitolo, in settimane
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{fra 1 settimana} other{fra {count} settimane}}'**
  String seriesWhenInWeeks(int count);

  /// Pulsante che richiude la sinossi lunga
  ///
  /// In it, this message translates to:
  /// **'Riduci'**
  String get seriesShowLess;

  /// Pulsante che espande la sinossi troncata
  ///
  /// In it, this message translates to:
  /// **'Leggi tutto'**
  String get seriesShowMore;

  /// Titolo della sezione con l'elenco dei capitoli
  ///
  /// In it, this message translates to:
  /// **'Capitoli'**
  String get seriesChaptersTitle;

  /// Accanto al titolo Capitoli: quanti ne ha la serie in tutto, quando alcuni non sono scaricati
  ///
  /// In it, this message translates to:
  /// **'su {total}'**
  String seriesChaptersOf(int total);

  /// Testo suggerito nel campo di ricerca dei capitoli
  ///
  /// In it, this message translates to:
  /// **'Cerca capitolo…'**
  String get seriesSearchChapter;

  /// Descrizione del pulsante di ordinamento: ora i capitoli vanno dal più recente
  ///
  /// In it, this message translates to:
  /// **'Dal più recente'**
  String get seriesSortNewest;

  /// Descrizione del pulsante di ordinamento: ora i capitoli vanno dal primo
  ///
  /// In it, this message translates to:
  /// **'Dal primo'**
  String get seriesSortOldest;

  /// Descrizione del pulsante che segna tutti i capitoli come letti (o da leggere)
  ///
  /// In it, this message translates to:
  /// **'Segna tutti'**
  String get seriesMarkAll;

  /// Descrizione del pulsante che scarica da Google Drive sul telefono i capitoli
  ///
  /// In it, this message translates to:
  /// **'Scarica da Drive'**
  String get seriesDownloadFromDrive;

  /// Azione accanto alla riga dei capitoli letti: apre il foglio per toglierli dal telefono
  ///
  /// In it, this message translates to:
  /// **'Libera spazio'**
  String get seriesFreeSpace;

  /// Filtro dell'elenco capitoli: solo quelli non letti
  ///
  /// In it, this message translates to:
  /// **'Da leggere'**
  String get seriesFilterUnread;

  /// Filtro dell'elenco capitoli: solo quelli sul telefono
  ///
  /// In it, this message translates to:
  /// **'Scaricati'**
  String get seriesFilterDownloaded;

  /// Filtro dell'elenco capitoli: tutti i blocchi di capitoli, senza salto
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get seriesFilterAll;

  /// Barra in basso: quanti capitoli sono selezionati
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 selezionato} other{{count} selezionati}}'**
  String seriesSelectedCount(int count);

  /// Descrizione del pulsante che segna i capitoli selezionati come letti
  ///
  /// In it, this message translates to:
  /// **'Segna letti'**
  String get seriesMarkReadMany;

  /// Descrizione del pulsante che segna un capitolo (o i selezionati) come da leggere
  ///
  /// In it, this message translates to:
  /// **'Segna da leggere'**
  String get seriesMarkUnread;

  /// Descrizione del pulsante che segna un capitolo come letto
  ///
  /// In it, this message translates to:
  /// **'Segna letto'**
  String get seriesMarkRead;

  /// Descrizione del pulsante che segna letti tutti i capitoli fino al più recente selezionato
  ///
  /// In it, this message translates to:
  /// **'Segna letto fino a qui'**
  String get seriesMarkReadThrough;

  /// Titolo della sezione con serie simili per generi e tag
  ///
  /// In it, this message translates to:
  /// **'Altre così'**
  String get seriesSimilar;

  /// Riga sotto il titolo di un capitolo annunciato ma non scaricato
  ///
  /// In it, this message translates to:
  /// **'Non scaricato'**
  String get seriesChapterNotDownloaded;

  /// Riga sotto il titolo di un capitolo: numero di pagine (tavole)
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 tavola} other{{count} tavole}}'**
  String seriesChapterPages(int count);

  /// Descrizione del pulsante che scarica un capitolo da Drive sul telefono
  ///
  /// In it, this message translates to:
  /// **'Scarica sul telefono'**
  String get seriesDownloadToPhone;

  /// Messaggio a schermo intero nel lettore quando la serie non esiste più.
  ///
  /// In it, this message translates to:
  /// **'Serie non disponibile.'**
  String get readerSeriesUnavailable;

  /// Messaggio nel lettore: manca il file pages.json (nome di file, da non tradurre) con l'elenco delle tavole.
  ///
  /// In it, this message translates to:
  /// **'Questa serie non ha un pages.json: vanno rigenerati gli indici con l\'archiviatore che l\'ha scritta.'**
  String get readerNoPagesIndex;

  /// Messaggio nel lettore: niente rete e l'elenco delle tavole della serie è solo su Google Drive.
  ///
  /// In it, this message translates to:
  /// **'Senza connessione non si può aprire questa serie: l\'elenco delle sue tavole è su Drive. Si apre appena torna la rete.'**
  String get readerSeriesOffline;

  /// Messaggio nel lettore: il capitolo richiesto non è presente sul dispositivo.
  ///
  /// In it, this message translates to:
  /// **'Questo capitolo non è ancora sul telefono. La sincronizzazione può essere a metà: riprovare più tardi.'**
  String get readerChapterNotOnPhone;

  /// Messaggio nel lettore: il capitolo non contiene pagine.
  ///
  /// In it, this message translates to:
  /// **'Il capitolo non ha pagine leggibili.'**
  String get readerChapterNoPages;

  /// Messaggio nel lettore: l'indice elenca le tavole ma i file immagine non sono ancora arrivati sul dispositivo.
  ///
  /// In it, this message translates to:
  /// **'Le tavole di questo capitolo non sono ancora sul telefono. L\'indice le annuncia, i file no: è la cartella sincronizzata a doverli portare.'**
  String get readerPagesNotOnPhone;

  /// Titolo del foglio mostrato a fine capitolo: chiede se segnare come letti i capitoli precedenti ancora da leggere.
  ///
  /// In it, this message translates to:
  /// **'Segnare letti i precedenti?'**
  String get readerMarkEarlierTitle;

  /// Testo del foglio che chiede se segnare letti i capitoli precedenti; {chapter} è il nome del capitolo appena finito, {count} quanti precedenti sono ancora da leggere.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Hai finito {chapter}. Il capitolo precedente risulta ancora da leggere: se l\'hai già letto altrove, segnalo letto.} other{Hai finito {chapter}. I {count} capitoli precedenti risultano ancora da leggere: se li hai già letti altrove, segnali letti tutti insieme.}}'**
  String readerMarkEarlierBody(int count, String chapter);

  /// Pulsante di conferma nel foglio dei capitoli precedenti: segna come letti {count} capitoli.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Segna letto il precedente} other{Segna letti tutti i {count}}}'**
  String readerMarkEarlierConfirm(int count);

  /// Pulsante nel foglio dei capitoli precedenti: non segnarli come letti.
  ///
  /// In it, this message translates to:
  /// **'Lasciali da leggere'**
  String get readerMarkEarlierDecline;

  /// Avviso breve dopo aver salvato un segnalibro; {page} è il numero della pagina.
  ///
  /// In it, this message translates to:
  /// **'Pagina {page} messa da parte'**
  String readerBookmarkAdded(int page);

  /// Titolo del foglio con l'elenco dei capitoli dentro il lettore.
  ///
  /// In it, this message translates to:
  /// **'Capitoli'**
  String get readerChapters;

  /// Titolo del foglio dei segnalibri e tooltip del pulsante che lo apre (pagine salvate dall'utente).
  ///
  /// In it, this message translates to:
  /// **'Pagine messe da parte'**
  String get readerBookmarks;

  /// Titolo dello stato vuoto del foglio dei segnalibri.
  ///
  /// In it, this message translates to:
  /// **'Nessuna pagina da parte'**
  String get readerNoBookmarks;

  /// Spiegazione nello stato vuoto dei segnalibri: il segnalibro salva una pagina precisa, mentre il punto di lettura del capitolo è già ricordato.
  ///
  /// In it, this message translates to:
  /// **'Il segnalibro tiene il punto di una tavola; quello del capitolo lo tiene già la ripresa.'**
  String get readerNoBookmarksHint;

  /// Sottotitolo di un segnalibro nell'elenco; {page} è il numero della pagina.
  ///
  /// In it, this message translates to:
  /// **'pagina {page}'**
  String readerBookmarkPage(int page);

  /// Tooltip del pulsante cestino che rimuove un segnalibro.
  ///
  /// In it, this message translates to:
  /// **'Togli'**
  String get readerBookmarkRemove;

  /// Tooltip del pulsante che riporta all'inizio del capitolo.
  ///
  /// In it, this message translates to:
  /// **'Torna in cima'**
  String get readerToTop;

  /// Motivo mostrato al posto di una tavola di Google Drive che non si è scaricata.
  ///
  /// In it, this message translates to:
  /// **'Tavola non arrivata da Drive'**
  String get readerPageNotFromDrive;

  /// Motivo mostrato al posto di una tavola: il file c'è ma non si riesce ad aprire.
  ///
  /// In it, this message translates to:
  /// **'Tavola illeggibile'**
  String get readerPageUnreadable;

  /// Motivo mostrato al posto di una tavola: il file non è ancora arrivato sul dispositivo.
  ///
  /// In it, this message translates to:
  /// **'Tavola non sincronizzata'**
  String get readerPageNotSynced;

  /// Titolo dell'avviso su una tavola di Drive mancante per assenza di rete.
  ///
  /// In it, this message translates to:
  /// **'Tavola non ancora scaricata'**
  String get readerPageNotDownloaded;

  /// Sottotitolo dell'avviso su una tavola mancante per assenza di rete.
  ///
  /// In it, this message translates to:
  /// **'Senza connessione. Arriva da sola appena torna la rete.'**
  String get readerPageOfflineHint;

  /// Pulsante che riprova subito a scaricare una tavola mancante.
  ///
  /// In it, this message translates to:
  /// **'Riprova ora'**
  String get readerRetryNow;

  /// Fondo del capitolo quando non ce ne sono altri disponibili sul dispositivo.
  ///
  /// In it, this message translates to:
  /// **'È l\'ultimo capitolo che c\'è sul telefono.'**
  String get readerLastChapterOnPhone;

  /// Piccola etichetta in fondo al capitolo sopra il pulsante che porta al successivo.
  ///
  /// In it, this message translates to:
  /// **'Capitolo seguente'**
  String get readerNextChapter;

  /// Pulsante in fondo al capitolo per passare al successivo, se manca il nome del capitolo.
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get readerContinue;

  /// Tooltip del pulsante che salva un segnalibro sulla pagina corrente.
  ///
  /// In it, this message translates to:
  /// **'Metti da parte questa pagina'**
  String get readerBookmarkThisPage;

  /// Tooltip del pulsante e titolo del foglio con le impostazioni di lettura.
  ///
  /// In it, this message translates to:
  /// **'Come si legge'**
  String get readerHowToRead;

  /// Tooltip della freccia che porta al capitolo precedente.
  ///
  /// In it, this message translates to:
  /// **'Capitolo precedente'**
  String get readerPreviousChapter;

  /// Tooltip della freccia che porta al capitolo successivo.
  ///
  /// In it, this message translates to:
  /// **'Capitolo successivo'**
  String get readerNextChapterTooltip;

  /// Segnaposto del campo di ricerca nell'elenco dei capitoli.
  ///
  /// In it, this message translates to:
  /// **'Cerca capitolo…'**
  String get readerSearchChapter;

  /// Tooltip del pulsante di ordinamento dei capitoli: ora sono dal più recente.
  ///
  /// In it, this message translates to:
  /// **'Dal più recente'**
  String get readerNewestFirst;

  /// Tooltip del pulsante di ordinamento dei capitoli: ora sono dal primo (il più vecchio).
  ///
  /// In it, this message translates to:
  /// **'Dal primo'**
  String get readerOldestFirst;

  /// Riga in fondo all'elenco dei capitoli: {current} è il numero del capitolo in lettura (mostrato con uno stile a parte), {total} quanti sono.
  ///
  /// In it, this message translates to:
  /// **'In lettura: {current} / {total} capitoli'**
  String readerReadingNow(String current, int total);

  /// Titolo di sezione nelle impostazioni di lettura.
  ///
  /// In it, this message translates to:
  /// **'Modalità di lettura'**
  String get readerMode;

  /// Opzione della modalità di lettura: scorrimento verticale continuo.
  ///
  /// In it, this message translates to:
  /// **'Striscia'**
  String get readerModeStrip;

  /// Opzione della modalità di lettura: una tavola per volta.
  ///
  /// In it, this message translates to:
  /// **'Pagina'**
  String get readerModePage;

  /// Titolo di sezione: direzione in cui si sfogliano le pagine.
  ///
  /// In it, this message translates to:
  /// **'Verso di lettura'**
  String get readerDirection;

  /// Opzione del verso di lettura.
  ///
  /// In it, this message translates to:
  /// **'Sinistra → destra'**
  String get readerDirectionLtr;

  /// Opzione del verso di lettura (stile manga giapponese).
  ///
  /// In it, this message translates to:
  /// **'Destra → sinistra'**
  String get readerDirectionRtl;

  /// Titolo di sezione: come la tavola si adatta allo schermo.
  ///
  /// In it, this message translates to:
  /// **'Adattamento'**
  String get readerFit;

  /// Titolo di sezione: colore dello sfondo del lettore.
  ///
  /// In it, this message translates to:
  /// **'Sfondo'**
  String get readerBackground;

  /// Titolo di sezione: luminosità dello schermo nel lettore.
  ///
  /// In it, this message translates to:
  /// **'Luminosità'**
  String get readerBrightness;

  /// Titolo di sezione: scorrimento automatico della striscia.
  ///
  /// In it, this message translates to:
  /// **'Scorrimento automatico'**
  String get readerAutoScroll;

  /// Valore dello scorrimento automatico quando è disattivato.
  ///
  /// In it, this message translates to:
  /// **'spento'**
  String get readerAutoScrollOff;

  /// Velocità dello scorrimento automatico, in tavole al minuto.
  ///
  /// In it, this message translates to:
  /// **'{rate} tavole/min'**
  String readerAutoScrollRate(int rate);

  /// Interruttore: mostra il numero della pagina sopra la tavola.
  ///
  /// In it, this message translates to:
  /// **'Numero di pagina'**
  String get readerShowPageNumber;

  /// Interruttore: mostra la sottile barra di avanzamento in fondo allo schermo.
  ///
  /// In it, this message translates to:
  /// **'Barra di avanzamento'**
  String get readerShowProgress;

  /// Interruttore: mostra il pulsante che riporta all'inizio del capitolo.
  ///
  /// In it, this message translates to:
  /// **'Pulsante per tornare in cima'**
  String get readerShowScrollTop;

  /// Interruttore: impedisce allo schermo di spegnersi durante la lettura.
  ///
  /// In it, this message translates to:
  /// **'Tieni acceso lo schermo'**
  String get readerKeepAwake;

  /// Interruttore: nella modalità a pagine mostra due tavole una accanto all'altra.
  ///
  /// In it, this message translates to:
  /// **'Due tavole affiancate'**
  String get readerDoublePage;

  /// Interruttore: blocca la rotazione dello schermo.
  ///
  /// In it, this message translates to:
  /// **'Blocca la rotazione'**
  String get readerLockRotation;

  /// Titolo della schermata per archiviare una serie dal sito (Impostazioni → Scarica un manga)
  ///
  /// In it, this message translates to:
  /// **'Scarica un manga'**
  String get archiveTitle;

  /// Testo introduttivo in cima alla schermata di download
  ///
  /// In it, this message translates to:
  /// **'Cerca un titolo sui siti supportati, o incolla il link di una serie: Kagami la scarica dal sito, con metadati, copertina e l\'elenco completo dei capitoli, nella libreria.'**
  String get archiveIntro;

  /// Suggerimento nel campo di ricerca per titolo
  ///
  /// In it, this message translates to:
  /// **'Cerca un manga per titolo'**
  String get archiveSearchHint;

  /// Tooltip del pulsante che svuota il campo di ricerca
  ///
  /// In it, this message translates to:
  /// **'Cancella'**
  String get archiveClear;

  /// Tooltip del pulsante che incolla il link dagli appunti
  ///
  /// In it, this message translates to:
  /// **'Incolla'**
  String get archivePaste;

  /// Etichetta del pulsante mentre la pagina della serie viene letta dal sito
  ///
  /// In it, this message translates to:
  /// **'Lettura della serie…'**
  String get archiveReading;

  /// Pulsante che legge la serie dal link incollato, per controllare cosa c'è prima di scaricare
  ///
  /// In it, this message translates to:
  /// **'Verifica serie'**
  String get archiveVerify;

  /// Riga sotto il titolo della serie trovata: sito, numero di capitoli, stato di pubblicazione
  ///
  /// In it, this message translates to:
  /// **'{site} · {count, plural, =1{1 capitolo} other{{count} capitoli}} · {status}'**
  String archiveSeriesSummary(String site, int count, String status);

  /// Avviso sulla scheda della serie che è già in libreria: quanti capitoli archiviati sul totale
  ///
  /// In it, this message translates to:
  /// **'Già in libreria: {archived} di {total} capitoli. Quelli che ci sono si saltano.'**
  String archiveKnown(int archived, int total);

  /// Titolo della sezione in cui si sceglie quali capitoli scaricare
  ///
  /// In it, this message translates to:
  /// **'Cosa scaricare'**
  String get archiveWhatSection;

  /// Scelta segmentata: scarica la serie intera
  ///
  /// In it, this message translates to:
  /// **'Tutta'**
  String get archiveModeAll;

  /// Scelta segmentata: scarica dal capitolo scelto in poi
  ///
  /// In it, this message translates to:
  /// **'Dal capitolo'**
  String get archiveModeFrom;

  /// Scelta segmentata: scarica solo i capitoli scelti uno per uno
  ///
  /// In it, this message translates to:
  /// **'Scelti'**
  String get archiveModePick;

  /// Spiegazione della modalità «Tutta»
  ///
  /// In it, this message translates to:
  /// **'Tutti i capitoli. Rifarlo più avanti porta solo quelli nuovi o rovinati.'**
  String get archiveModeAllHint;

  /// Spiegazione della modalità «Dal capitolo»
  ///
  /// In it, this message translates to:
  /// **'Dal capitolo scelto in poi: i precedenti restano nell\'elenco della serie, segnati come non scaricati.'**
  String get archiveModeFromHint;

  /// Spiegazione della modalità «Scelti»
  ///
  /// In it, this message translates to:
  /// **'Solo i capitoli toccati. Gli altri restano nell\'elenco, non scaricati.'**
  String get archiveModePickHint;

  /// Suggerimento del campo in cui si scrive il numero del capitolo da cui partire
  ///
  /// In it, this message translates to:
  /// **'Numero del capitolo, come sul sito'**
  String get archiveChapterNumberHint;

  /// Quanti capitoli sono stati toccati nella scelta uno per uno
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 scelto} other{{count} scelti}}'**
  String archivePickedCount(int count);

  /// Pulsante che seleziona tutti i capitoli da scaricare
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get archiveSelectAll;

  /// Pulsante che deseleziona tutti i capitoli da scaricare
  ///
  /// In it, this message translates to:
  /// **'Nessuno'**
  String get archiveSelectNone;

  /// Titolo della sezione in cui si sceglie la destinazione del download
  ///
  /// In it, this message translates to:
  /// **'Dove'**
  String get archiveWhereSection;

  /// Destinazione: il Kagami Server collegato
  ///
  /// In it, this message translates to:
  /// **'Server'**
  String get archiveWhereServer;

  /// Destinazione: solo la cartella di Google Drive della libreria
  ///
  /// In it, this message translates to:
  /// **'Drive'**
  String get archiveWhereDrive;

  /// Destinazione: su Drive e anche sul telefono
  ///
  /// In it, this message translates to:
  /// **'Drive e telefono'**
  String get archiveWhereDriveAndPhone;

  /// Destinazione: solo sul telefono
  ///
  /// In it, this message translates to:
  /// **'Telefono'**
  String get archiveWherePhone;

  /// Spiegazione della destinazione Drive
  ///
  /// In it, this message translates to:
  /// **'Nella cartella di Drive della libreria. Le tavole passano dal telefono e se ne vanno appena Drive le ha: si leggono in streaming, o si scaricano dopo.'**
  String get archiveWhereDriveHint;

  /// Spiegazione della destinazione Drive e telefono
  ///
  /// In it, this message translates to:
  /// **'Nella cartella di Drive della libreria, e i capitoli restano anche sul telefono per leggerli senza rete.'**
  String get archiveWhereDriveAndPhoneHint;

  /// Spiegazione della destinazione Telefono
  ///
  /// In it, this message translates to:
  /// **'Sul telefono, nella cartella dei manga o nello spazio dell\'app. Collegando Drive si può scaricare direttamente là.'**
  String get archiveWherePhoneHint;

  /// Spiegazione della destinazione Server; other vale «other» se la cartella del server è diversa da quella letta dall'app, altrimenti «same»
  ///
  /// In it, this message translates to:
  /// **'Lo scarica «{name}» e lo carica in «{folder}» su Drive, anche a telefono spento. Le serie in corso le segue il server.{other, select, other{ Attenzione: non è la cartella che legge l\'app.} same{}}'**
  String archiveServerHint(String name, String folder, String other);

  /// Titolo della sezione con la pausa fra una richiesta e l'altra al sito
  ///
  /// In it, this message translates to:
  /// **'Pausa fra le richieste'**
  String get archiveDelaySection;

  /// Pausa fra le richieste: nessuna
  ///
  /// In it, this message translates to:
  /// **'Niente'**
  String get archiveDelayNone;

  /// Pausa fra le richieste in secondi (s = secondi)
  ///
  /// In it, this message translates to:
  /// **'{seconds} s'**
  String archiveDelaySeconds(String seconds);

  /// Spiegazione della pausa fra le richieste
  ///
  /// In it, this message translates to:
  /// **'I siti non amano chi scarica a raffica: una pausa breve evita di farsi bloccare.'**
  String get archiveDelayHint;

  /// Pulsante di download, modalità serie intera
  ///
  /// In it, this message translates to:
  /// **'Scarica tutta la serie'**
  String get archiveDownloadAll;

  /// Pulsante di download, modalità dal capitolo scelto
  ///
  /// In it, this message translates to:
  /// **'Scarica dal capitolo scelto'**
  String get archiveDownloadFrom;

  /// Pulsante di download, modalità capitoli scelti
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Scarica 1 capitolo} other{Scarica {count} capitoli}}'**
  String archiveDownloadPicked(int count);

  /// Ricerca per titolo senza risultati su un sito
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato su {site}.'**
  String archiveNoResults(String site);

  /// Numero di capitoli di un risultato di ricerca
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 capitolo} other{{count} capitoli}}'**
  String archiveChaptersCount(int count);

  /// Titolo della riga che apre la verifica anti-robot del sito
  ///
  /// In it, this message translates to:
  /// **'Verifica {site}'**
  String archiveVerifySite(String site);

  /// Spiegazione della riga di verifica del sito (Cloudflare)
  ///
  /// In it, this message translates to:
  /// **'Il sito vuole sapere che sei una persona: toccando si apre la verifica, poi si cerca anche lì'**
  String get archiveVerifySiteHint;

  /// Stato di pubblicazione di una serie: ancora in uscita
  ///
  /// In it, this message translates to:
  /// **'in corso'**
  String get archiveStatusOngoing;

  /// Stato di pubblicazione di una serie: finita
  ///
  /// In it, this message translates to:
  /// **'conclusa'**
  String get archiveStatusCompleted;

  /// Stato di pubblicazione di una serie: in pausa (hiatus)
  ///
  /// In it, this message translates to:
  /// **'in pausa'**
  String get archiveStatusHiatus;

  /// Stato di pubblicazione di una serie: interrotta definitivamente
  ///
  /// In it, this message translates to:
  /// **'interrotta'**
  String get archiveStatusCancelled;

  /// Stato di pubblicazione di una serie: non noto
  ///
  /// In it, this message translates to:
  /// **'stato ignoto'**
  String get archiveStatusUnknown;

  /// Errore di ricerca: il sito chiede una verifica anti-robot non eseguibile
  ///
  /// In it, this message translates to:
  /// **'Il sito chiede una verifica che da qui non si può fare.'**
  String get archiveErrChallenge;

  /// Errore: manca la rete o il sito non risponde
  ///
  /// In it, this message translates to:
  /// **'Nessuna connessione: il sito non risponde.'**
  String get archiveErrOffline;

  /// Errore: l'utente ha chiuso la pagina di verifica senza completarla
  ///
  /// In it, this message translates to:
  /// **'La verifica del sito non è stata completata.'**
  String get archiveErrVerifyIncomplete;

  /// Avviso dopo aver messo una serie in coda sul telefono
  ///
  /// In it, this message translates to:
  /// **'«{title}» è in coda. Continua anche a schermo spento.'**
  String archiveQueuedSnack(String title);

  /// Avviso dopo aver messo una serie in coda sul server
  ///
  /// In it, this message translates to:
  /// **'«{title}» è in coda su «{server}». Il telefono può anche spegnersi.'**
  String archiveQueuedServerSnack(String title, String server);

  /// Nome generico del server quando non ne ha uno
  ///
  /// In it, this message translates to:
  /// **'server'**
  String get archiveServerFallbackName;

  /// Titolo della sezione con la coda e lo storico dei download
  ///
  /// In it, this message translates to:
  /// **'Download'**
  String get archiveDownloads;

  /// Pulsante che svuota lo storico dei download
  ///
  /// In it, this message translates to:
  /// **'Pulisci'**
  String get archiveClearHistory;

  /// Titolo della riga che compare quando ci sono lavori in coda ma nessuno in corso
  ///
  /// In it, this message translates to:
  /// **'Coda ferma'**
  String get archiveQueueStopped;

  /// Spiegazione della coda ferma
  ///
  /// In it, this message translates to:
  /// **'Riparte da sola; toccando la fai partire adesso'**
  String get archiveQueueResumeHint;

  /// Riga di un lavoro in coda creato dal controllo delle serie in corso; destinazione del download
  ///
  /// In it, this message translates to:
  /// **'Capitoli nuovi · {destination}'**
  String archiveJobAutomatic(String destination);

  /// Riga di un lavoro in coda chiesto dall'utente; destinazione del download
  ///
  /// In it, this message translates to:
  /// **'In coda · {destination}'**
  String archiveJobQueued(String destination);

  /// Tooltip del pulsante che toglie un lavoro dalla coda
  ///
  /// In it, this message translates to:
  /// **'Togli dalla coda'**
  String get archiveRemoveFromQueue;

  /// Riga dello storico: quando è finito il lavoro e com'è andato (messaggio del motore)
  ///
  /// In it, this message translates to:
  /// **'{when} · {message}'**
  String archiveHistoryLine(String when, String message);

  /// Titolo della sezione con i siti da cui si può scaricare
  ///
  /// In it, this message translates to:
  /// **'Siti supportati'**
  String get archiveSites;

  /// Nota sui siti che verranno aggiunti
  ///
  /// In it, this message translates to:
  /// **'Altri siti sono in arrivo: il supporto per nuovi provider arriverà con i prossimi aggiornamenti.'**
  String get archiveMoreSites;

  /// Avviso quando il link di un sito non si può aprire e viene copiato negli appunti
  ///
  /// In it, this message translates to:
  /// **'{url} copiato negli appunti.'**
  String archiveLinkCopied(String url);

  /// Titolo della sezione sul controllo dei capitoli nuovi delle serie ancora in uscita
  ///
  /// In it, this message translates to:
  /// **'Serie in corso'**
  String get archiveTracked;

  /// Spiegazione del controllo delle serie in corso
  ///
  /// In it, this message translates to:
  /// **'Le serie in corso scaricate da qui si ricontrollano: arrivano solo i capitoli nuovi, nella stessa destinazione. Quelle del server le segue il server.'**
  String get archiveTrackedIntro;

  /// Interruttore del controllo giornaliero delle serie in corso
  ///
  /// In it, this message translates to:
  /// **'Controllo ogni giorno'**
  String get archiveCheckDaily;

  /// Controllo giornaliero spento: si controlla solo su richiesta
  ///
  /// In it, this message translates to:
  /// **'Solo a mano'**
  String get archiveCheckManual;

  /// Ora del controllo giornaliero; time è un orario già formattato
  ///
  /// In it, this message translates to:
  /// **'Alle {time}, anche ad app chiusa'**
  String archiveCheckAt(String time);

  /// Titolo della riga che apre la scelta dell'ora del controllo
  ///
  /// In it, this message translates to:
  /// **'Ora'**
  String get archiveCheckTime;

  /// Intestazione del selettore dell'ora del controllo
  ///
  /// In it, this message translates to:
  /// **'Ora del controllo'**
  String get archiveCheckTimeHelp;

  /// Interruttore: il controllo parte solo con il Wi-Fi
  ///
  /// In it, this message translates to:
  /// **'Solo con Wi-Fi'**
  String get archiveWifiOnly;

  /// Spiegazione di «Solo con Wi-Fi» acceso
  ///
  /// In it, this message translates to:
  /// **'Aspetta una rete che non si paga a consumo'**
  String get archiveWifiOnlyOn;

  /// Spiegazione di «Solo con Wi-Fi» spento
  ///
  /// In it, this message translates to:
  /// **'Anche con i dati mobili'**
  String get archiveWifiOnlyOff;

  /// Riga che avvia subito il controllo delle serie in corso
  ///
  /// In it, this message translates to:
  /// **'Controlla adesso'**
  String get archiveCheckNow;

  /// Sottotitolo di «Controlla adesso» quando non ci sono serie seguite
  ///
  /// In it, this message translates to:
  /// **'Nessuna serie da seguire, per ora'**
  String get archiveNoTracked;

  /// Quante serie in corso sono seguite
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 serie da seguire} other{{count} serie da seguire}}'**
  String archiveTrackedCount(int count);

  /// Riga di una serie seguita: capitoli noti e destinazione
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 capitolo noto} other{{count} capitoli noti}} · {destination}'**
  String archiveTrackedLine(int count, String destination);

  /// Riga di una serie seguita: capitoli noti, destinazione e quando è stata controllata l'ultima volta (when è già formattato)
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 capitolo noto} other{{count} capitoli noti}} · {destination} · controllata {when}'**
  String archiveTrackedLineChecked(int count, String destination, String when);

  /// Tooltip del pulsante che smette di seguire una serie in corso
  ///
  /// In it, this message translates to:
  /// **'Smetti di seguirla'**
  String get archiveStopFollowing;

  /// Esito del controllo: serie con capitoli nuovi messi in coda (names è un elenco di titoli); è un pezzo di frase dopo cui viene il punto
  ///
  /// In it, this message translates to:
  /// **'capitoli nuovi per {names}'**
  String archiveCheckQueued(String names);

  /// Esito del controllo: serie che ora risultano concluse (names è un elenco di titoli); pezzo di frase
  ///
  /// In it, this message translates to:
  /// **'{names} ora conclusa'**
  String archiveCheckRemoved(String names);

  /// Esito del controllo: serie che il sito non ha fatto leggere; pezzo di frase
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 non raggiunta} other{{count} non raggiunte}}'**
  String archiveCheckFailed(int count);

  /// Separatore fra i pezzi dell'esito del controllo
  ///
  /// In it, this message translates to:
  /// **'; '**
  String get archiveCheckSeparator;

  /// Frase finale dell'esito del controllo: i pezzi uniti dal separatore, seguiti dal punto
  ///
  /// In it, this message translates to:
  /// **'{parts}.'**
  String archiveCheckReport(String parts);

  /// Esito del controllo quando non c'è niente di nuovo
  ///
  /// In it, this message translates to:
  /// **'Nessun capitolo nuovo.'**
  String get archiveNoNewChapters;

  /// Avviso: manca la rete
  ///
  /// In it, this message translates to:
  /// **'Nessuna connessione.'**
  String get archiveNoConnection;

  /// Titolo del dialogo di conferma per smettere di seguire una serie
  ///
  /// In it, this message translates to:
  /// **'Smettere di seguirla?'**
  String get archiveForgetTitle;

  /// Testo del dialogo di conferma per smettere di seguire una serie
  ///
  /// In it, this message translates to:
  /// **'I capitoli nuovi di «{title}» non arriveranno più da soli. Quelli già scaricati restano.'**
  String archiveForgetBody(String title);

  /// Pulsante che chiude il dialogo senza fare niente
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get archiveCancel;

  /// Pulsante che conferma di smettere di seguire la serie
  ///
  /// In it, this message translates to:
  /// **'Smetti'**
  String get archiveForgetConfirm;

  /// Introduzione del foglio che chiede se scaricare tutta la serie o da un capitolo
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 capitolo.} other{{count} capitoli.}} Scarica tutto oppure scegli da quale capitolo partire: i precedenti restano in elenco nel lettore, senza tavole.'**
  String archiveStartIntro(int count);

  /// Il numero scritto non corrisponde a nessun capitolo
  ///
  /// In it, this message translates to:
  /// **'Nessun capitolo con questo numero.'**
  String get archiveStartNoMatch;

  /// Riepilogo della scelta: dal capitolo indicato in poi, quanti capitoli restano
  ///
  /// In it, this message translates to:
  /// **'Da «{title}» in poi: {remaining, plural, =1{1 capitolo} other{{remaining} capitoli}}.'**
  String archiveStartFrom(String title, int remaining);

  /// Nessun capitolo scelto nel foglio di partenza
  ///
  /// In it, this message translates to:
  /// **'Nessun capitolo scelto: si può scaricare tutto.'**
  String get archiveStartNone;

  /// Pulsante del foglio: scarica la serie intera
  ///
  /// In it, this message translates to:
  /// **'Scarica tutto'**
  String get archiveStartAll;

  /// Pulsante del foglio: scarica dal capitolo scelto in poi
  ///
  /// In it, this message translates to:
  /// **'Da qui'**
  String get archiveStartHere;

  /// Titolo della pagina in cui si supera la verifica anti-robot di un sito
  ///
  /// In it, this message translates to:
  /// **'Verifica del sito'**
  String get browserTitle;

  /// Messaggio sulle piattaforme senza WebView (non Android)
  ///
  /// In it, this message translates to:
  /// **'La verifica si fa solo dal telefono.'**
  String get browserPhoneOnly;

  /// Istruzioni nella pagina di verifica quando si sta aprendo la pagina di una serie
  ///
  /// In it, this message translates to:
  /// **'Il sito vuole sapere che sei una persona. Completa la verifica: quando compare l\'elenco dei capitoli, Kagami se ne accorge e torna indietro da sola.'**
  String get browserInstructionsChapters;

  /// Istruzioni nella pagina di verifica quando si sta aprendo la ricerca del sito
  ///
  /// In it, this message translates to:
  /// **'Il sito vuole sapere che sei una persona. Completa la verifica: quando compare la ricerca del sito, Kagami se ne accorge e torna indietro da sola.'**
  String get browserInstructionsSearch;

  /// Errore di ricerca su piattaforme senza WebView
  ///
  /// In it, this message translates to:
  /// **'Su questo sito si cerca solo dal telefono.'**
  String get browserSearchPhoneOnly;

  /// Errore: una ricerca è stata sostituita da una più recente
  ///
  /// In it, this message translates to:
  /// **'Superata da una ricerca più recente.'**
  String get browserSearchSuperseded;

  /// Errore: la pagina del sito è troppo grande
  ///
  /// In it, this message translates to:
  /// **'Risposta troppo grande.'**
  String get browserResponseTooLarge;

  /// Titolo della sezione «Server» in «Scarica un manga» e del foglio del server collegato
  ///
  /// In it, this message translates to:
  /// **'Server'**
  String get serverTitle;

  /// Pulsante che svuota lo storico dei lavori del server
  ///
  /// In it, this message translates to:
  /// **'Pulisci'**
  String get serverClear;

  /// Errore: la build non ha il segreto del client Web, quindi non si può dare a un server il permesso su Drive
  ///
  /// In it, this message translates to:
  /// **'Questa build dell\'app non può collegare server: chi l\'ha compilata non ha indicato il segreto del client Web (GOOGLE_SERVER_CLIENT_SECRET).'**
  String get serverUnavailableNoSecret;

  /// Errore: collegare un server è possibile solo su Android
  ///
  /// In it, this message translates to:
  /// **'Collegare un server si può solo da Android.'**
  String get serverUnavailableAndroidOnly;

  /// Errore: serve l'accesso con Google per parlare col server
  ///
  /// In it, this message translates to:
  /// **'Fai l\'accesso con Google per usare il server.'**
  String get serverSignInRequired;

  /// Errore: il telefono non ha rete
  ///
  /// In it, this message translates to:
  /// **'Nessuna connessione.'**
  String get serverNoConnection;

  /// Errore: la build non include google-services.json
  ///
  /// In it, this message translates to:
  /// **'Manca google-services.json: questa build non ha il client di Google.'**
  String get serverMissingGoogleServices;

  /// Errore: l'utente o Google ha negato il permesso su Drive
  ///
  /// In it, this message translates to:
  /// **'Google non ha concesso l\'accesso a Drive.'**
  String get serverDriveAccessDenied;

  /// Errore: i server di Google non rispondono
  ///
  /// In it, this message translates to:
  /// **'Google non risponde: riprova fra poco.'**
  String get serverGoogleNotResponding;

  /// Quando è avvenuto qualcosa, oggi; {clock} è l'ora (es. 14:30)
  ///
  /// In it, this message translates to:
  /// **'oggi alle {clock}'**
  String serverWhenToday(String clock);

  /// Quando è avvenuto qualcosa in un altro giorno; {date} è giorno e mese, {clock} l'ora
  ///
  /// In it, this message translates to:
  /// **'{date} alle {clock}'**
  String serverWhenDate(String date, String clock);

  /// Riga di avanzamento del download: tavole scaricate, dimensione e tavole già presenti (saltate)
  ///
  /// In it, this message translates to:
  /// **'{pages} tavole nuove · {size}{skipped, plural, =0{} other{ · {skipped} già a posto}}'**
  String serverProgressStats(int pages, String size, int skipped);

  /// Descrizione del pulsante che toglie un lavoro dalla coda di download
  ///
  /// In it, this message translates to:
  /// **'Togli dalla coda'**
  String get serverRemoveFromQueue;

  /// Avviso nella sezione Server: questa build non ha l'account Google
  ///
  /// In it, this message translates to:
  /// **'Il server riconosce chi lo usa dall\'account Google, che in questa build dell\'app non c\'è.'**
  String get serverNoFirebase;

  /// Spiegazione nella sezione Server quando non si è entrati con Google
  ///
  /// In it, this message translates to:
  /// **'Un computer sempre acceso può scaricare e caricare sul tuo Drive al posto del telefono, che intanto può anche spegnersi. Il server ti riconosce dal tuo account Google.'**
  String get serverSignedOutIntro;

  /// Titolo della voce che fa entrare con l'account Google
  ///
  /// In it, this message translates to:
  /// **'Accedi con Google'**
  String get serverSignIn;

  /// Sottotitolo della voce «Accedi con Google» nella sezione Server
  ///
  /// In it, this message translates to:
  /// **'Per creare il tuo server o usare quello di qualcun altro'**
  String get serverSignInSubtitle;

  /// Invito ricevuto: {sender} è chi ha invitato, {serverName} il nome del server
  ///
  /// In it, this message translates to:
  /// **'{sender} ti ha dato accesso a «{serverName}»'**
  String serverInviteTitle(String sender, String serverName);

  /// Sottotitolo dell'invito a usare un server
  ///
  /// In it, this message translates to:
  /// **'Scarica sul tuo Drive, anche a telefono spento. Tocca per collegarlo'**
  String get serverInviteSubtitle;

  /// Descrizione del pulsante che scarta un invito a un server
  ///
  /// In it, this message translates to:
  /// **'Ignora'**
  String get serverIgnore;

  /// Spiegazione nella sezione Server quando nessun server è collegato
  ///
  /// In it, this message translates to:
  /// **'Un computer sempre acceso — il tuo o quello di chi ti ha dato accesso — può scaricare e caricare sul tuo Drive al posto del telefono, che intanto può anche spegnersi.'**
  String get serverLinkIntro;

  /// Voce e titolo del foglio per creare un proprio Kagami Server
  ///
  /// In it, this message translates to:
  /// **'Crea il tuo server'**
  String get serverCreate;

  /// Sottotitolo della voce «Crea il tuo server»
  ///
  /// In it, this message translates to:
  /// **'Un comando da incollare su un computer con Docker: niente da configurare'**
  String get serverCreateSubtitle;

  /// Voce e titolo del foglio per collegare un server esistente
  ///
  /// In it, this message translates to:
  /// **'Collega un server'**
  String get serverLinkTitle;

  /// Sottotitolo della voce «Collega un server»
  ///
  /// In it, this message translates to:
  /// **'Il tuo, già acceso, o quello di chi ti ha aggiunto'**
  String get serverLinkSubtitle;

  /// Stato del server mentre l'app lo sta contattando
  ///
  /// In it, this message translates to:
  /// **'Collegamento…'**
  String get serverStateConnecting;

  /// Stato del server: manca il permesso sul Drive dell'utente
  ///
  /// In it, this message translates to:
  /// **'Non ha ancora il permesso del tuo Drive'**
  String get serverStateNoGrant;

  /// Stato del server: manca la cartella di Drive
  ///
  /// In it, this message translates to:
  /// **'Non sa ancora in quale cartella del tuo Drive scrivere'**
  String get serverStateNoFolder;

  /// Stato del server pronto; {folder} è il nome della cartella di Drive
  ///
  /// In it, this message translates to:
  /// **'Pronto · scrive in «{folder}» sul tuo Drive'**
  String serverStateReady(String folder);

  /// Sottotitolo del server collegato: indirizzo e stato
  ///
  /// In it, this message translates to:
  /// **'{address} · {state}'**
  String serverTileSubtitle(String address, String state);

  /// Sottotitolo del server collegato di un altro proprietario: indirizzo, proprietario e stato
  ///
  /// In it, this message translates to:
  /// **'{address} · di {owner} · {state}'**
  String serverTileSubtitleOwner(String address, String owner, String state);

  /// Avviso: il server è raggiunto in HTTP su un indirizzo pubblico
  ///
  /// In it, this message translates to:
  /// **'La connessione è in chiaro'**
  String get serverPlainTitle;

  /// Spiegazione dell'avviso di connessione in chiaro
  ///
  /// In it, this message translates to:
  /// **'Il token del tuo account si legge per strada: serve HTTPS (Tailscale Funnel, un reverse proxy)'**
  String get serverPlainSubtitle;

  /// Voce che dà al server il permesso sul Drive
  ///
  /// In it, this message translates to:
  /// **'Dai il tuo Drive al server'**
  String get serverGrantTitle;

  /// Sottotitolo della voce che dà il Drive al server
  ///
  /// In it, this message translates to:
  /// **'Scaricherà nella cartella che legge l\'app, anche a telefono spento'**
  String get serverGrantSubtitle;

  /// Voce che fa scrivere al server nella cartella di Drive che legge l'app
  ///
  /// In it, this message translates to:
  /// **'Usa la cartella dell\'app'**
  String get serverUseAppFolder;

  /// Le due cartelle di Drive sono diverse
  ///
  /// In it, this message translates to:
  /// **'Il server scrive in «{serverFolder}», l\'app legge «{appFolder}»'**
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder);

  /// Voce e titolo del foglio con gli account ammessi al server
  ///
  /// In it, this message translates to:
  /// **'Chi può usarlo'**
  String get serverUsersTitle;

  /// Sottotitolo quando il server ha solo il proprietario
  ///
  /// In it, this message translates to:
  /// **'Solo tu. Aggiungi l\'account Google di chi vuoi'**
  String get serverUsersOnlyYou;

  /// Sottotitolo: quanti account possono usare il server
  ///
  /// In it, this message translates to:
  /// **'{count} account, te compreso'**
  String serverUsersCount(int count);

  /// Titolo: la coda del server non sta lavorando
  ///
  /// In it, this message translates to:
  /// **'Coda in attesa'**
  String get serverQueueWaiting;

  /// Sottotitolo: la coda del server riprenderà da sola
  ///
  /// In it, this message translates to:
  /// **'Il server riparte da solo'**
  String get serverQueueRestarts;

  /// Sottotitolo di un lavoro in coda nato dal controllo automatico dei capitoli nuovi
  ///
  /// In it, this message translates to:
  /// **'Capitoli nuovi · sul server'**
  String get serverJobAutomatic;

  /// Sottotitolo di un lavoro in coda sul server
  ///
  /// In it, this message translates to:
  /// **'In coda · sul server'**
  String get serverJobQueued;

  /// Titolo della voce sulle serie in corso che il server segue
  ///
  /// In it, this message translates to:
  /// **'Serie in corso sul server'**
  String get serverOngoingTitle;

  /// Quante serie in corso il server segue
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessuna, per ora} other{{count} da seguire}}'**
  String serverOngoingCount(int count);

  /// Il controllo quotidiano dei capitoli nuovi è spento
  ///
  /// In it, this message translates to:
  /// **'controllo spento'**
  String get serverOngoingCheckOff;

  /// Ora del controllo quotidiano dei capitoli nuovi
  ///
  /// In it, this message translates to:
  /// **'controllo alle {clock}'**
  String serverOngoingCheckAt(String clock);

  /// Sottotitolo della voce sulle serie in corso: {count} è il numero di serie, {check} dice quando controlla
  ///
  /// In it, this message translates to:
  /// **'{count} · {check}. Tocca per controllare adesso'**
  String serverOngoingSubtitle(String count, String check);

  /// Di una serie seguita dal server: quanti capitoli conosce
  ///
  /// In it, this message translates to:
  /// **'{count} capitoli noti'**
  String serverSeriesKnown(int count);

  /// Di una serie seguita: capitoli noti e quando è stata controllata l'ultima volta
  ///
  /// In it, this message translates to:
  /// **'{count} capitoli noti · controllata {when}'**
  String serverSeriesKnownChecked(int count, String when);

  /// Descrizione del pulsante che fa smettere al server di seguire una serie
  ///
  /// In it, this message translates to:
  /// **'Smetti di seguirla'**
  String get serverStopFollowing;

  /// Errore nello scartare un invito
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a togliere l\'invito: riprova.'**
  String get serverInviteRemoveFailed;

  /// Conferma dopo aver chiesto al server di controllare subito i capitoli nuovi
  ///
  /// In it, this message translates to:
  /// **'Il server sta controllando: i capitoli nuovi compaiono nella sua coda.'**
  String get serverCheckingNow;

  /// Descrizione del pulsante che incolla l'indirizzo del server
  ///
  /// In it, this message translates to:
  /// **'Incolla'**
  String get serverPaste;

  /// Avviso sotto il campo indirizzo quando è HTTP su un indirizzo pubblico
  ///
  /// In it, this message translates to:
  /// **'Attenzione: in chiaro su un indirizzo pubblico il token del tuo account si legge per strada. Usa HTTPS (Tailscale Funnel, un reverse proxy) o Tailscale.'**
  String get serverAddressExposed;

  /// Nota sotto il campo indirizzo nel foglio «Collega un server»
  ///
  /// In it, this message translates to:
  /// **'L\'indirizzo viaggia col backup e con l\'account, come la cartella di Drive.'**
  String get serverAddressSavedNote;

  /// Errore: indirizzo del server mancante o non valido
  ///
  /// In it, this message translates to:
  /// **'Scrivi l\'indirizzo del server, per esempio http://192.168.1.20:8080.'**
  String get serverAddressMissing;

  /// Conferma di collegamento riuscito
  ///
  /// In it, this message translates to:
  /// **'Collegato a «{name}»: scarica in «{folder}» sul tuo Drive.'**
  String serverLinked(String name, String folder);

  /// Spiegazione nel foglio quando si arriva da un invito
  ///
  /// In it, this message translates to:
  /// **'{sender} ti ha aggiunto a «{serverName}». Collegandolo, il server scaricherà i manga che scegli nella cartella della tua libreria sul tuo Drive: Google ti chiederà di permettergli di scriverci. Chi gestisce il server potrà usare quel permesso.'**
  String serverLinkFromInvite(String sender, String serverName);

  /// Spiegazione nel foglio del server già collegato; {account} è l'email o la frase «l'account con cui hai fatto l'accesso»
  ///
  /// In it, this message translates to:
  /// **'Il server ti riconosce come {account}. Scollegandolo, se non è tuo, dimentica anche il permesso sul tuo Drive e la tua coda.'**
  String serverLinkLinked(String account);

  /// Sostituisce l'email quando non è nota, dentro la frase «Il server ti riconosce come …»
  ///
  /// In it, this message translates to:
  /// **'l\'account con cui hai fatto l\'accesso'**
  String get serverSignedInAccount;

  /// Spiegazione nel foglio «Collega un server»
  ///
  /// In it, this message translates to:
  /// **'Scrivi l\'indirizzo del server: il tuo, o quello che ti ha dato chi ti ha aggiunto. Il server ti riconosce dall\'account Google, e la prima volta gli dai il permesso di scrivere nella cartella della tua libreria su Drive.'**
  String get serverLinkNew;

  /// Pulsante mentre si verifica il server
  ///
  /// In it, this message translates to:
  /// **'Verifica…'**
  String get serverVerifying;

  /// Pulsante per ripetere la verifica del server già collegato
  ///
  /// In it, this message translates to:
  /// **'Verifica di nuovo'**
  String get serverVerifyAgain;

  /// Pulsante che verifica il server e lo collega
  ///
  /// In it, this message translates to:
  /// **'Verifica e collega'**
  String get serverVerifyAndLink;

  /// Pulsante che scollega il server
  ///
  /// In it, this message translates to:
  /// **'Scollega'**
  String get serverUnlink;

  /// Nome predefinito del server creato, se non si conosce il nome dell'utente
  ///
  /// In it, this message translates to:
  /// **'Il mio Kagami Server'**
  String get serverDefaultNameOwn;

  /// Nome predefinito del server creato; {name} è il nome di battesimo del proprietario
  ///
  /// In it, this message translates to:
  /// **'Il server di {name}'**
  String serverDefaultNameOf(String name);

  /// Conferma dopo aver copiato il comando di avvio del server
  ///
  /// In it, this message translates to:
  /// **'Comando copiato.'**
  String get serverCommandCopied;

  /// Errore: indirizzo del computer mancante o non valido
  ///
  /// In it, this message translates to:
  /// **'Scrivi l\'indirizzo del computer, per esempio http://192.168.1.20:8080.'**
  String get serverComputerAddressMissing;

  /// Errore: il server collegato ha un altro proprietario
  ///
  /// In it, this message translates to:
  /// **'Quel server è di {owner}: è collegato, ma non l\'hai creato tu.'**
  String serverNotOwner(String owner);

  /// Conferma: il server appena creato è pronto
  ///
  /// In it, this message translates to:
  /// **'«{name}» è pronto. Aggiungi chi vuoi da «Chi può usarlo».'**
  String serverReady(String name);

  /// Sostituisce il nome della cartella di Drive quando non è scelta, dentro la frase del foglio «Crea il tuo server»
  ///
  /// In it, this message translates to:
  /// **'la cartella della libreria'**
  String get serverLibraryFolderFallback;

  /// Introduzione del foglio «Crea il tuo server»
  ///
  /// In it, this message translates to:
  /// **'Serve un computer che resti acceso — un mini PC, un NAS, un Raspberry Pi, un server in rete — con Docker. Il server scarica i manga e li carica sul tuo Drive, in «{folder}», anche a telefono spento.'**
  String serverSetupIntro(String folder);

  /// Cosa fa l'app prima di generare il comando. signIn e folder valgono «yes» se quel passo manca
  ///
  /// In it, this message translates to:
  /// **'Preparo un comando che contiene tutto: {signIn, select, yes{prima fai l\'accesso con Google, poi } other{}}{folder, select, yes{scegli la cartella dei manga su Drive, poi } other{}}Google ti chiede di permettere al server di scrivere sul tuo Drive.'**
  String serverPrepareIntro(String signIn, String folder);

  /// Pulsante mentre si prepara il comando
  ///
  /// In it, this message translates to:
  /// **'Preparo…'**
  String get serverPreparing;

  /// Pulsante che genera il comando docker run
  ///
  /// In it, this message translates to:
  /// **'Genera il comando'**
  String get serverGenerate;

  /// Passo 1 delle istruzioni per creare il server
  ///
  /// In it, this message translates to:
  /// **'Installa Docker sul computer (docker.com), se non c\'è già.'**
  String get serverStep1;

  /// Passo 2 delle istruzioni per creare il server
  ///
  /// In it, this message translates to:
  /// **'Incolla questi comandi nel suo terminale: il primo accende il server, il secondo lo tiene aggiornato da solo. Contengono il permesso sul tuo Drive: non mandarli a nessuno.'**
  String get serverStep2;

  /// Pulsante che copia il comando di avvio negli appunti
  ///
  /// In it, this message translates to:
  /// **'Copia il comando'**
  String get serverCopyCommand;

  /// Passo 3 delle istruzioni per creare il server
  ///
  /// In it, this message translates to:
  /// **'Scrivi qui l\'indirizzo del computer: in casa quello della rete locale; da fuori, il suo nome in Tailscale o l\'indirizzo HTTPS con cui lo esponi.'**
  String get serverStep3;

  /// Nota sotto il campo indirizzo nel foglio «Crea il tuo server»
  ///
  /// In it, this message translates to:
  /// **'Il server risponde sulla porta 8080.'**
  String get serverPortNote;

  /// Introduzione del foglio «Chi può usarlo»
  ///
  /// In it, this message translates to:
  /// **'Aggiungi l\'account Google di chi vuoi. Nella sua app di Kagami comparirà l\'invito: collegando il server, i suoi download andranno sul suo Drive, con la sua coda.'**
  String get serverUsersIntro;

  /// Errore: email non valida
  ///
  /// In it, this message translates to:
  /// **'Scrivi l\'indirizzo dell\'account Google, per esempio nome@gmail.com.'**
  String get serverUserEmailInvalid;

  /// Conferma dopo aver aggiunto un account al server
  ///
  /// In it, this message translates to:
  /// **'{email} può usare il server: glielo dice la sua app.'**
  String serverUserAdded(String email);

  /// Titolo della conferma per togliere un account dal server
  ///
  /// In it, this message translates to:
  /// **'Togliere {email}?'**
  String serverRemoveTitle(String email);

  /// Corpo della conferma per togliere un account dal server
  ///
  /// In it, this message translates to:
  /// **'Non potrà più usare il server. La sua coda e il permesso sul suo Drive si cancellano; ciò che è già sul suo Drive resta.'**
  String get serverRemoveBody;

  /// Pulsante che chiude la conferma senza togliere l'account
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get serverCancel;

  /// Pulsante che toglie l'account dal server (azione, non «Togli dalla coda»)
  ///
  /// In it, this message translates to:
  /// **'Togli'**
  String get serverRemove;

  /// Descrizione del pulsante che aggiunge un account al server
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get serverAdd;

  /// Sottotitolo dell'account dell'utente stesso, proprietario del server
  ///
  /// In it, this message translates to:
  /// **'Tu, il proprietario'**
  String get serverOwnerYou;

  /// Sottotitolo: l'account invitato ha già collegato il server
  ///
  /// In it, this message translates to:
  /// **'Ha collegato il server'**
  String get serverConnected;

  /// Sottotitolo: l'account invitato non ha ancora collegato il server
  ///
  /// In it, this message translates to:
  /// **'Invitato, non ha ancora collegato il server'**
  String get serverInvitedPending;

  /// Schermata del primo avvio: presentazione di cosa fa l'app, sotto il titolo Kagami
  ///
  /// In it, this message translates to:
  /// **'Legge la cartella dei manga che la sincronizzazione deposita sul telefono, oppure la stessa libreria direttamente da Google Drive, senza portarla tutta qui.'**
  String get setupIntro;

  /// Primo avvio, passo 1: titolo della spiegazione del permesso di accedere a tutti i file
  ///
  /// In it, this message translates to:
  /// **'Accesso ai file'**
  String get setupAccessTitle;

  /// Primo avvio, passo 1: perché serve il permesso di accesso ai file
  ///
  /// In it, this message translates to:
  /// **'La cartella sta fuori dallo spazio privato dell\'app, e contiene decine di migliaia di immagini: Kagami ha bisogno di leggerle direttamente. Scrive soltanto le copie dei dati nella sottocartella reading/ della libreria e, se lo chiedi, i capitoli che scarichi da Drive.'**
  String get setupAccessBody;

  /// Pulsante del primo avvio che chiede il permesso di accesso ai file
  ///
  /// In it, this message translates to:
  /// **'Concedi accesso'**
  String get setupGrantAccess;

  /// Primo avvio, passo 2: titolo della scelta della cartella della libreria
  ///
  /// In it, this message translates to:
  /// **'La cartella'**
  String get setupFolderTitle;

  /// Primo avvio, passo 2: quale cartella scegliere (FolderSync è un'app di sincronizzazione, library.json un nome di file)
  ///
  /// In it, this message translates to:
  /// **'Indica la cartella sincronizzata da FolderSync: quella che contiene library.json e una sottocartella per serie.'**
  String get setupFolderBody;

  /// Pulsante del primo avvio che apre il selettore della cartella della libreria
  ///
  /// In it, this message translates to:
  /// **'Scegli la cartella'**
  String get setupChooseFolder;

  /// Separatore fra la scelta della cartella del telefono e quella di Google Drive
  ///
  /// In it, this message translates to:
  /// **'oppure'**
  String get setupOr;

  /// Primo avvio: titolo della scheda che spiega la lettura da Drive (nome proprio)
  ///
  /// In it, this message translates to:
  /// **'Google Drive'**
  String get setupDriveTitle;

  /// Primo avvio: spiega come funziona la lettura direttamente da Google Drive
  ///
  /// In it, this message translates to:
  /// **'Si accede con Google e si sceglie la cartella della libreria su Drive: le tavole arrivano mentre si legge, e i capitoli che si vogliono avere sempre a portata si scaricano con un tocco. Non serve l\'accesso ai file del telefono.'**
  String get setupDriveBody;

  /// Pulsante del primo avvio che collega Google Drive
  ///
  /// In it, this message translates to:
  /// **'Leggi da Google Drive'**
  String get setupReadFromDrive;

  /// Titolo dello stato vuoto mostrato quando la libreria non si riesce a leggere
  ///
  /// In it, this message translates to:
  /// **'Libreria non leggibile'**
  String get setupLibraryProblemTitle;

  /// Pulsante sotto l'errore della libreria: sceglie un'altra cartella
  ///
  /// In it, this message translates to:
  /// **'Cambia cartella'**
  String get setupChangeFolder;

  /// Titolo del foglio in cui si sceglie la cartella della libreria su Google Drive
  ///
  /// In it, this message translates to:
  /// **'Cartella su Drive'**
  String get driveFolderSheetTitle;

  /// Titolo del foglio che chiede dove salvare i capitoli scaricati
  ///
  /// In it, this message translates to:
  /// **'Dove salvo i manga?'**
  String get driveDestinationTitle;

  /// Spiega la scelta fra una cartella sul telefono e lo spazio privato dell'app per i download
  ///
  /// In it, this message translates to:
  /// **'Non c\'è una cartella per i manga sul telefono. In una cartella i capitoli scaricati restano anche se l\'app si disinstalla, e Kagami li legge insieme a quelli che ci sono già. Nello spazio dell\'app non serve nessun permesso, ma se ne vanno con lei.'**
  String get driveDestinationBody;

  /// Pulsante del foglio della destinazione dei download: sceglie una cartella del telefono
  ///
  /// In it, this message translates to:
  /// **'Scegli una cartella'**
  String get driveChooseFolder;

  /// Pulsante del foglio della destinazione dei download: usa lo spazio privato dell'app
  ///
  /// In it, this message translates to:
  /// **'Nello spazio dell\'app'**
  String get driveInAppSpace;

  /// Scheda del navigatore cartelle: il Drive dell'utente
  ///
  /// In it, this message translates to:
  /// **'Il mio Drive'**
  String get driveMyDrive;

  /// Scheda del navigatore cartelle: cartelle condivise da altri
  ///
  /// In it, this message translates to:
  /// **'Condivisi con me'**
  String get driveSharedWithMe;

  /// Descrizione (tooltip) del pulsante che torna alla cartella superiore nel navigatore di Drive
  ///
  /// In it, this message translates to:
  /// **'Indietro'**
  String get driveBack;

  /// Titolo dell'errore del navigatore cartelle quando Drive non risponde
  ///
  /// In it, this message translates to:
  /// **'Drive non risponde'**
  String get driveNoResponse;

  /// Pulsante per ritentare dopo un errore di Drive o di rete
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get driveRetry;

  /// Navigatore cartelle: la cartella scelta è una libreria valida (library.json è un nome di file)
  ///
  /// In it, this message translates to:
  /// **'Contiene library.json: è una libreria'**
  String get driveIsLibrary;

  /// Navigatore cartelle: la cartella scelta non è una libreria (library.json è un nome di file)
  ///
  /// In it, this message translates to:
  /// **'Non contiene library.json: la libreria è la cartella che lo ha'**
  String get driveNotLibrary;

  /// Pulsante che conferma la cartella di Drive scelta come libreria
  ///
  /// In it, this message translates to:
  /// **'Usa questa cartella'**
  String get driveUseFolder;

  /// Navigatore cartelle: la cartella aperta non contiene sottocartelle
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella qui'**
  String get driveNoFolders;

  /// Avviso sopra la libreria: manca il permesso su Drive
  ///
  /// In it, this message translates to:
  /// **'Kagami non ha ancora il permesso di leggere Google Drive'**
  String get driveNoticeAuthRequired;

  /// Pulsante dell'avviso che chiede il permesso su Google Drive
  ///
  /// In it, this message translates to:
  /// **'Autorizza'**
  String get driveAuthorize;

  /// Pulsante dell'avviso che fa accedere con l'account Google
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get driveSignIn;

  /// Avviso sopra la libreria quando non c'è rete
  ///
  /// In it, this message translates to:
  /// **'Sei offline: si leggono i capitoli sul telefono e le tavole di Drive già scaricate. Il resto torna da solo con la rete'**
  String get driveNoticeOffline;

  /// Avviso sopra la libreria quando Drive dà un errore; {message} è il testo dell'errore
  ///
  /// In it, this message translates to:
  /// **'Drive: {message}. Si vede quello che c\'è sul telefono'**
  String driveNoticeError(String message);

  /// Riassunto della sincronizzazione della cartella nelle impostazioni: disattivata
  ///
  /// In it, this message translates to:
  /// **'Spenta'**
  String get syncSummaryOff;

  /// Direzione della sincronizzazione, usata nel riassunto
  ///
  /// In it, this message translates to:
  /// **'Da Drive al telefono'**
  String get syncSummaryDownload;

  /// Direzione della sincronizzazione, usata nel riassunto
  ///
  /// In it, this message translates to:
  /// **'Dal telefono a Drive'**
  String get syncSummaryUpload;

  /// Direzione della sincronizzazione, usata nel riassunto
  ///
  /// In it, this message translates to:
  /// **'In entrambe le direzioni'**
  String get syncSummaryBoth;

  /// Riassunto della sincronizzazione senza orario; {direction} è la direzione già localizzata
  ///
  /// In it, this message translates to:
  /// **'{direction}, a mano'**
  String syncSummaryManual(String direction);

  /// Riassunto della sincronizzazione programmata; {direction} è la direzione già localizzata, {time} l'ora (HH:mm)
  ///
  /// In it, this message translates to:
  /// **'{direction}, ogni giorno alle {time}'**
  String syncSummaryDaily(String direction, String time);

  /// Titolo della schermata della sincronizzazione della cartella
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione'**
  String get syncTitle;

  /// Introduzione della schermata di sincronizzazione (FolderSync è un'altra app)
  ///
  /// In it, this message translates to:
  /// **'Tiene uguali la cartella dei manga sul telefono e quella su Drive, senza FolderSync. Se lo usi ancora su questa cartella, spegnilo: due sincronizzazioni sugli stessi file si pestano i piedi.'**
  String get syncIntro;

  /// Intestazione di sezione: le due cartelle sincronizzate
  ///
  /// In it, this message translates to:
  /// **'Cartelle'**
  String get syncFolders;

  /// Riga che mostra la cartella locale
  ///
  /// In it, this message translates to:
  /// **'Sul telefono'**
  String get syncOnPhone;

  /// Sottotitolo quando non è stata scelta la cartella del telefono
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella scelta'**
  String get syncNoFolderChosen;

  /// Riga che mostra la cartella di Google Drive
  ///
  /// In it, this message translates to:
  /// **'Su Drive'**
  String get syncOnDrive;

  /// Sottotitolo quando Google Drive non è collegato
  ///
  /// In it, this message translates to:
  /// **'Drive non è collegato'**
  String get syncDriveNotConnected;

  /// Intestazione di sezione: verso dove si copia
  ///
  /// In it, this message translates to:
  /// **'Direzione'**
  String get syncDirection;

  /// Voce del selettore di direzione: sincronizzazione disattivata
  ///
  /// In it, this message translates to:
  /// **'Spenta'**
  String get syncDirectionOff;

  /// Voce del selettore di direzione: da Drive al telefono
  ///
  /// In it, this message translates to:
  /// **'Da Drive'**
  String get syncDirectionFromDrive;

  /// Voce del selettore di direzione: dal telefono a Drive
  ///
  /// In it, this message translates to:
  /// **'Verso Drive'**
  String get syncDirectionToDrive;

  /// Voce del selettore di direzione: in tutt'e due i versi
  ///
  /// In it, this message translates to:
  /// **'Entrambe'**
  String get syncDirectionBoth;

  /// Spiegazione della direzione Spenta; «Scarica» è il pulsante di download dei capitoli
  ///
  /// In it, this message translates to:
  /// **'Niente si muove da solo. La libreria di Drive si legge lo stesso, e «Scarica» funziona come sempre.'**
  String get syncDescOff;

  /// Spiegazione della direzione Da Drive
  ///
  /// In it, this message translates to:
  /// **'Quello che arriva su Drive scende sul telefono. Dal telefono non sale niente.'**
  String get syncDescDownload;

  /// Spiegazione della direzione Verso Drive (reading/backup è un percorso)
  ///
  /// In it, this message translates to:
  /// **'Quello che c\'è sul telefono sale su Drive — per esempio le copie dei dati in reading/backup. Gli indici della libreria restano quelli del server.'**
  String get syncDescUpload;

  /// Spiegazione della direzione Entrambe
  ///
  /// In it, this message translates to:
  /// **'Quello che cambia da una parte arriva dall\'altra; se è cambiato da tutt\'e due, vince il più recente. Gli indici della libreria scendono e basta: sono del server.'**
  String get syncDescBoth;

  /// Interruttore: un file tolto da una parte si toglie anche dall'altra
  ///
  /// In it, this message translates to:
  /// **'Propaga le cancellazioni'**
  String get syncDeletions;

  /// Sottotitolo dell'interruttore delle cancellazioni, direzione Da Drive
  ///
  /// In it, this message translates to:
  /// **'Toglie dal telefono ciò che sparisce da Drive'**
  String get syncDeletionsDownload;

  /// Sottotitolo dell'interruttore delle cancellazioni, direzione Verso Drive
  ///
  /// In it, this message translates to:
  /// **'Sposta nel cestino di Drive ciò che togli dal telefono'**
  String get syncDeletionsUpload;

  /// Sottotitolo dell'interruttore delle cancellazioni, direzione Entrambe
  ///
  /// In it, this message translates to:
  /// **'Da una parte all\'altra; da Drive solo nel cestino'**
  String get syncDeletionsBoth;

  /// Nota sotto l'interruttore delle cancellazioni quando è acceso; «Libera spazio» è il foglio che cancella i capitoli già letti
  ///
  /// In it, this message translates to:
  /// **'«Libera spazio» toglie i capitoli letti anche da Drive, al giro seguente.'**
  String get syncDeletionsOnNote;

  /// Nota sotto l'interruttore delle cancellazioni quando è spento
  ///
  /// In it, this message translates to:
  /// **'Un file tolto da una parte resta dall\'altra e non torna indietro: «Libera spazio» libera il telefono e lascia i capitoli su Drive.'**
  String get syncDeletionsOffNote;

  /// Intestazione di sezione: sincronizzazione programmata
  ///
  /// In it, this message translates to:
  /// **'Ogni giorno'**
  String get syncDaily;

  /// Interruttore della sincronizzazione giornaliera
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione programmata'**
  String get syncScheduled;

  /// Sottotitolo dell'interruttore della programmazione quando è spento
  ///
  /// In it, this message translates to:
  /// **'Solo a mano'**
  String get syncManualOnly;

  /// Sottotitolo della programmazione accesa; {time} è l'ora (HH:mm)
  ///
  /// In it, this message translates to:
  /// **'Alle {time}, anche ad app chiusa'**
  String syncAtTime(String time);

  /// Riga che mostra e cambia l'ora della sincronizzazione giornaliera
  ///
  /// In it, this message translates to:
  /// **'Ora'**
  String get syncTime;

  /// Interruttore: il giro programmato parte solo con il Wi-Fi
  ///
  /// In it, this message translates to:
  /// **'Solo con Wi-Fi'**
  String get syncWifiOnly;

  /// Sottotitolo di «Solo con Wi-Fi» quando è acceso
  ///
  /// In it, this message translates to:
  /// **'Aspetta una rete che non si paga a consumo'**
  String get syncWifiOnlyOn;

  /// Sottotitolo di «Solo con Wi-Fi» quando è spento
  ///
  /// In it, this message translates to:
  /// **'Anche con i dati mobili'**
  String get syncWifiOnlyOff;

  /// Nota sotto la sezione della sincronizzazione programmata
  ///
  /// In it, this message translates to:
  /// **'Android decide il momento esatto: se all\'ora scelta manca la rete, il giro parte appena torna.'**
  String get syncScheduleNote;

  /// Intestazione di sezione: il giro a mano
  ///
  /// In it, this message translates to:
  /// **'Adesso'**
  String get syncNow;

  /// Titolo del selettore dell'ora
  ///
  /// In it, this message translates to:
  /// **'Ora della sincronizzazione'**
  String get syncTimePickerHelp;

  /// Riga che avvia subito un giro di sincronizzazione
  ///
  /// In it, this message translates to:
  /// **'Sincronizza adesso'**
  String get syncRunNow;

  /// Sottotitolo di «Sincronizza adesso» quando si può avviare
  ///
  /// In it, this message translates to:
  /// **'Si può continuare a leggere: le copie vanno avanti da sole'**
  String get syncRunNowReady;

  /// Sottotitolo di «Sincronizza adesso» quando mancano le cartelle
  ///
  /// In it, this message translates to:
  /// **'Servono la cartella del telefono e quella di Drive'**
  String get syncRunNowNotReady;

  /// Avanzamento del giro: elenco dei file su Drive
  ///
  /// In it, this message translates to:
  /// **'Guardo cosa c\'è su Drive…'**
  String get syncPhaseListing;

  /// Avanzamento del giro: confronto con i file del telefono
  ///
  /// In it, this message translates to:
  /// **'Confronto con il telefono…'**
  String get syncPhaseComparing;

  /// Avanzamento del giro: nessun file da copiare
  ///
  /// In it, this message translates to:
  /// **'Niente da copiare'**
  String get syncPhaseNothing;

  /// Avanzamento del giro: file copiato corrente su totale
  ///
  /// In it, this message translates to:
  /// **'File {done} di {total}'**
  String syncPhaseFiles(int done, int total);

  /// Descrizione (tooltip) del pulsante che ferma il giro in corso
  ///
  /// In it, this message translates to:
  /// **'Interrompi'**
  String get syncStop;

  /// Titolo dell'esito quando non c'è ancora stato nessun giro
  ///
  /// In it, this message translates to:
  /// **'Mai sincronizzata'**
  String get syncNever;

  /// Nota sotto «Mai sincronizzata»
  ///
  /// In it, this message translates to:
  /// **'Il primo giro su una cartella già piena è veloce: i file uguali si riconoscono dalla misura'**
  String get syncNeverNote;

  /// Data dell'ultimo giro, se era programmato; {date} è giorno e mese, {time} l'ora
  ///
  /// In it, this message translates to:
  /// **'Ultima, programmata: {date} alle {time}'**
  String syncLastScheduled(String date, String time);

  /// Data dell'ultimo giro, se lanciato a mano; {date} è giorno e mese, {time} l'ora
  ///
  /// In it, this message translates to:
  /// **'Ultima, a mano: {date} alle {time}'**
  String syncLastManual(String date, String time);

  /// Esito dell'ultimo giro: file scaricati dal Drive al telefono
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{{count} scaricati} other{{count} scaricati}}'**
  String syncOutcomeDownloaded(int count);

  /// Esito dell'ultimo giro: file caricati dal telefono su Drive
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{{count} caricati} other{{count} caricati}}'**
  String syncOutcomeUploaded(int count);

  /// Esito dell'ultimo giro: file cancellati dal telefono
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{{count} tolti dal telefono} other{{count} tolti dal telefono}}'**
  String syncOutcomeDeletedLocal(int count);

  /// Esito dell'ultimo giro: file spostati nel cestino di Drive
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{{count} nel cestino di Drive} other{{count} nel cestino di Drive}}'**
  String syncOutcomeTrashed(int count);

  /// Esito dell'ultimo giro: file non copiati, che si riprovano al prossimo
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{{count} non riusciti, si riprovano} other{{count} non riusciti, si riprovano}}'**
  String syncOutcomeFailed(int count);

  /// Esito di un giro finito con errore; {error} è il messaggio, {done} l'elenco di ciò che era stato fatto
  ///
  /// In it, this message translates to:
  /// **'{error}. Fin lì: {done}'**
  String syncOutcomeErrorSoFar(String error, String done);

  /// Esito dell'ultimo giro: niente da copiare
  ///
  /// In it, this message translates to:
  /// **'Era già tutto allineato'**
  String get syncOutcomeAligned;

  /// Titolo della schermata delle impostazioni
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settingsTitle;

  /// Intestazione di sezione delle impostazioni: tema e lingua
  ///
  /// In it, this message translates to:
  /// **'Aspetto'**
  String get settingsAppearance;

  /// Tema dell'interfaccia: scuro
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get settingsThemeDark;

  /// Tema dell'interfaccia: chiaro
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get settingsThemeLight;

  /// Tema dell'interfaccia: segue quello del telefono
  ///
  /// In it, this message translates to:
  /// **'Come il sistema'**
  String get settingsThemeSystem;

  /// Intestazione di sezione delle impostazioni: la cartella della libreria
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get settingsLibrary;

  /// Riga che mostra e cambia la cartella della libreria sul telefono
  ///
  /// In it, this message translates to:
  /// **'Cartella'**
  String get settingsFolder;

  /// Sottotitolo quando non c'è una cartella della libreria
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella scelta'**
  String get settingsNoFolder;

  /// Riga che rilegge gli indici della libreria
  ///
  /// In it, this message translates to:
  /// **'Rileggi gli indici'**
  String get settingsReloadIndexes;

  /// Sottotitolo di «Rileggi gli indici»
  ///
  /// In it, this message translates to:
  /// **'Da fare quando la sincronizzazione ha appena portato roba nuova'**
  String get settingsReloadIndexesNote;

  /// Messaggio breve dopo aver riletto gli indici
  ///
  /// In it, this message translates to:
  /// **'Indici riletti'**
  String get settingsIndexesReloaded;

  /// Intestazione di sezione delle impostazioni: Drive (nome proprio)
  ///
  /// In it, this message translates to:
  /// **'Google Drive'**
  String get settingsGoogleDrive;

  /// Intestazione di sezione delle impostazioni: valori predefiniti del lettore
  ///
  /// In it, this message translates to:
  /// **'Lettura'**
  String get settingsReading;

  /// Intestazione di sezione delle impostazioni: accesso con Google
  ///
  /// In it, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Intestazione di sezione delle impostazioni: backup e dati personali
  ///
  /// In it, this message translates to:
  /// **'Dati'**
  String get settingsData;

  /// Intestazione di sezione delle impostazioni: versione dell'app
  ///
  /// In it, this message translates to:
  /// **'Informazioni'**
  String get settingsAbout;

  /// Riga delle impostazioni che sceglie tema chiaro, scuro o del sistema; accanto c'è la scelta attuale
  ///
  /// In it, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// Sottotitolo della voce «Libreria» nella pagina principale delle impostazioni, quando Google Drive è disponibile
  ///
  /// In it, this message translates to:
  /// **'Cartella, indici e Google Drive'**
  String get settingsLibraryNote;

  /// Sottotitolo della voce «Libreria» nella pagina principale delle impostazioni, senza Google Drive
  ///
  /// In it, this message translates to:
  /// **'Cartella e indici'**
  String get settingsLibraryNoteLocal;

  /// Sottotitolo della voce «Lettura» nella pagina principale delle impostazioni
  ///
  /// In it, this message translates to:
  /// **'Modalità predefinita e misure del lettore'**
  String get settingsReadingNote;

  /// Sottotitolo della voce «Account» nella pagina principale delle impostazioni
  ///
  /// In it, this message translates to:
  /// **'Accesso con Google e sincronizzazione'**
  String get settingsAccountNote;

  /// Sottotitolo della voce «Dati» nella pagina principale delle impostazioni
  ///
  /// In it, this message translates to:
  /// **'Backup, ripristino e cancellazione'**
  String get settingsDataNote;

  /// Interruttore della copia di backup giornaliera
  ///
  /// In it, this message translates to:
  /// **'Copia automatica nella libreria'**
  String get settingsAutoBackup;

  /// Sottotitolo dell'interruttore della copia automatica (reading/backup/ è un percorso)
  ///
  /// In it, this message translates to:
  /// **'Una volta al giorno in reading/backup/, che la sincronizzazione porta su Drive insieme ai manga'**
  String get settingsAutoBackupNote;

  /// Riga che esporta i dati personali in un file
  ///
  /// In it, this message translates to:
  /// **'Esporta i dati'**
  String get settingsExport;

  /// Sottotitolo di «Esporta i dati»
  ///
  /// In it, this message translates to:
  /// **'Stato, voti, cronologia, raccolte e segnalibri in un file'**
  String get settingsExportNote;

  /// Titolo del selettore di file per salvare il backup
  ///
  /// In it, this message translates to:
  /// **'Dove salvare il backup'**
  String get settingsExportDialog;

  /// Messaggio breve: l'utente ha annullato l'esportazione
  ///
  /// In it, this message translates to:
  /// **'Esportazione annullata'**
  String get settingsExportCancelled;

  /// Messaggio breve: backup salvato
  ///
  /// In it, this message translates to:
  /// **'Backup salvato'**
  String get settingsExportSaved;

  /// Riga che importa i dati da un file di backup
  ///
  /// In it, this message translates to:
  /// **'Importa da un backup'**
  String get settingsImport;

  /// Sottotitolo di «Importa da un backup»
  ///
  /// In it, this message translates to:
  /// **'Dice cosa contiene prima di toccare niente'**
  String get settingsImportNote;

  /// Titolo del selettore di file per scegliere il backup
  ///
  /// In it, this message translates to:
  /// **'Scegli un backup di Kagami'**
  String get settingsImportDialog;

  /// Messaggio breve: il file scelto non è un backup valido
  ///
  /// In it, this message translates to:
  /// **'Non è un backup di Kagami'**
  String get settingsImportInvalid;

  /// Titolo del foglio di conferma dell'importazione
  ///
  /// In it, this message translates to:
  /// **'Importare questo backup?'**
  String get settingsImportSheetTitle;

  /// Etichetta di un numero nel riepilogo del backup: quante serie
  ///
  /// In it, this message translates to:
  /// **'Serie'**
  String get settingsImportSeries;

  /// Etichetta di un numero nel riepilogo del backup: quanti capitoli letti
  ///
  /// In it, this message translates to:
  /// **'Letti'**
  String get settingsImportRead;

  /// Etichetta di un numero nel riepilogo del backup: quante raccolte
  ///
  /// In it, this message translates to:
  /// **'Raccolte'**
  String get settingsImportCollections;

  /// Spiega le due scelte di importazione (Fondi e Sostituisci); {date} è la data del backup
  ///
  /// In it, this message translates to:
  /// **'Fatto il {date}. Fondere tiene quello che hai già e aggiunge: i capitoli letti si sommano e per il resto vince il record più recente. Sostituire cancella i dati di questo dispositivo.'**
  String settingsImportExplain(String date);

  /// Come la spiegazione dell'importazione, ma per un backup senza data
  ///
  /// In it, this message translates to:
  /// **'Fatto in una data ignota. Fondere tiene quello che hai già e aggiunge: i capitoli letti si sommano e per il resto vince il record più recente. Sostituire cancella i dati di questo dispositivo.'**
  String get settingsImportExplainUnknownDate;

  /// Pulsante: importa il backup unendolo ai dati esistenti
  ///
  /// In it, this message translates to:
  /// **'Fondi'**
  String get settingsImportMerge;

  /// Pulsante: importa il backup cancellando i dati esistenti
  ///
  /// In it, this message translates to:
  /// **'Sostituisci'**
  String get settingsImportReplace;

  /// Messaggio breve: importazione riuscita
  ///
  /// In it, this message translates to:
  /// **'Dati importati'**
  String get settingsImportDone;

  /// Messaggio breve: importazione fallita
  ///
  /// In it, this message translates to:
  /// **'Importazione non riuscita'**
  String get settingsImportFailed;

  /// Riga che cancella i dati personali dal telefono
  ///
  /// In it, this message translates to:
  /// **'Elimina i dati personali'**
  String get settingsWipe;

  /// Sottotitolo di «Elimina i dati personali»
  ///
  /// In it, this message translates to:
  /// **'Stato, voti, cronologia e raccolte. I manga non si toccano'**
  String get settingsWipeNote;

  /// Titolo del foglio di conferma della cancellazione dei dati
  ///
  /// In it, this message translates to:
  /// **'Eliminare tutti i dati personali?'**
  String get settingsWipeSheetTitle;

  /// Avviso nel foglio di conferma della cancellazione dei dati personali
  ///
  /// In it, this message translates to:
  /// **'Spariscono stato, voti, preferiti, capitoli letti, cronologia, sessioni, raccolte e segnalibri di questo dispositivo. I manga e gli indici della libreria non vengono toccati.\n\nSe non hai un backup, questa è l\'ultima occasione per farlo.'**
  String get settingsWipeExplain;

  /// Pulsante di conferma della cancellazione dei dati personali
  ///
  /// In it, this message translates to:
  /// **'Elimina tutto'**
  String get settingsWipeConfirm;

  /// Messaggio breve: dati personali cancellati
  ///
  /// In it, this message translates to:
  /// **'Dati personali eliminati'**
  String get settingsWipeDone;

  /// Riga che collega Drive, quando non lo è
  ///
  /// In it, this message translates to:
  /// **'Collega Google Drive'**
  String get settingsDriveConnect;

  /// Sottotitolo di «Collega Google Drive»
  ///
  /// In it, this message translates to:
  /// **'Legge la libreria da Drive senza portarla tutta sul telefono, e scarica solo ciò che si sceglie'**
  String get settingsDriveConnectNote;

  /// Riga che mostra e cambia la cartella della libreria su Drive
  ///
  /// In it, this message translates to:
  /// **'Cartella su Drive'**
  String get settingsDriveFolder;

  /// Riga che apre la schermata di sincronizzazione della cartella
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione della cartella'**
  String get settingsDriveSync;

  /// Titolo della riga che dice dove finiscono i capitoli scaricati da Drive
  ///
  /// In it, this message translates to:
  /// **'I capitoli scaricati vanno'**
  String get settingsDriveDownloadsGo;

  /// Destinazione dei capitoli scaricati: la cartella della libreria; {path} è il percorso
  ///
  /// In it, this message translates to:
  /// **'Nella cartella della libreria: {path}'**
  String settingsDriveDownloadsFolder(String path);

  /// Destinazione dei capitoli scaricati: lo spazio privato dell'app
  ///
  /// In it, this message translates to:
  /// **'Nello spazio dell\'app: se ne vanno disinstallandola'**
  String get settingsDriveDownloadsApp;

  /// Destinazione dei capitoli scaricati: non ancora scelta
  ///
  /// In it, this message translates to:
  /// **'Si chiede al primo download'**
  String get settingsDriveDownloadsAsk;

  /// Titolo della riga sulla cache delle tavole scaricate da Drive mentre si legge
  ///
  /// In it, this message translates to:
  /// **'Tavole lette da Drive'**
  String get settingsDriveCache;

  /// Sottotitolo della cache di Drive; {used} e {limit} sono dimensioni (es. 120 MB, 2 GB)
  ///
  /// In it, this message translates to:
  /// **'{used} in cache, al massimo {limit}. Si rileggono senza rete'**
  String settingsDriveCacheNote(String used, String limit);

  /// Titolo del foglio che sceglie la dimensione massima della cache di Drive
  ///
  /// In it, this message translates to:
  /// **'Spazio per le tavole'**
  String get settingsDriveCacheLimitTitle;

  /// Riga che svuota la cache delle tavole di Drive
  ///
  /// In it, this message translates to:
  /// **'Svuota la cache'**
  String get settingsDriveClearCache;

  /// Sottotitolo di «Svuota la cache»
  ///
  /// In it, this message translates to:
  /// **'I capitoli scaricati non si toccano'**
  String get settingsDriveClearCacheNote;

  /// Riga che scollega Google Drive
  ///
  /// In it, this message translates to:
  /// **'Scollega Drive'**
  String get settingsDriveDisconnect;

  /// Sottotitolo di «Scollega Drive»
  ///
  /// In it, this message translates to:
  /// **'La libreria torna a essere la cartella del telefono. I capitoli scaricati restano'**
  String get settingsDriveDisconnectNote;

  /// Titolo mostrato nelle build senza Firebase
  ///
  /// In it, this message translates to:
  /// **'Account non disponibile qui'**
  String get settingsAccountUnavailable;

  /// Sottotitolo di «Account non disponibile qui»
  ///
  /// In it, this message translates to:
  /// **'Questa build non ha Firebase: i dati restano dove sono, sul dispositivo'**
  String get settingsAccountUnavailableNote;

  /// Riga che fa accedere con l'account Google
  ///
  /// In it, this message translates to:
  /// **'Accedi con Google'**
  String get settingsAccountSignIn;

  /// Sottotitolo di «Accedi con Google»
  ///
  /// In it, this message translates to:
  /// **'Voti, stato, capitoli letti, cronologia e raccolte seguono l\'account invece del telefono'**
  String get settingsAccountSignInNote;

  /// Riga che sincronizza subito i dati personali con l'account
  ///
  /// In it, this message translates to:
  /// **'Sincronizza adesso'**
  String get settingsAccountSyncNow;

  /// Sottotitolo della sincronizzazione account: mai fatta
  ///
  /// In it, this message translates to:
  /// **'Mai sincronizzato su questo telefono'**
  String get settingsAccountNeverSynced;

  /// Sottotitolo della sincronizzazione account; {date} è giorno e mese, {time} l'ora
  ///
  /// In it, this message translates to:
  /// **'L\'ultima volta il {date} alle {time}'**
  String settingsAccountLastSync(String date, String time);

  /// Riga che chiude la sessione con l'account Google
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get settingsAccountSignOut;

  /// Sottotitolo di «Esci»
  ///
  /// In it, this message translates to:
  /// **'Manda su l\'ultima lettura, poi chiude la sessione'**
  String get settingsAccountSignOutNote;

  /// Riga che cancella i dati dall'account
  ///
  /// In it, this message translates to:
  /// **'Smetti di tenerne copia'**
  String get settingsAccountForget;

  /// Sottotitolo di «Smetti di tenerne copia»
  ///
  /// In it, this message translates to:
  /// **'Cancella i dati dall\'account. Quelli di questo telefono restano dove sono'**
  String get settingsAccountForgetNote;

  /// Sottotitolo sotto un errore dell'account
  ///
  /// In it, this message translates to:
  /// **'I dati di questo telefono non sono stati toccati'**
  String get settingsAccountErrorNote;

  /// Titolo del foglio di conferma della cancellazione dei dati dall'account
  ///
  /// In it, this message translates to:
  /// **'Cancellare i dati dall\'account?'**
  String get settingsAccountForgetSheetTitle;

  /// Avviso nel foglio di conferma della cancellazione dall'account
  ///
  /// In it, this message translates to:
  /// **'Sparisce la copia tenuta per te, e l\'accesso si chiude. Stato, voti, cronologia e raccolte di questo telefono restano dove sono — ma da un altro telefono non si vedranno più.'**
  String get settingsAccountForgetExplain;

  /// Pulsante di conferma della cancellazione dei dati dall'account
  ///
  /// In it, this message translates to:
  /// **'Cancella dall\'account'**
  String get settingsAccountForgetConfirm;

  /// Impostazione del lettore: verso di lettura in modalità a pagine
  ///
  /// In it, this message translates to:
  /// **'Direzione in paginata'**
  String get settingsReaderDirection;

  /// Impostazione del lettore: colore dello sfondo
  ///
  /// In it, this message translates to:
  /// **'Sfondo'**
  String get settingsReaderBackground;

  /// Impostazione del lettore: schermo sempre acceso
  ///
  /// In it, this message translates to:
  /// **'Tieni acceso lo schermo'**
  String get settingsReaderKeepAwake;

  /// Impostazione del lettore: barra di avanzamento
  ///
  /// In it, this message translates to:
  /// **'Barra di avanzamento'**
  String get settingsReaderProgressBar;

  /// Interruttore che mostra nel lettore i numeri sulla fluidità dello scorrimento
  ///
  /// In it, this message translates to:
  /// **'Misura la fluidità'**
  String get settingsProbe;

  /// Sottotitolo di «Misura la fluidità» (GC è il garbage collector)
  ///
  /// In it, this message translates to:
  /// **'Nel lettore, in alto: fotogrammi lenti e saltati, da dove arrivano le fasce, GC. Un tocco sui numeri li azzera'**
  String get settingsProbeNote;

  /// Spiegazione di «Misura la fluidità», paragrafo 1
  ///
  /// In it, this message translates to:
  /// **'Mostra nel lettore, in alto a sinistra, un riquadro di numeri su quanto è fluida la lettura. Serve a capire perché lo scorrimento scatta: non cambia niente di come si legge, e costa pochissimo.'**
  String get settingsProbeInfo1;

  /// Spiegazione di «Misura la fluidità», paragrafo 2: nomina le etichette del riquadro di misura (saltati, Partiti tardi, Lenti, GC Android)
  ///
  /// In it, this message translates to:
  /// **'Il numero che conta di più è «saltati»: i fotogrammi che mancano mentre la pagina scorre. Ognuno è un piccolo scatto che si vede. «Partiti tardi» e «Lenti» dicono se l\'app era occupata, «GC Android» se il sistema stava liberando memoria.'**
  String get settingsProbeInfo2;

  /// Spiegazione di «Misura la fluidità», paragrafo 3: nomina le etichette del riquadro di misura (tessere, intere, del telefono, native)
  ///
  /// In it, this message translates to:
  /// **'«Tessere», «intere», «del telefono» e «native» dicono da dove è arrivato ogni pezzo di tavola: le prime tre sono le vie leggere, l\'ultima è il ritaglio fatto al momento, che è quella che pesa.'**
  String get settingsProbeInfo3;

  /// Spiegazione di «Misura la fluidità», paragrafo 4
  ///
  /// In it, this message translates to:
  /// **'Un tocco sul riquadro azzera i numeri, così si misura da un punto preciso del capitolo. Riaprendo l\'app la misura si spegne da sola.'**
  String get settingsProbeInfo4;

  /// Interruttore sperimentale: le fasce ritagliate dal telefono vanno alla GPU come texture
  ///
  /// In it, this message translates to:
  /// **'Fasce native come texture'**
  String get settingsTexture;

  /// Sottotitolo di «Fasce native come texture»
  ///
  /// In it, this message translates to:
  /// **'Prova: le tavole ancora da tagliare arrivano alla GPU senza passare dall\'interfaccia. Si spegne riaprendo l\'app'**
  String get settingsTextureNote;

  /// Spiegazione di «Fasce native come texture», paragrafo 1
  ///
  /// In it, this message translates to:
  /// **'Le tavole molto alte di un webtoon si leggono a pezzi. Quasi sempre i pezzi sono già pronti: tagliati dall\'archivio sul server, o dal telefono la prima volta che si apre il capitolo. Quando non lo sono, li ritaglia al momento il decodificatore di Android.'**
  String get settingsTextureInfo1;

  /// Spiegazione di «Fasce native come texture», paragrafo 2
  ///
  /// In it, this message translates to:
  /// **'Normalmente i pixel di quei pezzi passano dall\'app prima di arrivare allo schermo. Con questa opzione vanno direttamente alla scheda grafica: l\'app ha meno lavoro mentre si scorre, e lo scorrimento può scattare meno. La qualità dell\'immagine non cambia.'**
  String get settingsTextureInfo2;

  /// Spiegazione di «Fasce native come texture», paragrafo 3
  ///
  /// In it, this message translates to:
  /// **'È una prova: è un modo di disegnare nuovo, non ancora verificato su questo telefono. Se vedi tavole nere, righe o sfarfallii, spegnila. Se il telefono non lo supporta, l\'app torna da sola al modo normale.'**
  String get settingsTextureInfo3;

  /// Spiegazione di «Fasce native come texture», paragrafo 4
  ///
  /// In it, this message translates to:
  /// **'Sui capitoli già tagliati in tessere non cambia niente, perché lì questa strada non si usa. Riaprendo l\'app si spegne da sola.'**
  String get settingsTextureInfo4;

  /// Descrizione (tooltip) del pulsante info che spiega un'impostazione
  ///
  /// In it, this message translates to:
  /// **'Cosa fa'**
  String get settingsWhatItDoes;

  /// Riga che elenca le copie di backup automatiche nella cartella della libreria
  ///
  /// In it, this message translates to:
  /// **'Copie nella libreria'**
  String get settingsBackupsTitle;

  /// Sottotitolo di «Copie nella libreria» quando non ce ne sono
  ///
  /// In it, this message translates to:
  /// **'Nessuna copia ancora: la prima si fa alla prossima apertura'**
  String get settingsBackupsNone;

  /// Sottotitolo di «Copie nella libreria»; {name} è il nome del file dell'ultima copia
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 copia, l\'ultima {name}} other{{count} copie, l\'ultima {name}}}'**
  String settingsBackupsLatest(int count, String name);

  /// Descrizione (tooltip) del pulsante che crea subito una copia di backup
  ///
  /// In it, this message translates to:
  /// **'Fai una copia adesso'**
  String get settingsBackupNow;

  /// Messaggio breve dopo aver scritto la copia; {path} è il percorso del file
  ///
  /// In it, this message translates to:
  /// **'Copia scritta in {path}'**
  String settingsBackupWritten(String path);

  /// Riga informazioni: versione dell'app e numero di build
  ///
  /// In it, this message translates to:
  /// **'versione {version} ({build})'**
  String settingsVersion(String version, String build);

  /// Descrizione breve dell'app mostrata nelle informazioni (MALF è il nome del formato)
  ///
  /// In it, this message translates to:
  /// **'lettore per archivi MALF locali'**
  String get settingsTagline;

  /// Ordinamento della libreria: per data dell'ultimo capitolo arrivato
  ///
  /// In it, this message translates to:
  /// **'Aggiornate di recente'**
  String get librarySortUpdated;

  /// Ordinamento della libreria: alfabetico per titolo
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get librarySortTitle;

  /// Ordinamento della libreria: per percentuale di capitoli letti
  ///
  /// In it, this message translates to:
  /// **'Avanzamento'**
  String get librarySortProgress;

  /// Ordinamento della libreria: per data in cui la serie è stata archiviata
  ///
  /// In it, this message translates to:
  /// **'Aggiunte di recente'**
  String get librarySortAdded;

  /// Ordinamento della libreria: per ultima lettura
  ///
  /// In it, this message translates to:
  /// **'Lette di recente'**
  String get librarySortLastRead;

  /// Ordinamento della libreria: per numero di capitoli ancora da leggere
  ///
  /// In it, this message translates to:
  /// **'Da leggere'**
  String get librarySortUnread;

  /// Ordinamento della libreria: per voto dato dall'utente
  ///
  /// In it, this message translates to:
  /// **'Voto'**
  String get librarySortRating;

  /// Ordinamento della libreria: per numero di capitoli archiviati
  ///
  /// In it, this message translates to:
  /// **'Numero di capitoli'**
  String get librarySortChapters;

  /// Ordinamento della libreria: casuale
  ///
  /// In it, this message translates to:
  /// **'A caso'**
  String get librarySortShuffle;

  /// Disposizione della libreria: griglia con copertine grandi
  ///
  /// In it, this message translates to:
  /// **'Griglia comoda'**
  String get libraryDisplayComfortable;

  /// Disposizione della libreria: griglia con copertine piccole
  ///
  /// In it, this message translates to:
  /// **'Griglia fitta'**
  String get libraryDisplayCompact;

  /// Disposizione della libreria: elenco semplice
  ///
  /// In it, this message translates to:
  /// **'Elenco'**
  String get libraryDisplayList;

  /// Disposizione della libreria: elenco con autori, stato e avanzamento
  ///
  /// In it, this message translates to:
  /// **'Elenco dettagliato'**
  String get libraryDisplayDetailed;

  /// Raccolta automatica: serie che si stanno leggendo
  ///
  /// In it, this message translates to:
  /// **'In lettura'**
  String get libraryAutoReading;

  /// Raccolta automatica: serie con capitoli nuovi
  ///
  /// In it, this message translates to:
  /// **'Novità'**
  String get libraryAutoFresh;

  /// Raccolta automatica: serie preferite
  ///
  /// In it, this message translates to:
  /// **'Preferiti'**
  String get libraryAutoFavorites;

  /// Raccolta automatica: serie in programma o mai iniziate
  ///
  /// In it, this message translates to:
  /// **'Da iniziare'**
  String get libraryAutoPlanned;

  /// Raccolta automatica: serie completate
  ///
  /// In it, this message translates to:
  /// **'Finiti'**
  String get libraryAutoFinished;

  /// Riga d'elenco della libreria: numero di capitoli di una serie, abbreviato
  ///
  /// In it, this message translates to:
  /// **'{count} cap.'**
  String libraryRowChapters(int count);

  /// Riga d'elenco della libreria: numero di capitoli ancora da leggere
  ///
  /// In it, this message translates to:
  /// **'{count} da leggere'**
  String libraryRowUnread(int count);

  /// Titolo della libreria quando ricerca o filtri non trovano nessuna serie
  ///
  /// In it, this message translates to:
  /// **'Nessuna corrispondenza'**
  String get libraryNoMatchTitle;

  /// Messaggio della libreria quando ricerca o filtri non trovano nessuna serie
  ///
  /// In it, this message translates to:
  /// **'Nessuna serie passa la ricerca e i filtri scelti.'**
  String get libraryNoMatchMessage;

  /// Titolo della libreria quando non contiene nessuna serie
  ///
  /// In it, this message translates to:
  /// **'Libreria vuota'**
  String get libraryEmptyTitle;

  /// Messaggio della libreria vuota
  ///
  /// In it, this message translates to:
  /// **'La libreria non contiene serie. Se dovrebbe, controllare la sincronizzazione della cartella.'**
  String get libraryEmptyMessage;

  /// Pulsante che toglie ricerca e filtri dalla libreria
  ///
  /// In it, this message translates to:
  /// **'Azzera i filtri'**
  String get libraryClearFilters;

  /// Titolo della schermata della libreria
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get libraryTitle;

  /// Descrizione del pulsante che esce dalla selezione multipla di serie
  ///
  /// In it, this message translates to:
  /// **'Annulla selezione'**
  String get libraryCancelSelection;

  /// Barra della selezione multipla: quante serie sono selezionate
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 selezionata} other{{count} selezionate}}'**
  String librarySelectedCount(int count);

  /// Pulsante che seleziona tutte le serie, o chip che mostra tutta la libreria, col numero di serie
  ///
  /// In it, this message translates to:
  /// **'Tutte ({count})'**
  String libraryAllWithCount(int count);

  /// Pulsante che seleziona tutte le serie visibili
  ///
  /// In it, this message translates to:
  /// **'Tutte'**
  String get libraryAll;

  /// Azione di gruppo sulle serie selezionate: segna tutti i capitoli come letti
  ///
  /// In it, this message translates to:
  /// **'Segna tutto letto'**
  String get libraryMarkAllRead;

  /// Azione di gruppo sulle serie selezionate: riporta tutti i capitoli da leggere
  ///
  /// In it, this message translates to:
  /// **'Segna tutto da leggere'**
  String get libraryMarkAllUnread;

  /// Azione di gruppo sulle serie selezionate e gruppo di filtri: stato dell'utente sulla serie (in lettura, completata, ecc.)
  ///
  /// In it, this message translates to:
  /// **'Stato'**
  String get libraryStatus;

  /// Azione di gruppo sulle serie selezionate: aggiunge ai preferiti
  ///
  /// In it, this message translates to:
  /// **'Preferiti'**
  String get libraryFavorites;

  /// Azione di gruppo sulle serie selezionate: le aggiunge a una raccolta
  ///
  /// In it, this message translates to:
  /// **'Aggiungi a una raccolta'**
  String get libraryAddToCollection;

  /// Titolo del foglio per scegliere lo stato da dare alle serie selezionate
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Stato di 1 serie} other{Stato di {count} serie}}'**
  String libraryStatusOfSeries(int count);

  /// Avviso dopo aver segnato come lette le serie selezionate
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 serie segnata come letta} other{{count} serie segnate come lette}}'**
  String libraryMarkedRead(int count);

  /// Avviso dopo aver riportato da leggere le serie selezionate
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 serie tornata da leggere} other{{count} serie tornate da leggere}}'**
  String libraryMarkedUnread(int count);

  /// Suggerimento nel campo di ricerca della libreria; «tag:» è un prefisso di ricerca che resta com'è
  ///
  /// In it, this message translates to:
  /// **'Titolo, autore, tag:…'**
  String get librarySearchHint;

  /// Pulsante e titolo del foglio per scegliere come disporre la libreria (griglia, elenco)
  ///
  /// In it, this message translates to:
  /// **'Disposizione'**
  String get libraryLayout;

  /// Pulsante e titolo del foglio di filtri e ordinamento della libreria
  ///
  /// In it, this message translates to:
  /// **'Filtri e ordinamento'**
  String get libraryFiltersAndSort;

  /// Pulsante nel foglio dei filtri che li toglie tutti
  ///
  /// In it, this message translates to:
  /// **'Azzera'**
  String get libraryReset;

  /// Intestazione di sezione nel foglio dei filtri: scelta dell'ordinamento
  ///
  /// In it, this message translates to:
  /// **'Ordina'**
  String get librarySortSection;

  /// Intestazione di sezione nel foglio dei filtri: interruttori che restringono l'elenco
  ///
  /// In it, this message translates to:
  /// **'Mostra solo'**
  String get libraryShowOnly;

  /// Filtro: solo serie con capitoli ancora da leggere
  ///
  /// In it, this message translates to:
  /// **'Con capitoli da leggere'**
  String get libraryOnlyUnread;

  /// Filtro: solo serie già iniziate a leggere
  ///
  /// In it, this message translates to:
  /// **'Iniziate'**
  String get libraryOnlyStarted;

  /// Filtro: solo serie con capitoli arrivati dopo l'ultima apertura
  ///
  /// In it, this message translates to:
  /// **'Con capitoli nuovi'**
  String get libraryOnlyNew;

  /// Filtro: solo serie preferite
  ///
  /// In it, this message translates to:
  /// **'Preferite'**
  String get libraryOnlyFavorite;

  /// Gruppo di filtri: voto minimo, seguito da un numero da 6 a 10
  ///
  /// In it, this message translates to:
  /// **'Voto almeno'**
  String get libraryMinRating;

  /// Gruppo di filtri: stato di pubblicazione della serie (in corso, conclusa, ecc.)
  ///
  /// In it, this message translates to:
  /// **'Pubblicazione'**
  String get libraryRelease;

  /// Gruppo di filtri per genere
  ///
  /// In it, this message translates to:
  /// **'Generi'**
  String get libraryGenres;

  /// Suggerimento sotto i generi: un tocco su un valore lo richiede, un secondo lo esclude
  ///
  /// In it, this message translates to:
  /// **'Un tocco richiede, due escludono'**
  String get libraryTriHint;

  /// Gruppo di filtri per tag
  ///
  /// In it, this message translates to:
  /// **'Tag'**
  String get libraryTags;

  /// Gruppo di filtri per autore
  ///
  /// In it, this message translates to:
  /// **'Autori'**
  String get libraryAuthors;

  /// Home: titolo quando la libreria non ha serie
  ///
  /// In it, this message translates to:
  /// **'Libreria vuota'**
  String get homeEmptyTitle;

  /// Home: messaggio quando la libreria non ha serie
  ///
  /// In it, this message translates to:
  /// **'Niente da sfogliare: la cartella non contiene ancora nessuna serie.'**
  String get homeEmptyMessage;

  /// Home: titolo della fila di serie mai aperte che si potrebbero iniziare
  ///
  /// In it, this message translates to:
  /// **'Da iniziare'**
  String get homeToStart;

  /// Home: titolo della fila di consigli basati sui generi già letti
  ///
  /// In it, this message translates to:
  /// **'Perché leggi quello che leggi'**
  String get homeSimilarTitle;

  /// Home: sottotitolo della fila di consigli
  ///
  /// In it, this message translates to:
  /// **'Non ancora aperte, con i generi che ti tornano'**
  String get homeSimilarSubtitle;

  /// Home: titolo della fila di serie aggiunte da poco all'archivio
  ///
  /// In it, this message translates to:
  /// **'Arrivate di recente'**
  String get homeRecentlyArrived;

  /// Home: titolo della fila di serie in pausa o abbandonate
  ///
  /// In it, this message translates to:
  /// **'Lasciate a metà'**
  String get homeLeftHalfway;

  /// Home: sottotitolo della fila di serie in pausa o abbandonate
  ///
  /// In it, this message translates to:
  /// **'In pausa e abbandonate'**
  String get homeLeftHalfwaySubtitle;

  /// Home: titolo quando non c'è niente da riprendere, aggiornare o iniziare
  ///
  /// In it, this message translates to:
  /// **'Sei in pari'**
  String get homeCaughtUpTitle;

  /// Home: messaggio di «sei in pari», completa il titolo «Sei in pari»
  ///
  /// In it, this message translates to:
  /// **'Con tutto quello che è sincronizzato. Il prossimo capitolo arriverà con la cartella.'**
  String get homeCaughtUpMessage;

  /// Home: descrizione del pulsante che apre una serie scelta a caso
  ///
  /// In it, this message translates to:
  /// **'Una a caso'**
  String get homeRandomSeries;

  /// Home: descrizione del pulsante che rilegge la cartella della libreria
  ///
  /// In it, this message translates to:
  /// **'Rileggi la libreria'**
  String get homeReloadLibrary;

  /// Home: saluto da mezzanotte alle 5
  ///
  /// In it, this message translates to:
  /// **'Notte fonda'**
  String get homeGreetingNight;

  /// Home: saluto del mattino
  ///
  /// In it, this message translates to:
  /// **'Buongiorno'**
  String get homeGreetingMorning;

  /// Home: saluto del pomeriggio
  ///
  /// In it, this message translates to:
  /// **'Buon pomeriggio'**
  String get homeGreetingAfternoon;

  /// Home: saluto della sera
  ///
  /// In it, this message translates to:
  /// **'Buonasera'**
  String get homeGreetingEvening;

  /// Home: etichetta della scheda con i capitoli letti in tutto (participio: capitoli letti)
  ///
  /// In it, this message translates to:
  /// **'Letti'**
  String get homeStatRead;

  /// Home: didascalia sotto il numero di capitoli letti
  ///
  /// In it, this message translates to:
  /// **'capitoli in tutto'**
  String get homeStatReadCaption;

  /// Home: etichetta della scheda con i capitoli ancora da leggere
  ///
  /// In it, this message translates to:
  /// **'Da leggere'**
  String get homeStatUnread;

  /// Home: didascalia sotto il numero di capitoli da leggere
  ///
  /// In it, this message translates to:
  /// **'sul telefono'**
  String get homeStatUnreadCaption;

  /// Home: etichetta della scheda con i giorni consecutivi di lettura
  ///
  /// In it, this message translates to:
  /// **'Di fila'**
  String get homeStatStreak;

  /// Home: didascalia sotto il numero di giorni di lettura consecutivi
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{giorno} other{giorni}}'**
  String homeStatStreakCaption(int count);

  /// Home: titolo della fila delle serie da riprendere a leggere
  ///
  /// In it, this message translates to:
  /// **'Riprendi'**
  String get homeResume;

  /// Home: testo della scheda di ripresa quando il capitolo da leggere non è noto
  ///
  /// In it, this message translates to:
  /// **'Capitolo successivo'**
  String get homeNextChapter;

  /// Home: pulsante che apre il lettore sul capitolo da riprendere
  ///
  /// In it, this message translates to:
  /// **'Leggi'**
  String get homeRead;

  /// Home: titolo dell'elenco delle serie con capitoli arrivati
  ///
  /// In it, this message translates to:
  /// **'Aggiornamenti'**
  String get homeUpdates;

  /// Home: sottotitolo dell'elenco degli aggiornamenti
  ///
  /// In it, this message translates to:
  /// **'Capitoli sincronizzati e non ancora letti'**
  String get homeUpdatesSubtitle;

  /// Home: ultimo capitolo arrivato di una serie, abbreviato; {number} è il numero del capitolo
  ///
  /// In it, this message translates to:
  /// **'cap. {number}'**
  String homeLatestChapter(String number);

  /// Quanto tempo fa è arrivato l'ultimo capitolo: oggi
  ///
  /// In it, this message translates to:
  /// **'oggi'**
  String get homeAgoToday;

  /// Quanto tempo fa è arrivato l'ultimo capitolo: ieri
  ///
  /// In it, this message translates to:
  /// **'ieri'**
  String get homeAgoYesterday;

  /// Quanto tempo fa è arrivato l'ultimo capitolo, in giorni
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 giorno fa} other{{count} giorni fa}}'**
  String homeAgoDays(int count);

  /// Quanto tempo fa è arrivato l'ultimo capitolo, in settimane
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 settimana fa} other{{count} settimane fa}}'**
  String homeAgoWeeks(int count);

  /// Quanto tempo fa è arrivato l'ultimo capitolo, in mesi
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 mese fa} other{{count} mesi fa}}'**
  String homeAgoMonths(int count);

  /// Quanto tempo fa è arrivato l'ultimo capitolo, in anni
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 anno fa} other{{count} anni fa}}'**
  String homeAgoYears(int count);

  /// Titolo della schermata delle raccolte (come le playlist)
  ///
  /// In it, this message translates to:
  /// **'Raccolte'**
  String get collectionsTitle;

  /// Pulsante che crea una nuova raccolta
  ///
  /// In it, this message translates to:
  /// **'Nuova'**
  String get collectionsNew;

  /// Intestazione di sezione: raccolte costruite dall'app
  ///
  /// In it, this message translates to:
  /// **'Automatiche'**
  String get collectionsAutomatic;

  /// Intestazione di sezione: raccolte create dall'utente
  ///
  /// In it, this message translates to:
  /// **'Le tue raccolte'**
  String get collectionsYours;

  /// Titolo quando l'utente non ha creato raccolte
  ///
  /// In it, this message translates to:
  /// **'Nessuna raccolta'**
  String get collectionsNoneTitle;

  /// Messaggio quando l'utente non ha creato raccolte
  ///
  /// In it, this message translates to:
  /// **'Sono il modo per dare struttura a una libreria che cresce da sola: una serie può stare in più raccolte e l\'ordine lo scegli tu.'**
  String get collectionsNoneMessage;

  /// Numero di serie in una raccolta
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 serie} other{{count} serie}}'**
  String collectionsSeriesCount(int count);

  /// Descrizione del pulsante con il menu di una raccolta
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get collectionsEdit;

  /// Voce del menu di una raccolta
  ///
  /// In it, this message translates to:
  /// **'Rinomina e cambia colore'**
  String get collectionsRenameRecolor;

  /// Voce del menu di una raccolta
  ///
  /// In it, this message translates to:
  /// **'Elimina la raccolta'**
  String get collectionsDelete;

  /// Messaggio quando la raccolta aperta non esiste più
  ///
  /// In it, this message translates to:
  /// **'Raccolta non trovata.'**
  String get collectionsNotFound;

  /// Descrizione del pulsante che esce dalla modalità di riordino di una raccolta
  ///
  /// In it, this message translates to:
  /// **'Fine'**
  String get collectionsDone;

  /// Descrizione del pulsante che attiva il riordino delle serie di una raccolta
  ///
  /// In it, this message translates to:
  /// **'Riordina'**
  String get collectionsReorder;

  /// Titolo quando una raccolta non contiene serie
  ///
  /// In it, this message translates to:
  /// **'Raccolta vuota'**
  String get collectionsEmptyTitle;

  /// Messaggio quando una raccolta non contiene serie
  ///
  /// In it, this message translates to:
  /// **'Si aggiunge una serie dalla sua scheda, o tenendo premuta una copertina nella libreria.'**
  String get collectionsEmptyMessage;

  /// Descrizione del pulsante che toglie una serie dalla raccolta (non la elimina)
  ///
  /// In it, this message translates to:
  /// **'Togli dalla raccolta'**
  String get collectionsRemoveFrom;

  /// Titolo della schermata d'errore quando il database dell'app non risponde all'avvio
  ///
  /// In it, this message translates to:
  /// **'Dati dell\'app non leggibili'**
  String get shellDataUnreadableTitle;

  /// Pulsante della schermata d'errore all'avvio: riprova a leggere i dati dell'app
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get shellRetry;

  /// Barra di navigazione in basso: prima destinazione, la schermata iniziale
  ///
  /// In it, this message translates to:
  /// **'Home'**
  String get shellTabHome;

  /// Barra di navigazione in basso: la libreria di manga
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get shellTabLibrary;

  /// Barra di navigazione in basso: le raccolte, elenchi di serie creati dall'utente o automatici
  ///
  /// In it, this message translates to:
  /// **'Raccolte'**
  String get shellTabCollections;

  /// Voce delle Impostazioni che apre la schermata per archiviare una serie da un sito
  ///
  /// In it, this message translates to:
  /// **'Scarica un manga'**
  String get moreDownload;

  /// Sottotitolo della voce «Scarica un manga»
  ///
  /// In it, this message translates to:
  /// **'Cerca un titolo o incolla un link'**
  String get moreDownloadSubtitle;

  /// Voce delle Impostazioni che apre la cronologia di lettura
  ///
  /// In it, this message translates to:
  /// **'Cronologia'**
  String get moreHistory;

  /// Sottotitolo della voce Cronologia
  ///
  /// In it, this message translates to:
  /// **'Cosa hai letto e quando'**
  String get moreHistorySubtitle;

  /// Voce delle Impostazioni che apre le statistiche di lettura
  ///
  /// In it, this message translates to:
  /// **'Statistiche'**
  String get moreStatistics;

  /// Sottotitolo della voce Statistiche
  ///
  /// In it, this message translates to:
  /// **'Quanto leggi, cosa leggi, quando'**
  String get moreStatisticsSubtitle;

  /// Interruttore nelle Impostazioni: la lettura non lascia tracce
  ///
  /// In it, this message translates to:
  /// **'Lettura in incognito'**
  String get moreIncognito;

  /// Sottotitolo dell'interruttore della lettura in incognito
  ///
  /// In it, this message translates to:
  /// **'Non registra posizione, capitoli finiti né tempo di lettura'**
  String get moreIncognitoSubtitle;

  /// Titolo della schermata della cronologia di lettura
  ///
  /// In it, this message translates to:
  /// **'Cronologia'**
  String get historyTitle;

  /// Tooltip del pulsante a occhio nella cronologia quando la lettura in incognito è accesa
  ///
  /// In it, this message translates to:
  /// **'Incognito attivo'**
  String get historyIncognitoOn;

  /// Tooltip del pulsante a occhio nella cronologia quando la lettura in incognito è spenta: lo accende
  ///
  /// In it, this message translates to:
  /// **'Leggi in incognito'**
  String get historyIncognitoOff;

  /// Tooltip del cestino e pulsante di conferma che cancella tutta la cronologia di lettura
  ///
  /// In it, this message translates to:
  /// **'Svuota'**
  String get historyClear;

  /// Titolo dell'errore quando la cronologia non si riesce a leggere
  ///
  /// In it, this message translates to:
  /// **'Cronologia non leggibile'**
  String get historyUnreadable;

  /// Titolo dello stato vuoto della cronologia
  ///
  /// In it, this message translates to:
  /// **'Niente di letto, per ora'**
  String get historyEmptyTitle;

  /// Messaggio dello stato vuoto della cronologia
  ///
  /// In it, this message translates to:
  /// **'Ogni capitolo finito comparirà qui con la sua data.'**
  String get historyEmptyMessage;

  /// Titolo del foglio di conferma per cancellare la cronologia
  ///
  /// In it, this message translates to:
  /// **'Svuotare la cronologia?'**
  String get historyClearTitle;

  /// Spiegazione nel foglio di conferma che svuota la cronologia
  ///
  /// In it, this message translates to:
  /// **'Le date di lettura e il tempo passato a leggere spariscono, e con loro le statistiche che ne derivano. I capitoli tornano da leggere.'**
  String get historyClearMessage;

  /// Banner in fondo alla cronologia quando la lettura in incognito è attiva
  ///
  /// In it, this message translates to:
  /// **'In incognito: posizione, capitoli finiti e tempo di lettura non vengono registrati.'**
  String get historyIncognitoBanner;

  /// Intestazione del gruppo di cronologia di oggi
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get historyToday;

  /// Intestazione del gruppo di cronologia di ieri
  ///
  /// In it, this message translates to:
  /// **'Ieri'**
  String get historyYesterday;

  /// Tooltip del pulsante su una riga di cronologia che riapre il capitolo
  ///
  /// In it, this message translates to:
  /// **'Rileggi'**
  String get historyReread;

  /// Tooltip del pulsante su una riga di cronologia che la rimuove (il capitolo torna da leggere)
  ///
  /// In it, this message translates to:
  /// **'Togli dalla cronologia'**
  String get historyRemove;

  /// Etichetta di accessibilità dell'icona d'origine: la serie è solo sul telefono
  ///
  /// In it, this message translates to:
  /// **'Sul telefono'**
  String get originLocal;

  /// Etichetta di accessibilità dell'icona d'origine: la serie è solo su Google Drive
  ///
  /// In it, this message translates to:
  /// **'Su Drive'**
  String get originDrive;

  /// Etichetta di accessibilità dell'icona d'origine: alcuni capitoli sul telefono e altri su Drive
  ///
  /// In it, this message translates to:
  /// **'Sul telefono, e altri capitoli su Drive'**
  String get originMixed;

  /// Sottotitolo di una serie in griglia senza capitoli sul telefono né su Drive
  ///
  /// In it, this message translates to:
  /// **'Nessun capitolo scaricato'**
  String get coverNoChapters;

  /// Sottotitolo di una serie in griglia: numero di capitoli, «cap.» è l'abbreviazione di capitoli
  ///
  /// In it, this message translates to:
  /// **'{count, plural, other{{count} cap.}}'**
  String coverChapters(int count);

  /// Sottotitolo di una serie in griglia: numero di capitoli («cap.» abbreviazione) e quanti ne restano da leggere
  ///
  /// In it, this message translates to:
  /// **'{count, plural, other{{count} cap.}} · {unread} da leggere'**
  String coverChaptersUnread(int count, int unread);

  /// Etichetta di accessibilità del pallino dei capitoli arrivati dall'ultima apertura della scheda
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 capitolo nuovo} other{{count} capitoli nuovi}}'**
  String coverNewChapters(int count);

  /// Etichetta di accessibilità del segnalino dei capitoli da leggere
  ///
  /// In it, this message translates to:
  /// **'{unread, plural, =1{1 capitolo da leggere} other{{unread} capitoli da leggere}}'**
  String coverUnread(int unread);

  /// Etichetta di accessibilità del segnalino dei capitoli da leggere, quando alcuni sono nuovi (arrivati di recente)
  ///
  /// In it, this message translates to:
  /// **'{unread, plural, =1{1 capitolo da leggere} other{{unread} capitoli da leggere}}, di cui {fresh, plural, =1{1 nuovo} other{{fresh} nuovi}}'**
  String coverUnreadFresh(int unread, int fresh);

  /// Tooltip di un quadratino del calendario dell'attività: in quel giorno non si è letto niente. {date} è giorno e mese
  ///
  /// In it, this message translates to:
  /// **'{date}: niente'**
  String chartsDayNothing(String date);

  /// Tooltip di un quadratino del calendario dell'attività: capitoli letti in quel giorno. {date} è giorno e mese
  ///
  /// In it, this message translates to:
  /// **'{date}: {count, plural, =1{1 capitolo} other{{count} capitoli}}'**
  String chartsDayChapters(String date, int count);

  /// Tooltip del pulsante X che chiude un foglio a scomparsa
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get kitClose;

  /// Titolo del foglio per aggiungere una serie alle raccolte
  ///
  /// In it, this message translates to:
  /// **'Raccolte'**
  String get collectionSheetTitle;

  /// Titolo del foglio per aggiungere più serie selezionate alle raccolte
  ///
  /// In it, this message translates to:
  /// **'Raccolte di {count} serie'**
  String collectionSheetTitleMany(int count);

  /// Pulsante nel foglio delle raccolte che crea una nuova raccolta
  ///
  /// In it, this message translates to:
  /// **'Nuova'**
  String get collectionSheetNew;

  /// Titolo dello stato vuoto del foglio delle raccolte
  ///
  /// In it, this message translates to:
  /// **'Nessuna raccolta'**
  String get collectionSheetEmptyTitle;

  /// Messaggio dello stato vuoto del foglio delle raccolte: a cosa servono
  ///
  /// In it, this message translates to:
  /// **'Servono a dare struttura a una libreria che cresce da sola.'**
  String get collectionSheetEmptyMessage;

  /// Sottotitolo di una raccolta: quante serie contiene
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 serie} other{{count} serie}}'**
  String collectionSheetSeriesCount(int count);

  /// Titolo del foglio per creare una raccolta
  ///
  /// In it, this message translates to:
  /// **'Nuova raccolta'**
  String get collectionSheetCreateTitle;

  /// Titolo del foglio per modificare nome e colore di una raccolta
  ///
  /// In it, this message translates to:
  /// **'Modifica raccolta'**
  String get collectionSheetEditTitle;

  /// Segnaposto del campo del nome di una raccolta
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get collectionSheetNameHint;

  /// Intestazione della scelta del colore di una raccolta
  ///
  /// In it, this message translates to:
  /// **'Colore'**
  String get collectionSheetColor;

  /// Pulsante che crea la raccolta
  ///
  /// In it, this message translates to:
  /// **'Crea'**
  String get collectionSheetCreate;

  /// Pulsante che salva le modifiche alla raccolta
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get collectionSheetSave;

  /// Titolo del foglio che propone di togliere i capitoli già letti
  ///
  /// In it, this message translates to:
  /// **'Liberare spazio?'**
  String get cleanupTitle;

  /// Avviso: non si può liberare spazio mentre la sincronizzazione della cartella è in corso
  ///
  /// In it, this message translates to:
  /// **'Una sincronizzazione è in corso: riprova quando finisce'**
  String get cleanupSyncBusy;

  /// Avviso dopo un errore di file durante la cancellazione dei capitoli letti. {error} è il messaggio del sistema
  ///
  /// In it, this message translates to:
  /// **'Non tutto è stato cancellato: {error}'**
  String cleanupNotAllDeleted(String error);

  /// Avviso dopo un errore di Google Drive durante la cancellazione. {error} è il messaggio di Drive
  ///
  /// In it, this message translates to:
  /// **'Drive: {error}. Quelli già tolti restano tolti'**
  String cleanupDriveError(String error);

  /// Avviso a operazione finita: spazio liberato. {size} è una dimensione già formattata, per esempio «120 MB»
  ///
  /// In it, this message translates to:
  /// **'Liberati {size}'**
  String cleanupFreed(String size);

  /// Avviso: senza rete non si possono spostare capitoli di Drive nel cestino
  ///
  /// In it, this message translates to:
  /// **'Per togliere da Drive serve la rete'**
  String get cleanupNeedsNetwork;

  /// Introduzione del foglio «Libera spazio» quando i capitoli letti sono solo su Google Drive
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Un capitolo già letto è ancora su Drive.} other{{count} capitoli già letti sono ancora su Drive.}}'**
  String cleanupIntroDrive(int count);

  /// Introduzione del foglio «Libera spazio» quando i capitoli letti occupano spazio sul telefono
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Un capitolo già letto occupa ancora spazio sul telefono.} other{{count} capitoli già letti occupano ancora spazio sul telefono.}}'**
  String cleanupIntroPhone(int count);

  /// Voce del foglio «Libera spazio»: i capitoli letti salvati sul telefono
  ///
  /// In it, this message translates to:
  /// **'Capitoli sul telefono'**
  String get cleanupPhoneChapters;

  /// Voce del foglio «Libera spazio»: le immagini di Drive già scaricate in memoria temporanea sul telefono
  ///
  /// In it, this message translates to:
  /// **'Cache di Drive'**
  String get cleanupDriveCache;

  /// Voce del foglio «Libera spazio»: i capitoli letti che si tolgono da Google Drive
  ///
  /// In it, this message translates to:
  /// **'Capitoli su Drive'**
  String get cleanupDriveChapters;

  /// Sottotitolo di una voce del foglio «Libera spazio»: numero di capitoli e spazio approssimativo. {size} è già formattato, per esempio «120 MB»
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 capitolo} other{{count} capitoli}} · circa {size}'**
  String cleanupApproxSize(int count, String size);

  /// Sottotitolo della voce Cache di Drive: numero di capitoli e spazio occupato. {size} è già formattato
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 capitolo} other{{count} capitoli}} · {size}'**
  String cleanupExactSize(int count, String size);

  /// Sottotitolo della voce dei capitoli su Drive: numero, spazio approssimativo; finiscono nel cestino di Drive, non sono cancellati subito. {size} è già formattato
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 capitolo} other{{count} capitoli}} · circa {size} · nel cestino'**
  String cleanupApproxSizeTrash(int count, String size);

  /// Interruttore del foglio «Libera spazio»: non riproporre la pulizia per questa serie
  ///
  /// In it, this message translates to:
  /// **'Non chiedere più per questa serie'**
  String get cleanupQuiet;

  /// Avviso nel foglio «Libera spazio»: i capitoli tolti dal telefono non hanno copia su Drive
  ///
  /// In it, this message translates to:
  /// **'Questa serie non è su Drive: i capitoli cancellati non si potranno rileggere finché la sincronizzazione non li riporta.'**
  String get cleanupWarnNotOnDrive;

  /// Avviso nel foglio «Libera spazio»: i capitoli spariranno sia dal telefono sia da Drive
  ///
  /// In it, this message translates to:
  /// **'Non resteranno né sul telefono né su Drive.'**
  String get cleanupWarnGoneEverywhere;

  /// Avviso nel foglio «Libera spazio»: togliendoli dal telefono restano disponibili su Drive
  ///
  /// In it, this message translates to:
  /// **'I capitoli restano su Drive e si rileggono da lì.'**
  String get cleanupWarnStaysOnDrive;

  /// Avviso nel foglio «Libera spazio» quando si tolgono capitoli da Drive: restano trenta giorni nel cestino; «server» è Kagami Server, che scrive l'indice della libreria
  ///
  /// In it, this message translates to:
  /// **'Dal cestino di Drive si recuperano per trenta giorni. L\'indice del server li elenca ancora: se il server li ricarica, tornano a leggersi da Drive.'**
  String get cleanupWarnTrash;

  /// Pulsante di conferma del foglio «Libera spazio»: cancella le voci scelte
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get cleanupDelete;

  /// Pulsante del foglio «Libera spazio» che rimanda la pulizia senza cancellare
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get cleanupNotNow;

  /// Avviso nel foglio «Libera spazio»: FolderSync è un'app esterna di sincronizzazione che Kagami non controlla
  ///
  /// In it, this message translates to:
  /// **'Se FolderSync sincronizza la cartella in entrambe le direzioni, la cancellazione può arrivare anche su Drive; se scarica soltanto, i capitoli possono tornare al giro seguente.'**
  String get cleanupSyncWarnExternal;

  /// Avviso nel foglio «Libera spazio» quando è attiva la sincronizzazione integrata di Kagami
  ///
  /// In it, this message translates to:
  /// **'La sincronizzazione rispetta questa scelta: quello che togli da una parte non torna e non sparisce dall\'altra, anche con le cancellazioni propagate.'**
  String get cleanupSyncWarnOwn;

  /// Scelta dell'intervallo del grafico delle statistiche: ultimi 30 giorni (segmento stretto, testo corto)
  ///
  /// In it, this message translates to:
  /// **'30 giorni'**
  String get statsRangeMonth;

  /// Scelta dell'intervallo del grafico delle statistiche: ultimi 3 mesi (testo corto)
  ///
  /// In it, this message translates to:
  /// **'3 mesi'**
  String get statsRangeQuarter;

  /// Scelta dell'intervallo del grafico delle statistiche: ultimo anno (testo corto)
  ///
  /// In it, this message translates to:
  /// **'Un anno'**
  String get statsRangeYear;

  /// Titolo della schermata delle statistiche di lettura
  ///
  /// In it, this message translates to:
  /// **'Statistiche'**
  String get statsTitle;

  /// Titolo dell'errore quando le statistiche non si calcolano
  ///
  /// In it, this message translates to:
  /// **'Statistiche non calcolabili'**
  String get statsUnavailable;

  /// Etichetta di un riquadro numerico: totale dei capitoli letti (il numero sta sopra)
  ///
  /// In it, this message translates to:
  /// **'capitoli letti'**
  String get statsChaptersRead;

  /// Etichetta di un riquadro numerico: quante serie ci sono in libreria
  ///
  /// In it, this message translates to:
  /// **'serie in libreria'**
  String get statsSeriesInLibrary;

  /// Valore di un riquadro: tempo di lettura in minuti
  ///
  /// In it, this message translates to:
  /// **'{count} min'**
  String statsMinutes(int count);

  /// Valore di un riquadro: tempo di lettura in ore
  ///
  /// In it, this message translates to:
  /// **'{count} h'**
  String statsHours(int count);

  /// Etichetta del riquadro del tempo totale di lettura
  ///
  /// In it, this message translates to:
  /// **'tempo di lettura'**
  String get statsReadingTime;

  /// Nota sotto il tempo di lettura: il tempo è contato dal lettore
  ///
  /// In it, this message translates to:
  /// **'misurato mentre leggi'**
  String get statsReadingTimeHint;

  /// Etichetta di un riquadro numerico: totale delle pagine (tavole) del manga viste
  ///
  /// In it, this message translates to:
  /// **'tavole viste'**
  String get statsPagesSeen;

  /// Etichetta del riquadro con i giorni consecutivi in cui si è letto
  ///
  /// In it, this message translates to:
  /// **'giorni di fila'**
  String get statsStreak;

  /// Nota sotto i giorni di fila: il record personale
  ///
  /// In it, this message translates to:
  /// **'record: {count}'**
  String statsStreakRecord(int count);

  /// Etichetta del riquadro con la media dei voti dati alle serie
  ///
  /// In it, this message translates to:
  /// **'voto medio'**
  String get statsAverageRating;

  /// Nota sotto il voto medio: quante serie hanno un voto
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 serie votata} other{{count} serie votate}}'**
  String statsRatedSeries(int count);

  /// Titolo del grafico dei capitoli letti nel tempo
  ///
  /// In it, this message translates to:
  /// **'Capitoli letti'**
  String get statsChaptersOverTime;

  /// Sottotitolo del grafico: ogni punto è una settimana
  ///
  /// In it, this message translates to:
  /// **'per settimana'**
  String get statsPerWeek;

  /// Sottotitolo del grafico: ogni punto è un giorno
  ///
  /// In it, this message translates to:
  /// **'per giorno'**
  String get statsPerDay;

  /// Titolo del calendario dell'attività
  ///
  /// In it, this message translates to:
  /// **'Quando leggi'**
  String get statsActivityTitle;

  /// Sottotitolo del calendario dell'attività
  ///
  /// In it, this message translates to:
  /// **'un quadratino per giorno, negli ultimi sei mesi'**
  String get statsActivitySubtitle;

  /// Titolo del grafico a torta delle serie divise per stato di lettura
  ///
  /// In it, this message translates to:
  /// **'La libreria per stato'**
  String get statsShelfTitle;

  /// Fetta del grafico dei generi che raggruppa tutti gli altri generi; {count} è quanti generi raggruppa
  ///
  /// In it, this message translates to:
  /// **'Altri {count}'**
  String statsGenreOthers(int count);

  /// Titolo del grafico a torta dei generi
  ///
  /// In it, this message translates to:
  /// **'Generi che leggi'**
  String get statsGenresTitle;

  /// Sottotitolo del grafico dei generi: contati solo sulle serie iniziate
  ///
  /// In it, this message translates to:
  /// **'sulle serie che hai iniziato'**
  String get statsGenresSubtitle;

  /// Titolo del grafico della distribuzione dei voti
  ///
  /// In it, this message translates to:
  /// **'Come voti'**
  String get statsRatingsTitle;

  /// Sottotitolo del grafico dei voti
  ///
  /// In it, this message translates to:
  /// **'quante serie per ogni voto'**
  String get statsRatingsSubtitle;

  /// Titolo dell'elenco delle serie con più capitoli letti
  ///
  /// In it, this message translates to:
  /// **'Serie più lette'**
  String get statsTopSeries;

  /// Titolo della sezione con i numeri sulla libreria (capitoli, da leggere, in corso, spazio)
  ///
  /// In it, this message translates to:
  /// **'Com\'è fatta la libreria'**
  String get statsShapeTitle;

  /// Etichetta di un riquadro: capitoli presenti nella libreria
  ///
  /// In it, this message translates to:
  /// **'capitoli sincronizzati'**
  String get statsSyncedChapters;

  /// Etichetta di un riquadro: capitoli non ancora letti
  ///
  /// In it, this message translates to:
  /// **'ancora da leggere'**
  String get statsStillUnread;

  /// Etichetta di un riquadro: serie non ancora concluse
  ///
  /// In it, this message translates to:
  /// **'serie in corso'**
  String get statsOngoingSeries;

  /// Nota sotto le serie in corso: capitoli noti ma non ancora scaricati
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 capitolo annunciato e non scaricato} other{{count} capitoli annunciati e non scaricati}}'**
  String statsAnnouncedMissing(int count);

  /// Etichetta di un riquadro: spazio occupato dalla libreria sul telefono (il valore è in GB)
  ///
  /// In it, this message translates to:
  /// **'occupati sul telefono'**
  String get statsBytesOnPhone;

  /// Messaggio al posto del grafico quando non ci sono letture nel periodo
  ///
  /// In it, this message translates to:
  /// **'Niente di letto in questo periodo. La cronologia parte da quando l\'app ha cominciato a registrarla.'**
  String get statsNoHistory;

  /// Errore: si prova a usare Google Drive ma non è stata collegata nessuna cartella/account.
  ///
  /// In it, this message translates to:
  /// **'Drive non è collegato'**
  String get dataDriveNotLinked;

  /// Errore mostrato scaricando un capitolo che non risulta nell'indice della serie su Google Drive.
  ///
  /// In it, this message translates to:
  /// **'Capitolo non trovato su Drive'**
  String get dataChapterNotOnDrive;

  /// Errore scaricando un capitolo da Google Drive che non contiene pagine (tavole).
  ///
  /// In it, this message translates to:
  /// **'Il capitolo non ha tavole su Drive'**
  String get dataChapterNoPagesOnDrive;

  /// Errore: una tavola (pagina di manga) non si trova su Google Drive.
  ///
  /// In it, this message translates to:
  /// **'Tavola non trovata su Drive'**
  String get dataPageNotOnDrive;

  /// Errore interno mostrato se il precaricamento di una tavola da Drive è stato annullato.
  ///
  /// In it, this message translates to:
  /// **'Precarico annullato'**
  String get dataPrefetchCancelled;

  /// Errore: l'utente o Google ha rifiutato il permesso di accedere a Google Drive.
  ///
  /// In it, this message translates to:
  /// **'Google non ha concesso l\'accesso a Drive'**
  String get dataDriveAccessDenied;

  /// Errore offline: manca la rete e la libreria di Google Drive non è mai stata letta su questo telefono, quindi non c'è copia locale.
  ///
  /// In it, this message translates to:
  /// **'Senza connessione, e la libreria su Drive non è mai stata aperta su questo telefono'**
  String get dataDriveOfflineNeverOpened;

  /// Messaggio: c'è una cartella di Drive scelta ma nessun account Google con cui leggerla.
  ///
  /// In it, this message translates to:
  /// **'Accedi con Google per leggere la libreria su Drive'**
  String get dataDriveSignedOut;

  /// Esito della sincronizzazione: non è stata scelta la cartella del telefono, quella di Drive o la direzione.
  ///
  /// In it, this message translates to:
  /// **'Manca la cartella o la direzione'**
  String get dataSyncMissingFolderOrDirection;

  /// Esito generico di una sincronizzazione (cartella del telefono con Drive o dati dell'account) fallita.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione non riuscita'**
  String get dataSyncFailed;

  /// Esito della sincronizzazione: la cartella del telefono non è leggibile.
  ///
  /// In it, this message translates to:
  /// **'La cartella del telefono non si legge'**
  String get dataSyncFolderUnreadable;

  /// Errore: si avvia una sincronizzazione mentre un'altra è già in corso (nell'app o nel lavoro programmato).
  ///
  /// In it, this message translates to:
  /// **'Una sincronizzazione è già in corso'**
  String get dataSyncBusy;

  /// Esito di una sincronizzazione fermata dall'utente.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione interrotta'**
  String get dataSyncCancelled;

  /// Direzione della sincronizzazione: solo da Google Drive al telefono.
  ///
  /// In it, this message translates to:
  /// **'Da Drive'**
  String get dataSyncDirectionDownload;

  /// Direzione della sincronizzazione: solo dal telefono a Google Drive.
  ///
  /// In it, this message translates to:
  /// **'Verso Drive'**
  String get dataSyncDirectionUpload;

  /// Direzione della sincronizzazione: in tutte e due le direzioni, telefono e Drive.
  ///
  /// In it, this message translates to:
  /// **'Entrambe'**
  String get dataSyncDirectionBoth;

  /// Titolo della notifica di invito: un altro utente ha ammesso l'account al suo Kagami Server.
  ///
  /// In it, this message translates to:
  /// **'{sender} ti ha dato accesso al suo server'**
  String dataServerInviteTitle(String sender);

  /// Testo della notifica di invito a un Kagami Server: il server scarica i manga sul Drive dell'utente.
  ///
  /// In it, this message translates to:
  /// **'Collega «{serverName}» e scaricherà i manga sul tuo Drive, anche a telefono spento.'**
  String dataServerInviteText(String serverName);

  /// Messaggio: per usare Kagami Server serve essere entrati con l'account Google.
  ///
  /// In it, this message translates to:
  /// **'Fai l\'accesso con Google per usare il server.'**
  String get dataServerSignInRequired;

  /// Errore: si prova a usare Kagami Server ma non ne è stato collegato nessuno.
  ///
  /// In it, this message translates to:
  /// **'Nessun server collegato.'**
  String get dataServerNotLinked;

  /// Errore dopo aver ammesso un account al server: l'invito automatico non è partito, l'utente deve passare l'indirizzo a mano.
  ///
  /// In it, this message translates to:
  /// **'{email} può usare il server, ma non sono riuscito ad avvisarlo: mandagli tu l\'indirizzo {url}.'**
  String dataServerUserNotNotified(String email, String url);

  /// Titolo del selettore di cartelle di sistema quando si sceglie dove sta la libreria di manga.
  ///
  /// In it, this message translates to:
  /// **'Scegli la cartella della libreria manga'**
  String get dataPickLibraryFolderTitle;

  /// Errore: il metodo di accesso con Google non è abilitato nel progetto Firebase.
  ///
  /// In it, this message translates to:
  /// **'L\'accesso con Google non è ancora attivo su questo progetto'**
  String get dataCloudSignInNotEnabled;

  /// Errore di rete nell'accesso o nella sincronizzazione dell'account: il telefono è offline.
  ///
  /// In it, this message translates to:
  /// **'Nessuna connessione'**
  String get dataCloudNoConnection;

  /// Errore: si tenta di sincronizzare i dati dell'account senza essere entrati.
  ///
  /// In it, this message translates to:
  /// **'Nessun accesso'**
  String get dataCloudNoSignIn;

  /// Errore tecnico dell'accesso con Google: manca il token di identità.
  ///
  /// In it, this message translates to:
  /// **'Google non ha dato un token di identità'**
  String get dataCloudNoIdentityToken;

  /// Errore generico dell'accesso all'account.
  ///
  /// In it, this message translates to:
  /// **'Accesso non riuscito'**
  String get dataCloudSignInFailed;

  /// Errore: la finestra di accesso con Google è stata interrotta.
  ///
  /// In it, this message translates to:
  /// **'Accesso interrotto'**
  String get dataCloudSignInInterrupted;

  /// Errore: l'app non è registrata correttamente per l'accesso con Google.
  ///
  /// In it, this message translates to:
  /// **'Google non è configurato per questa app'**
  String get dataCloudGoogleNotConfigured;

  /// Errore generico dell'accesso con Google.
  ///
  /// In it, this message translates to:
  /// **'Accesso con Google non riuscito'**
  String get dataCloudGoogleSignInFailed;

  /// Testo della notifica Android che avvisa di capitoli nuovi in una serie (il titolo della notifica è il nome della serie).
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{È arrivato un capitolo nuovo} other{Sono arrivati {count} capitoli nuovi}}'**
  String dataNewChaptersNotification(int count);

  /// Errore di «Scarica un manga»: la destinazione è il telefono ma non c'è una cartella scelta.
  ///
  /// In it, this message translates to:
  /// **'Manca la cartella del telefono.'**
  String get dataArchivePhoneFolderMissing;

  /// Errore di «Scarica un manga»: la destinazione è Drive ma non c'è una cartella di Drive scelta.
  ///
  /// In it, this message translates to:
  /// **'Manca la cartella di Drive.'**
  String get dataArchiveDriveFolderMissing;

  /// Nome di un capitolo numerato in elenco, per esempio «Capitolo 70.5».
  ///
  /// In it, this message translates to:
  /// **'Capitolo {number}'**
  String dataChapterLabel(String number);

  /// Problema della cartella della libreria: non esiste o non si può leggere.
  ///
  /// In it, this message translates to:
  /// **'La cartella non esiste o non è leggibile.'**
  String get dataLibraryMissing;

  /// Problema della cartella della libreria: manca il file indice library.json (nome di file, da non tradurre).
  ///
  /// In it, this message translates to:
  /// **'La cartella non contiene library.json: vanno rigenerati gli indici con l\'archiviatore che ha scritto la libreria.'**
  String get dataLibraryNotIndexed;

  /// Problema della cartella della libreria: library.json (nome di file) è illeggibile o non è nel formato MALF.
  ///
  /// In it, this message translates to:
  /// **'library.json non è leggibile o non è un indice MALF valido.'**
  String get dataLibraryUnreadable;

  /// Problema della cartella della libreria: il formato è più nuovo di quello che l'app capisce, serve aggiornare l'app.
  ///
  /// In it, this message translates to:
  /// **'library.json usa una versione del formato più recente di questa app.'**
  String get dataLibraryUnsupported;

  /// Modalità di lettura: scorrimento verticale continuo.
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get dataReaderModeContinuous;

  /// Modalità di lettura: una tavola per volta.
  ///
  /// In it, this message translates to:
  /// **'Paginata'**
  String get dataReaderModePaged;

  /// Direzione di lettura in modalità paginata: da sinistra a destra.
  ///
  /// In it, this message translates to:
  /// **'Sinistra → destra'**
  String get dataReaderDirectionLtr;

  /// Direzione di lettura in modalità paginata: da destra a sinistra (stile manga).
  ///
  /// In it, this message translates to:
  /// **'Destra → sinistra'**
  String get dataReaderDirectionRtl;

  /// Adattamento della tavola allo schermo: alla larghezza.
  ///
  /// In it, this message translates to:
  /// **'Larghezza'**
  String get dataReaderFitWidth;

  /// Adattamento della tavola allo schermo: all'altezza.
  ///
  /// In it, this message translates to:
  /// **'Altezza'**
  String get dataReaderFitHeight;

  /// Adattamento della tavola allo schermo: dimensione originale del file.
  ///
  /// In it, this message translates to:
  /// **'Originale'**
  String get dataReaderFitOriginal;

  /// Colore di sfondo attorno alla tavola nel lettore: nero.
  ///
  /// In it, this message translates to:
  /// **'Nero'**
  String get dataReaderBackgroundBlack;

  /// Colore di sfondo attorno alla tavola nel lettore: grigio.
  ///
  /// In it, this message translates to:
  /// **'Grigio'**
  String get dataReaderBackgroundGrey;

  /// Colore di sfondo attorno alla tavola nel lettore: bianco.
  ///
  /// In it, this message translates to:
  /// **'Bianco'**
  String get dataReaderBackgroundWhite;

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Fotogrammi {frames} · limite {budget} ms'**
  String readerProbeFrames(String frames, String budget);

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Lenti UI {build} (max {buildMax} ms) · GPU {raster} (max {rasterMax} ms)'**
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  );

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Partiti tardi {late} (max {lateMax} ms)'**
  String readerProbeLate(String late, String lateMax);

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Scorrendo {scroll} · saltati {missed} (buco max {gap} ms)'**
  String readerProbeScroll(String scroll, String missed, String gap);

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Tessere {tiles} · intere {whole} · del telefono {phone} (fatte {phoneMade})'**
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  );

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Native {bands} (texture {textures}) · tavole decodificate {decodes}'**
  String readerProbeNative(String bands, String textures, String decodes);

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Decodifica {decode} ms (max {decodeMax}) · arrivo {arrival} ms (max {arrivalMax})'**
  String readerProbeDecode(
    String decode,
    String decodeMax,
    String arrival,
    String arrivalMax,
  );

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Copia max {copy} ms · GC Android {gc} ({gcMs} ms) · bloccanti {blocking} ({blockingMs} ms)'**
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  );

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Attese da Drive {drive} · ripieghi Dart {fallbacks}'**
  String readerProbeWaits(String drive, String fallbacks);

  /// Riga del riquadro diagnostico di fluidità del lettore (acceso dalle impostazioni, spiegato in settingsProbeInfo1-4): le etichette devono essere le stesse citate lì. Testo compatto, tecnico.
  ///
  /// In it, this message translates to:
  /// **'Correzioni {corrections} · salti {jumps} ({jumped} px)'**
  String readerProbeJumps(String corrections, String jumps, String jumped);

  /// Titolo dell'interruttore del controllo quotidiano dei capitoli nuovi sul server
  ///
  /// In it, this message translates to:
  /// **'Controllo giornaliero dei capitoli nuovi'**
  String get serverCheckDaily;

  /// Sottotitolo del controllo quotidiano acceso: l'ora; {clock} è l'ora già formattata
  ///
  /// In it, this message translates to:
  /// **'Ogni giorno alle {clock}, ora del server'**
  String serverCheckDailyAt(String clock);

  /// Sottotitolo del controllo quotidiano del server spento
  ///
  /// In it, this message translates to:
  /// **'Spento: i capitoli nuovi si scaricano solo a mano'**
  String get serverCheckDailyOff;

  /// Titolo dell'interruttore che fa controllare al server tutte le serie della libreria su Drive
  ///
  /// In it, this message translates to:
  /// **'Tutta la libreria su Drive'**
  String get serverCheckLibrary;

  /// Sottotitolo dell'interruttore della libreria intera, acceso
  ///
  /// In it, this message translates to:
  /// **'Anche le serie scaricate dal telefono o da altri, non solo dal server'**
  String get serverCheckLibraryOn;

  /// Sottotitolo dell'interruttore della libreria intera, spento
  ///
  /// In it, this message translates to:
  /// **'Solo le serie in corso scaricate dal server'**
  String get serverCheckLibraryOff;

  /// Esito dell'ultimo controllo del server; {when} è già formattato (es. «ieri alle 4:00»), {count} le serie con capitoli nuovi
  ///
  /// In it, this message translates to:
  /// **'Ultimo controllo {when}: {count, plural, =0{nessun capitolo nuovo} =1{1 serie con capitoli nuovi} other{{count} serie con capitoli nuovi}}'**
  String serverCheckLast(String when, int count);

  /// Titolo del selettore dell'ora del controllo quotidiano del server
  ///
  /// In it, this message translates to:
  /// **'Ora del controllo'**
  String get serverCheckTimeHelp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'es',
    'fr',
    'hi',
    'it',
    'ja',
    'pt',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
