# Checkpoint verifiche — 2026-09-08

## Refactoring fase 2 — 2026-09-09

Suite scripts/test.sh passata: nuovi test transizioni locomozione/azione, doppio salto vietato, input bloccati durante attacco/stun, interruzione attacco da hitstun, blockstun vietato durante attacco, durata esatta e nessun buffer implicito, atterraggio, inclusione di ogni campo nel checksum, KO simultaneo e reset. Rollback con ritardi 2/5/9 tick attraversa scadenza di hitstun/blockstun inizializzati nei test, attacco e KO; replay identico. Light conserva i test precedenti. Passati anche contenuti, rete sintetica, lobby/proxy e WebRTC nativo bidirezionale.

Nuovo checksum replay 600 tick: e81b41d9f2632854e53dbb9bbce505af7906dff586beda609c5b901c98dee601. Gate lab-3 necessario per evitare confronto con vecchio stato lab-2. Gli stun non sono effetti della light: vengono applicati esplicitamente nei test; nessuna parata giocabile aggiunta.

Build Web passata. Test browser smoke esistente passato: due Chromium, ICE connected, movimento/danno [100, 92], desync 0, disconnessione ferma la simulazione. Cross-platform browser/Linux passato, confermato 187 e desync 0; la libreria nativa ha emesso un warning di invio ICE errno=101 prima della connessione riuscita. Prove sulla stessa macchina: non validano questa revisione su dispositivi/reti fisiche differenti. Nessuna build generata inclusa in Git.

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
- TURN e credenziali: il default ora include STUN senza credenziali per scoprire percorsi diretti; resta assente un relay TURN e restano necessarie credenziali temporanee per NAT/firewall restrittivi, vedi NETWORKING.md.
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

## Ripresa M1 — 2026-09-09, COMBAT LAB 02

Primo incremento: attacco leggero condiviso, hit/hurtbox intere, danno, barra salute e stato mossa negli snapshot/checksum. Compatibilità lab-2. Rimangono esclusi pesante, parata, stun, combo, speciali, KO e round; a salute zero la simulazione continua.

- Suite `scripts/test.sh` passata: startup senza danno, impatto simultaneo, singolo impatto, tasto mantenuto, distanza e separazione verticale, snapshot durante startup e rollback di attacchi con ritardi 2/5/9 tick. Passati anche i precedenti test movimento/rete sintetica, lobby/proxy e WebRTC nativo.
- Nuovo checksum replay movimento 600 tick: `ac2cf9933e9ba6ec109aafee4f8948fd3d5aefe77da5bb9b408bb4c0fd184803`. Cambiato perché lo stato include direzione e mossa.
- Build web e Linux rigenerate con successo. La build macOS del checkpoint è precedente e incompatibile con lab-2; rigenerarla prima di usarla con questi client.
- Primo tentativo nella sandbox fallito per socket e scrittura impostazioni Godot; test/build rieseguiti con autorizzazione nel Codespace.
- Preview Node 8000 e signaling 8001 riavviati. Nessuna modifica alla visibilità delle porte.
- Le verifiche sintetiche RTT 50/100/150 ms rimangono sul replay di movimento; il nuovo scenario di combattimento copre ritardo degli input, senza simulazione aggiuntiva di perdita/jitter.
- `tests/browser/smoke.mjs` passato: due Chromium nello stesso Codespace, movimento fino a portata, J via tastiera, salute [100, 92] su entrambi, desync 0, 26 rollback osservati sul secondo client e arresto dopo disconnessione. Non prova reti diverse.
- `tests/browser/cross-platform.mjs` passato: browser/Linux, tick confermato 184 e desync 0. Questo test rimane sul movimento; non verifica uno scambio di colpi web/native.
- `tests/browser/signaling-errors.mjs` passato: timeout lobby silenziosa e chiusura 1011.

## Fondazione contenuti — fase 1, 2026-09-09

