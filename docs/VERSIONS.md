# Versioni fissate — 2026-09-08

| Componente | Versione / fonte |
|---|---|
| Godot | 4.7.2.stable.official.ed1daf0bf, binario Linux x86_64 ufficiale |
| Export templates | 4.7.2.stable, archivio ufficiale; SHA512 in scripts/godot-SHA512-SUMS.txt |
| webrtc-native | 1.2.1-stable, GDExtension Godot 4.3+, SHA256 in scripts/webrtc-SHA256.txt |
| Node osservato | 24.20.0 |
| npm osservato | 11.19.0 |
| Python osservato | 3.14.2 |
| ws | 8.21.3 (lockfile), npm audit: zero vulnerabilità riportate al controllo |
| Playwright test | 1.63.0 (lockfile) |
| Chromium test | 153.0.8010.12, Playwright build 1243 |

Il devcontainer seleziona Node 24/Python 3.14 (patch immagine aggiornabili); `.nvmrc` fissa il Node osservato per chi usa nvm. Engine, template e pacchetti npm sono fissati esattamente. Setup usa curl, unzip, Python e npm. I binari restano ignorati da Git.

Spazio iniziale circa 19 GB liberi. Download Godot/template/native circa 1.4 GB, motore estratto 140 MB, estensione 88 MB; template installati anche nella directory dati di Godot. I browser test e le loro dipendenze sono opzionali. Nessun download richiesto sul Mac per la prova web.
