# Checkpoint verifiche — 2026-09-08

Checkpoint richiesto dall'utente prima di proseguire. Nessuna nuova funzionalità aggiunta nel turno di checkpoint. Risultati ricavati dai test e dalle build già terminati; non equivalgono alla prima versione giocabile completa.

## Stato delle operazioni

Alla verifica non risultano installazioni, esportazioni o test attivi. Restano in esecuzione `python3 -m http.server 8000 --bind 0.0.0.0 --directory build/web` e `node server.mjs` (porta 8001). Lasciati attivi senza interromperli. Nessuna porta resa pubblica, nessun deployment esterno. Il repository remoto è stato verificato privato.

## Implementato

Godot 4.7.2 e template corrispondenti, GDExtension WebRTC 1.2.1, script setup/import/test/export/preview, configurazione Codespaces. Arena e silhouette originali sostituibili; selezione Leonida/Tesla, movimento e salto. Lobby a due posti con codice, pronto e gate build/contenuti, signaling separato, endpoint HTTPS/WSS derivato dal Codespace, ICE configurabile. Input numerati a 60 tick/s, predizione limitata, snapshot profondi, restore/risimulazione, reinvio input recenti, checksum confermati, RTT e diagnostica. Errori/disconnessioni e timeout implementati; copertura dettagliata sotto.

## Test automatici conclusi

| Verifica | Risultato e limite |
|---|---|
| Import script e suite `scripts/test.sh` | Passata; wrapper CLI rileva errori Godot anche con exit code zero |
| Replay deterministico | 600 tick, snapshot al tick 100 e replay fino a 600: checksum identico |
| Snapshot completo | Ripristino di risorse, cooldown, effetti, seed, contenitori proiettili/oggetti; questi ultimi non hanno ancora gameplay |
| Rollback | Ritardi di 2/3/5/9 tick, duplicati: 25 rollback per scenario, stesso checksum finale |
| Rete sintetica | RTT 50/100/150 ms tradotto in ritardo unidirezionale, jitter ±1 tick, perdita 10%, riordino e ridondanza: checksum identico; non è traffico reale sottoposto a shaping |
| Limite predizione | Arresto dopo 12 tick senza input confermati verificato |
| Lobby Node | Creazione/ingresso, versione incompatibile, stanza piena, pronto, relay SDP, disconnessione: passati |
| WebRTC nativo | Due peer nello stesso processo Linux, canale bidirezionale con tick 42: passato |
| Dipendenza signaling | `npm audit` dopo aggiornamento a ws 8.21.3: zero vulnerabilità riportate al momento del controllo |

Checksum del replay di riferimento: `556df070167ad8eb7b20eb82f2939a78cf4cd912d2bf238ed5f71133c0d2ac50`.

## Integrazione sulla stessa macchina

- `node tests/browser/smoke.mjs`: due contesti Chromium headless nel Codespace, creazione/ingresso tramite UI, pronto, WebRTC, movimento trasmesso e chiusura peer. Passato sulla build finale; desync 0 su entrambi, rollback osservato (2 sul secondo client). Le snapshot correnti possono avere checksum differenti perché appartengono a tick diversi: il codice confronta soltanto tick confermati corrispondenti.
- `node tests/browser/cross-platform.mjs`: Chromium web + processo Godot Linux nativo, stessa macchina e signaling. Passato sulla build finale, tick confermato 182, desync 0. Non prova macOS, Windows o reti diverse.
- Screenshot della UI ispezionato; arena e silhouette visibili. Screenshot e log restano artefatti locali esclusi da Git.
- Rendering Chromium headless software lento (screenshot iniziale: circa 4 FPS, frame 137 ms). Non è una misura rappresentativa della GPU del Mac e non soddisfa la validazione dei 60 FPS richiesti. Telemetria disponibile per il collaudo reale.

## Export e avvio