Il catalogo combattimento è stato convertito a schema JSON versione 1: fighter e mosse hanno rispettivamente `fighter_id` e `move_id`; `default_fighters` e la mossa leggera di ogni fighter sono riferimenti espliciti. La simulazione usa ID anziché indici di array e il reset legge `health` dalla definizione selezionata. Velocità, salto, hurtbox e mossa continuano a essere letti dalle definizioni validate.

- `game/tests/test_content.gd`: passato. Copre catalogo base, versione schema, ID duplicati o mancanti, riferimento a mossa/fighter inesistente, valore non valido e campo obbligatorio assente.
- `game/tests/test_simulation.gd`: passato. Include ora selezione tramite ID stabili, rifiuto atomico di un fighter inesistente e salute iniziale dai dati, oltre a replay, snapshot e rollback esistenti.
- `scripts/test.sh`: passato integralmente, inclusi signaling Node e due peer WebRTC nativi. Il checksum replay di riferimento resta `ac2cf9933e9ba6ec109aafee4f8948fd3d5aefe77da5bb9b408bb4c0fd184803`.

`node tests/browser/smoke.mjs` è passato sulla build Web rigenerata: due Chromium hanno raggiunto `connected`, scambiato candidati ICE, movimento e danno con `desyncs: 0`; la chiusura del peer ha fermato la simulazione. Non è una prova aggiuntiva di reti fisiche differenti. WebRTC, signaling, pacchetti e configurazione ICE non sono stati cambiati in questa fase.

## Correzione collaudo LAN — 2026-09-09

Il signaling ora consegna come default il solo STUN `stun:stun.cloudflare.com:3478`; non inoltra input né abilita TURN. Aggiunta telemetria dei candidati ICE locali/remoti in `window.fatalLab` e nel messaggio di timeout, per distinguere un blocco della negoziazione dall'assenza di candidati. Questa scelta mira a rendere verificabile il percorso P2P diretto fra browser sulla stessa LAN; non è una prova che ogni router, Wi-Fi guest, VPN o firewall lo permetta.

- `scripts/test.sh`: passata dopo la modifica (simulazione, signaling e WebRTC nativo).
- Build Web: esportata con successo.
- `node tests/browser/smoke.mjs`: passato contro la build aggiornata; due contesti Chromium hanno scambiato 2 candidati locali/remoti ciascuno, raggiunto WebRTC connesso, movimento e danno con desync 0. È un collaudo nello stesso Codespace, non due dispositivi fisici sulla LAN dell'utente.

## Diagnostica ICE per test LAN — 2026-09-09

Per il web, la configurazione effettiva della `RTCPeerConnection` dichiara `iceTransportPolicy: "all"`; non esiste una policy `relay`. Il canale dati negoziato viene creato prima dell'offerta; listener SDP/ICE sono già registrati prima dell'offerta, candidati remoti arrivati prima della SDP restano accodati, e l'evento di raccolta completa viene ora inoltrato come `ice-complete` diagnostico. Il proxy browser usa `wss://<host-8000>/signaling`; soltanto il proxy usa `ws://127.0.0.1:8001` internamente.

La UI e `window.fatalLab` riportano gathering/connection state, contatori e tipi ICE locali/remoti, fine raccolta locale/remota ed eventi recenti. Il preview inserisce inoltre una sonda prima del runtime Godot, che registra sull'oggetto `RTCPeerConnection` reale `iceGatheringState`, `iceConnectionState`, `connectionState`, ogni `onicecandidate` (incluso il candidato nullo finale) e `onicecandidateerror` nel console log con prefisso `Fatal Kombat WebRTC`.

- `scripts/test.sh`: passato.
- Build Web: esportata con successo.
- `node tests/browser/smoke.mjs`: passato con asserzioni su `iceTransportPolicy: all`, candidati `host` e `srflx`, evento finale ICE, gathering `complete`, stati browser ICE/connection `connected`, `ice-complete` nei due versi, movimento/danno e desync 0. Non sostituisce ancora la prova reale sul Mac/LAN dell'utente.
