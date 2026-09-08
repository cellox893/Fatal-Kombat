# Architettura e decisioni

## Confini attuali

- `game/simulation`: GDScript tipizzato, RefCounted senza Node, Input, JavaScriptBridge, fisica o clock. `step([p0,p1])` esegue esattamente un tick. Posizioni e velocità intere, ordine fisso P0/P1; JSON dei contenuti convertito esplicitamente a interi. Tick a 60 Hz.
- `game/content`: configurazione JSON con ID stabili per arena e combattenti. Selezione immutabile prima del tick 0. I nomi non decidono il movimento; ogni definizione sceglie velocità e salto.
- `game/network/rollback.gd`: snapshot profondi, predizione del movimento remoto (non dei pulsanti), correzione e risimulazione; nessun effetto di presentazione.
- `game/network/transport.gd`: WebSocket di signaling, WebRTCDataChannel negoziato ID 1, non ordinato senza ritrasmissioni SCTP; RTT applicativo ping/pong.
- `game/presentation`: menu, campionamento tastiera, vista procedurale, telemetria. È ancora un controller di laboratorio: input e ciclo round verranno estratti prima del combattimento completo. Unico punto browser-specifico: rilevamento endpoint e telemetria test `window.fatalLab`.
- `services/signaling/preview.mjs`: serve la build web su 8000 e inoltra `/signaling` al processo 8001. Stessa origine della pagina per WSS, senza inoltrare credenziali browser; coda e backpressure limitate. Non trasporta input di combattimento.
- `services/signaling`: Node/ws, stato volatile delle stanze, versione, pronto, inoltro SDP/ICE. Non esegue combattimento e non è autorevole.

## Protocollo lab-1

Il server assegna slot 0/1 nell'ordine d'ingresso. Codice casuale di 8 cifre esadecimali, due peer massimi. Handshake `lab-1:SHA256(bytes contenuti)` prima dell'ingresso; aggiornare lab-N a ogni cambiamento incompatibile della simulazione/protocollo. In futuro il build manifest sarà generato automaticamente da codice e contenuti.

Dopo entrambi pronti, lo slot 0 crea l'offerta. I client accodano ICE finché esiste la descrizione remota. Configurazione ICE identica distribuita dalla lobby. Apertura del canale avvia il tick locale 0: il peer in anticipo può predire solo 12 tick. Non è ancora presente un algoritmo completo di sincronizzazione degli orologi: macchine che girano a velocità diversa possono fermarsi e riprendere; introdurre pacing nella prossima milestone.

Input: bit 1 sinistra, 2 destra, 4 salto; 8 riservato. Ogni pacchetto include coppie `[tick, bits]` degli ultimi 120 tick, tick confermato e checksum relativo. Reinvio anche durante lo stallo; gestione duplicati identici, rifiuto conflitti, input fuori range e troppo futuri. La ridondanza copre perdita e riordino, non rende la rete affidabile senza limiti. Snapshot e input vengono potati oltre 120 tick. La predizione si ferma dopo 12 tick non confermati (200 ms); 5 secondi di stallo/interruzione fermano la sessione. Una desincronizzazione ferma la prova con tick diagnostico.

Checksum solo su tick con input di entrambi confermati. Canonicalizzazione con array in ordine fisso, interi e SHA-256. Posizioni intere adesso; prima delle mosse introdurre sottounità fisse se necessarie, senza float nella simulazione. Niente PhysicsBody2D. Casualità: seed riservato nello stato, nessun uso casuale nella prova. Prima di introdurla scegliere e testare un PRNG intero con overflow definito.

## Stato e rollback

Snapshot include tick, seed, posizioni, velocità, input precedente, salute, risorse, cooldown, effetti e contenitori per proiettili/oggetti. Attualmente solo movimento, salto e cooldown hanno un aggiornamento; i contenitori vuoti non significano che le abilità siano implementate. La selezione personaggi è configurazione immutabile della sessione. L'arena usa per ora il piano fisso y=550, da spostare interamente nella definizione contenuti quando verranno aggiunte arene.

