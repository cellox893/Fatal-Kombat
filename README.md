# Fatal Kombat

Prototipo di picchiaduro storico 2D online in Godot. Questa prima milestone è un **laboratorio tecnico**: arena, due silhouette selezionabili, movimento/salto, stanza privata, pronto, WebRTC e rollback di prova. Attacchi, speciali, round e rivincita sono nella roadmap, non ancora giocabili.

## Aprire l'anteprima nel Codespace attuale

1. Apri prima [signaling HTTPS, porta 8001](https://humble-carnival-5649pq6qvxf79xr-8001.app.github.dev) e completa l'accesso GitHub. Deve apparire `Fatal Kombat signaling ready`.
2. Apri [Fatal Kombat, porta 8000](https://humble-carnival-5649pq6qvxf79xr-8000.app.github.dev). Se il Codespace cambia nome, usa gli URL nel pannello **Ports**.
3. Primo client: **Crea stanza privata**, copia il codice mostrato. Secondo client, altra finestra/browser: inserisci il codice e premi **Entra**. Scegli Leonida o Tesla su ciascun client, poi entrambi **Pronto**.
4. Attendi `WebRTC connesso`. Clicca l'arena per togliere il focus dai campi. **A/D o frecce**: movimento, **spazio**: salto; **H**: rettangoli diagnostici provvisori. Il peer deve vedere gli stessi movimenti. Tick e confermato avanzano, RTT si aggiorna, desync deve restare 0. I tick correnti dei due client possono differire: i checksum vengono confrontati solo a tick confermati uguali.
5. Chiudi un client: l'altro deve segnalare la disconnessione e fermarsi. Per una nuova stanza ricarica entrambi. Non c'è ancora rivincita.

Le porte restano private. Un amico senza accesso al forwarding può non aprire questi URL: il codice stanza non concede accesso GitHub. Nessuna porta è stata resa pubblica. Con ICE vuoto la connessione è stata verificata solo sulla stessa macchina; per reti differenti serve completare STUN/TURN e accesso all'hosting, vedi [NETWORKING](docs/NETWORKING.md).

## Rigenerare e avviare

Tutto si installa nel Codespace; sul Mac basta il browser con WebGL2. Dal root:

```bash
bash scripts/setup.sh
bash scripts/test.sh
bash scripts/build.sh             # Web → build/web/index.html
bash scripts/preview.sh            # 0.0.0.0:8000, lascia aperto
```

In un secondo terminale:

```bash
npm start --prefix services/signaling  # 0.0.0.0:8001
```

Per STUN/TURN usare `.env` come descritto in [NETWORKING](docs/NETWORKING.md). Nel pannello Ports inoltrare entrambe le porte. Il campo signaling della build web deriva automaticamente **WSS della porta 8001** dall'URL HTTPS del Codespace: non tenta localhost del tester remoto. Se gli URL non seguono il formato Codespaces, incollare manualmente l'endpoint corretto.

I processi della sessione possono terminare quando il Codespace viene sospeso: riavviare i due comandi server. Non sono servizi persistenti.

## Verifiche riproducibili

`scripts/test.sh` importa gli script, verifica snapshot/replay/rollback con input ritardati/duplicati, simulazione di RTT 50/100/150 ms con jitter/perdita, finestra limitata, lobby/versione/pronto/relay/disconnessione e due peer WebRTC nativi nello stesso processo. Errori Godot rendono il comando fallito anche se il motore restituisce zero.

Test browser opzionali (installazione solo Codespace), con i due server avviati:

```bash
npm ci --prefix tests/browser
npx --prefix tests/browser playwright install --with-deps chromium
node tests/browser/smoke.mjs
node tests/browser/cross-platform.mjs
```

Il primo usa due contesti Chromium, il secondo un Chromium e un processo Godot Linux nativo. Non sono test fra due dispositivi fisici. Screenshot generati in `build/`, ignorati da Git. Dettaglio risultati e limiti: [VALIDATION](docs/VALIDATION.md).

## Desktop

```bash
bash scripts/build.sh Linux
build/linux/fatal-kombat.x86_64 --headless --quit-after 3
bash scripts/build.sh macOS
```

Artefatti: `build/linux/` include libreria WebRTC e PCK; `build/macos/fatal-kombat.zip` include app universale e framework WebRTC. Linux avviato headless; macOS esportato ma **non eseguito sul Mac**, non firmato/notarizzato. Distribuire tutto il pacchetto, non il solo eseguibile. Su desktop remoto impostare `SIGNALING_URL=wss://…`; nessuna integrazione Steam ancora. [Architettura](ARCHITECTURE.md) distingue packaging, firma, integrazioni e collaudi commerciali.

## Documenti

- [Brief conservato](docs/BRIEF.md), [roadmap](ROADMAP.md), [architettura e fonti ufficiali](ARCHITECTURE.md).
- [Versioni](docs/VERSIONS.md), [asset e licenze](docs/ASSETS.md), [rete e credenziali mancanti](docs/NETWORKING.md).
- [Istruzioni per lo sviluppo](AGENTS.md).

Prossima milestone: mosse con tempi/hitbox, parata, concatenamento e primo proiettile sottoposti a rollback, insieme a pacing e prove reali web/desktop su reti diverse. Il primo prodotto completo richiederà anche due speciali per personaggio, animazioni complete, controller/rimappatura e ciclo round/risultato/rivincita.
