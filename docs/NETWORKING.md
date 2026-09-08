# Rete, Codespaces e TURN

## Anteprima privata

Le porte 8000 (HTTP statico) e 8001 (WebSocket signaling) ascoltano su 0.0.0.0. Nel browser remoto si usano gli URL inoltrati HTTPS/WSS, non il suo localhost. Il client deriva il dominio della porta 8001 sostituendo `-8000.` nell'host Codespaces; per altri hosting modificare il campo endpoint prima di creare/entrare. La build desktop legge `SIGNALING_URL`, con fallback localhost soltanto per sviluppo locale.

In Codespaces aprire il pannello Ports, aggiungere 8000 e 8001 se assenti, mantenere la visibilità Private. Prima aprire in ogni browser l'URL HTTPS della 8001 e completare l'autenticazione GitHub; deve apparire `Fatal Kombat signaling ready`. Poi aprire la 8000. Il WebSocket non può presentare una schermata di login interattiva: un redirect di autenticazione si manifesta come errore di connessione.

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