- Web: esportazione conclusa e build eseguita nei test Chromium.
- Linux x86_64: esportazione conclusa, include PCK e libreria WebRTC; avvio headless dell'eseguibile verificato durante la sessione. Integrazione browser/native verificata usando il motore Linux e lo stesso progetto, non una sessione grafica desktop distribuita.
- macOS universale: ZIP esportato con app e framework WebRTC. Non eseguito sul Mac, non firmato/notarizzato. Durante la rigenerazione Godot ha segnalato l'indisponibilità dei comandi di cestino (`gio`/`kioclient5`/`gvfs-trash`); l'esportazione ZIP è comunque arrivata a completamento. Nel checkpoint `unzip -t` ha verificato l’integrità dello ZIP senza errori. Non trattare questo come verifica di avvio macOS.

## Non verificato / mancante

- Due dispositivi fisici su reti diverse, NAT traversal reale e percorso TURN selezionato.
- Servizio STUN/TURN e credenziali: default ICE vuoto, istruzioni precise in NETWORKING.md.
- Accesso di un amico esterno agli URL privati Codespaces; nessuna pubblicazione autorizzata/eseguita.
- 60 FPS stabili sul Mac; Safari e controller.
- Timeout wall-clock e tutti i casi di pacchetti malformati non hanno ancora copertura automatica completa; disconnessione e limite di predizione sì.
- Pacing/sincronizzazione clock di produzione, test lunghi, recovery/reconnect.
- Attacchi/parata/combo/speciali, collisioni di combattimento, round/timer/risultato/rivincita, controller/rimappatura, animazioni complete, audio/effetti deduplicati. Rettangoli H solo diagnostici, non hurtbox operative.
- Il rollback verificato riguarda questo piccolo stato/movimento, non il futuro combattimento completo. Nessuna integrazione Steam.

## Ripresa

Seguire README.md per avvio e test. Prima di dichiarare M0 validata multi-rete, completare accessi e STUN/TURN e misurare il Mac. Prossima implementazione pianificata: M1 della ROADMAP, senza avviarla nel checkpoint.

## Correzione signaling successiva al checkpoint — 2026-09-08

Segnalazione utente: P1 fermo su “Connessione al signaling…”, P2 disconnesso, anche dopo accesso HTTP alla 8001. Il servizio locale rispondeva sia HTTP sia WebSocket. Non è stato possibile ispezionare la sessione autenticata o il browser reale dell'utente; causa del rifiuto sul suo dispositivo non accertata.

Corretto un difetto verificato nel codice: il messaggio di connessione rimaneva invariato dopo la ricezione della stanza. Ora mostra “Lobby connessa”. Aggiunto timeout per risposta lobby mancante dopo apertura WebSocket, oltre al timeout di apertura; chiusure con fase e codice. Preview migrata da Python HTTP a Node con proxy `/signaling` sulla stessa origine 8000, per eliminare la dipendenza dall'accesso WebSocket fra due domini privati. Il servizio lobby 8001 resta separato e non è stato riavviato. Porte ancora private, nessuno STUN/TURN aggiunto.

Verifiche della correzione:

- `scripts/test.sh`: passata, inclusi tre test Node (lobby; preview/proxy con creazione e ingresso; backend indisponibile con codice 1011), suite deterministica e WebRTC nativo.
- `scripts/build.sh`: nuova build web NETWORK LAB 01.1 esportata.
- `tests/browser/smoke.mjs`: due Chromium sulla stessa macchina attraverso proxy, scambio input, rollback osservato e disconnessione passati, desync 0.
- `tests/browser/cross-platform.mjs`: web attraverso proxy e Linux nativo diretto al servizio, confermato 182, desync 0.
- `tests/browser/signaling-errors.mjs`: risposte WebSocket simulate nel browser; Godot segnala timeout quando il canale apre ma la lobby tace, e segnala codice 1011 quando chiuso. Non è un test di autenticazione del forwarding GitHub.
- Risposta HTTP preview controllata: `Cache-Control: no-store`.

La preview attiva è ora `node services/signaling/preview.mjs` su 8000; `node server.mjs` continua su 8001. Build desktop generate al checkpoint non rigenerate con questa correzione: il codice nativo aggiornato è stato eseguito nel test browser/Linux. Necessario riprovare sul Mac dell'utente con due finestre visibili. TURN, reti reali e FPS rimangono non validati.