La presentazione legge lo stato corrente; non emette audio o particelle durante `step`. Quando verranno introdotti, gli eventi avranno ID deterministici `(round,tick,entity,sequence)` e saranno consumati una sola volta, con politica esplicita per gli effetti speculativi. Sostituire una posa non modifica collisioni o tempi. Il rettangolo H è un overlay dimensionale provvisorio, non una hurtbox già operativa.

## Valutazione delle soluzioni (2026-09-08)

- [Godot 4.7.2 stabile](https://godotengine.org/download/archive/4.7.2-stable/): binario ufficiale, template della stessa release, SHA512 ufficiali registrati. Compatibility, GDScript, web senza thread/GDExtension. [Vincoli web ufficiali](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html): WebGL2, browser compatibile e HTTPS fuori localhost; single thread supportato da Godot 4.3. Prestazioni Safari da misurare sul Mac.
- [webrtc-native 1.2.1](https://github.com/godotengine/webrtc-native/releases/tag/1.2.1-stable): release ufficiale per Godot 4.3+, MIT, dipendenze e licenze nel pacchetto. La release aggiorna libdatachannel a 0.24.5 e mbedTLS a 3.6.7. Installata per desktop, esclusa dal web dove WebRTC è integrato. Avvio e scambio nativo verificati, non si assume compatibilità universale senza test.
- [Netfox](https://github.com/foxssake/netfox): MIT, supporto dichiarato Godot 4.x, repository con release e manutenzione attiva; utile per timing/prediction. [Caveat rollback](https://foxssake.github.io/netfox/latest/netfox/tutorials/rollback-caveats/): gestione della fisica e risimulazione richiedono attenzione. Integrazione web/WebRTC e identità dei checksum non verificate in questo progetto; non installato né dichiarato compatibile per deduzione.
- [Godot Rollback Netcode di Snopek](https://gitlab.com/snopek-games/godot-rollback-netcode): alternativa MIT storicamente usata per rollback; compatibilità/manutenzione dell'esatta release Godot 4.7 non accertata qui, nessuna dipendenza introdotta.
- Decisione reversibile: piccolo rollback specifico per input P2P e simulazione intera, verificato con test. È una prova, non un netcode di produzione completo. Riconsiderare una libreria se il costo di pacing/strumentazione supera il beneficio di questo nucleo ristretto. Nessun motivo sostanziale rilevato per cambiare lo stack richiesto.

## Espansione del combattimento

Prossimi Resources/config: CharacterDefinition, MoveDefinition, ArenaDefinition con ID stabili. Move: startup/active/recovery in tick, danno, hit/hurtbox intere, consumo risorsa, cooldown, effetto, cancellazioni e concatenamenti. Comportamenti piccoli come melee, projectile, barrier, counter-window; evitare switch sul nome del personaggio. Round state separato con timer, vittorie, transizione e rematch concordato. Nuovi personaggi non cambieranno messaggi di input o gestione round.

Leonida: scudo con finestra di contrattacco e avanzata protetta, punibili durante recupero/da attacchi appropriati. Tesla: proiettile elettrico e zona temporanea di controllo, con preparazione leggibile e vulnerabilità ravvicinata. Sono proposte di design da provare, non mosse già presenti.

## Fiducia e piattaforme

P2P permette al peer modificato di mentire sugli input e osservare lo stato. Codice privato e checksum non sono anticheat. Prima di ranked servono threat model, decisione su autorità/arbitraggio, sicurezza, identità e gestione risultati; nessuna classifica ora.

Il futuro desktop condivide simulation e rollback. Isolare input, trasporto, storage e inviti dietro adapter quando servono. Steam richiede packaging per OS/architettura, GDExtension e licenze, firma/notarizzazione macOS, test controller/firewall/performance e integrazione Steamworks autorizzata; non è un export automatico. Nessun SDK Steam o account introdotto.
