# Rete, Codespaces e TURN

## Anteprima privata

La porta 8000 serve la build e un proxy WebSocket sul percorso `/signaling`. Il servizio lobby rimane un processo separato su 8001. Entrambi ascoltano su 0.0.0.0; il browser usa `wss://<host-del-gioco>/signaling`, il proxy raggiunge `ws://127.0.0.1:8001` dal Codespace. Nessun localhost del tester e nessun cookie GitHub inoltrato al servizio interno. Il percorso del combattimento resta WebRTC P2P, non passa dal proxy.

In Codespaces mantenere visibilità Private. Per il browser basta inoltrare/aprire la 8000 e completare l'accesso GitHub in ciascun browser. La precedente build usava direttamente il dominio della 8001: aprire la pagina HTTP di quel dominio non prova l'upgrade WebSocket da un'altra origine. Il proxy elimina tale dipendenza; non è una prova che questa fosse l'unica causa del problema sul Mac dell'utente. Il titolo NETWORK LAB 01.1 identifica la build aggiornata; risposte statiche `Cache-Control: no-store` evitano cache obsolete. Non pubblicata alcuna porta.

La build desktop legge `SIGNALING_URL` e può usare lo stesso URL WSS con `/signaling`, oppure direttamente la 8001 quando accessibile; il fallback localhost vale solo per sviluppo locale.

Messaggi diagnostici: apertura WebSocket (timeout 15 s), richiesta lobby dopo apertura (timeout 10 s), lobby connessa, negoziazione WebRTC. Le chiusure indicano fase e codice; il codice 1011 del proxy indica un problema del servizio a monte, mentre una chiusura anomala prima dell'apertura non identifica da sola la causa. Un controllo HTTP “ready” non sostituisce un test WebSocket. Tenere entrambe le finestre visibili per evitare sospensione del ciclo Godot in background ([documentazione Godot](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html#background-processing)).

L'accesso al repository non garantisce l'accesso al forwarding privato del proprietario. Un tester senza accesso al Codespace può essere bloccato prima di raggiungere la lobby. Non abbiamo reso pubbliche le porte né distribuito servizi esterni. Per amici esterni servirà una decisione esplicita: autorizzare la visibilità di test o distribuire HTTPS/WSS su hosting autorizzato. Il codice invito non supera le restrizioni di accesso GitHub.

## Configurazione ICE

Default `ICE_SERVERS_JSON=[]`: candidati host, utili nei test sullo stesso computer/LAN; non promette collegamento fra reti diverse. Procurare:

1. URL STUN del servizio scelto, per esempio `stun:host:3478`.
2. URL TURN raggiungibili pubblicamente, preferibilmente UDP e TCP, più TLS se disponibile.
3. Username e credential TURN temporanei, scadenza, eventuali limiti traffico/regioni.
4. Per self-hosting: VPS/IP pubblico, DNS/TLS, autorizzazione e accessi di gestione, porte listener e intervallo relay UDP configurati sul firewall. Il forwarding Codespaces HTTP non sostituisce TURN.

Nessun servizio pagato attivato e nessuna credenziale inventata. Copiare `services/signaling/.env.example` in `.env` nella stessa cartella, sostituire i segnaposto, poi riavviare il servizio:

```bash
cd services/signaling
node --env-file=.env server.mjs
```

Le credenziali di connessione vengono consegnate ai partecipanti; usare credenziali brevi e limitate, mai una chiave amministrativa o il segreto master di emissione. Per deployment persistente serviranno emissione server-side a scadenza, limiti accesso/origine, monitoraggio e lifecycle delle stanze. Il servizio attuale ha limite payload, frequenza messaggi, cap connessioni e heartbeat; è un laboratorio privato, non un servizio pubblico pronto alla produzione.

[Configurazione ufficiale Godot](https://docs.godotengine.org/en/stable/classes/class_webrtcpeerconnection.html#class-webrtcpeerconnection-method-initialize): `iceServers`, `urls`, `username`, `credential`. Non assumiamo che `iceTransportPolicy` sia disponibile e identico nel wrapper Godot e nel plugin nativo: non è tra le opzioni documentate.

## Piano diretto / relay

Test diretto reale: Mac Wi-Fi e altro dispositivo su rete mobile o diversa, entrambi su HTTPS/WSS autorizzati. Creare stanza, scegliere/pronto, muovere/saltare, annotare tick/RTT/rollback/desync per almeno 5 minuti, disconnettere il secondo peer. Registrare browser, OS, rete e frame time.

Test TURN reale: fornire ICE TURN valido e utilizzare una rete/firewall di test che impedisca il percorso diretto. In Chromium aprire `chrome://webrtc-internals` prima del match e verificare il tipo `relay` della coppia selezionata; verificare traffico/allocation anche nei log del TURN. La semplice presenza di candidati relay non prova che siano stati usati. Se occorre forzare relay dal client, aggiungere e verificare prima un adapter specifico; non dichiarare completata questa prova con una sola connessione riuscita.

Gli attuali test di jitter/perdita sono una coda sintetica di input in GDScript, non emulazione del traffico UDP reale. Successivamente test con shaper di rete autorizzato e RTT end-to-end misurato. Nessuna prova TURN o multi-rete eseguita in questa sessione.
