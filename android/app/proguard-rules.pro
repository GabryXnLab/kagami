# Room crea il database di WorkManager per reflection, dal costruttore senza
# argomenti di WorkDatabase_Impl. La sua regola (`-keep class * extends
# RoomDatabase`) tiene la classe ma non i costruttori, e R8 in full mode —
# il predefinito dell'AGP 9 — li toglie: l'app moriva all'avvio del processo,
# prima ancora di Flutter.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}

# Stessa storia per WorkManager: ogni lavoro crea il suo InputMerger per
# reflection, e la regola del pacchetto (`-keep class * extends
# androidx.work.InputMerger`) non ne tiene il costruttore. Senza, ogni lavoro
# — download, sincronizzazione, controllo dei capitoli nuovi — falliva prima
# di partire, e restava in coda.
-keep class * extends androidx.work.InputMerger {
    <init>();
}
