# Roadmap verificabile

## Fase 5 — 2026-09-10

- [x] Comandi nei dati con ID, mossa, validità, priorità e sequenze orizzontali.
- [x] Buffer light 4 tick, fronte singolo, consumo una volta e scadenza limitata.
- [x] Confini recovery/stun, KO/reset, sequenze/pareggi e rollback correttivo.
- [x] Regressione golden con valid_ticks=1, comportamento buffer nuovo testato separatamente.

Schema 3/lab-5. Restano escluse speciali, nuove animazioni, proiettili, nuovi bit di input e modifiche al trasporto. Istruzioni di collaudo in docs/MOVES.md.

## Fase 4 — 2026-09-09

- [x] Rettangoli interi relativi al fighter, finestre a intervalli e variazioni hurtbox.
- [x] Light migrata con bordi stretti, tempi/danno/portata preservati.
- [x] ID deterministico istanza e registro per gruppi/bersagli; multi-hit solo nei test.
- [x] Test orientamento/bordi/finestre, deduplicazione, nuove istanze, registro e rollback.

Schema 2 e lab-4. Restano futuri command buffer, nuove mosse giocabili, proiettili e animazioni; fase successiva non avviata.

## Fase 3 — 2026-09-09

- [x] Risolutore condiviso melee, move_id/behavior_id e validazione.
- [x] Light preservata con confronto golden pre-migrazione; definizione alternativa solo nei test.
- [x] Confini fase, cleanup interruzione/KO/reset e rollback dei due cataloghi.

Documentazione: docs/MOVES.md. Hitbox per frame, command buffer e nuovi behavior rimangono fuori da questa fase.

Revisione di chiusura fase 2: coperti confini simultanei di tick, KO aereo e gate lab-3 prima del match; priorità e limiti documentati in docs/STATE_TRANSITIONS.md. Nessuna modifica a light, rete o regole simulate. Fase 3 non avviata.

## Refactoring fase 2 — 2026-09-09

- [x] Locomozione e azione separate, enum interi e timer stun nello snapshot/checksum.
- [x] Transizioni neutral/movimento/aria/attacco, stun temporanei e KO terminale fino al reset.
- [x] Light preservata; test di divieti, durata stun, KO simultaneo e rollback con ritardi 2/5/9 tick.

Hitstun/blockstun disponibili nel nucleo e testati; collegamento agli effetti delle mosse e comando parata restano futuri. Nessuna nuova mossa o animazione. Compatibilità lab-3, pacchetti invariati. Fase 3 da autorizzare separatamente.

## Checkpoint 2026-09-08

Implementazione sospesa su richiesta dell’utente per salvare il lavoro. Build e test terminati; preview 8000 e signaling 8001 lasciati attivi. Nessuna nuova funzionalità nel turno di checkpoint. M0 ha una base tecnica verificata sulla stessa macchina, ma resta aperta fino ai collaudi reali.

## Correzione accesso signaling — 2026-09-08

Proxy WebSocket sulla stessa origine della preview, servizio lobby ancora separato su 8001; messaggi distinti per apertura, attesa risposta lobby e chiusura con codice. Corretto lo stato “connessione…” che restava mostrato dopo ingresso nella stanza. Collaudo sul browser reale dell’utente ancora necessario.

## M0 — laboratorio tecnico (sessione iniziale)

- [x] Ambiente riproducibile Godot/template e dipendenze native fissate.
- [x] Arena provvisoria, silhouette originali, movimento/salto, build web.
- [x] Lobby privata, codice, selezione e pronto, protocollo/versione.
- [x] Trasporto WebRTC e input per tick, rollback ristretto con test separati.
- [x] STUN/TURN configurabili, timeout e telemetria.
- [x] Export Linux/macOS; esecuzione Linux headless.
- [x] Due contesti Chromium: lobby, WebRTC, movimento, rollback osservato e disconnessione.
- [x] Browser web + processo Linux nativo: input e checksum confermati, desync 0.
- [x] Test sintetici RTT 50/100/150 ms con jitter/perdita, distinti da collaudo rete reale.
- [ ] Esecuzione della build macOS sul sistema di destinazione.
- [ ] Collaudo reale Mac + secondo dispositivo su altra rete, diretto e TURN.
- [ ] 60 FPS misurati sul dispositivo dell'utente.

Lo stato dettagliato delle verifiche è in docs/VALIDATION.md. Questa è una prova tecnica, non la prima versione giocabile completa.

## M1 — vertical slice di combattimento

Primo incremento 2026-09-09: leggero condiviso dai due personaggi, tempi e collisioni nei contenuti, danno, salute visibile e replay/rollback del combattimento. Compatibilità lab-2, build COMBAT LAB 02. M1 resta aperta; prossimo incremento: pesante e parata, poi concatenamento/proiettile e stun.

### Fondazione contenuti — fase 1 completata (2026-09-09)

- [x] Catalogo JSON con `schema_version: 1`, `fighter_id` e `move_id` stabili.
- [x] Riferimenti `default_fighters` e `moves.light` validati, senza più selezione simulata per indici `0/1`.
- [x] Salute iniziale letta dalla definizione del fighter; velocità, salto, hurtbox e mossa restano dati del contenuto.
- [x] Test automatico per schema, campi obbligatori, valori, ID/riferimenti mancanti o duplicati e reset da contenuto.

Questa fase non aggiunge mosse o cambia le regole/protocollo `lab-2`; l'hash del contenuto continua a proteggere l'ingresso fra build differenti. Restano da fare macchina a stati, input buffer e hitbox per frame prima di ampliare sostanzialmente i contenuti.

Una coppia di mosse leggere/pesanti, parata, una concatenazione e un proiettile con startup/active/recovery e hit/hurtbox indipendenti dalle pose. Risorse, cooldown, stun e proiettili nel replay. Input adapter tastiera/controller e rimappatura persistente. Timing/pacing della sessione e test rete con RTT 50/100/150 ms, jitter/perdita, browser/desktop. Uscita: scambio di colpi leggibile online e checksum identici anche dopo rollback con proiettili.

## M2 — prima versione giocabile completa confermata

Due personaggi selezionabili sostituibili, una arena, movimento laterale/salto/parata, leggero/pesante/combo, due speciali distintive per personaggio, salute/timer/indicatori, meglio di tre round, risultato e rivincita concordata, errori e disconnessioni chiari. Animazioni idle/movimento/salto/atterraggio/attacchi/parata/danno/speciali/sconfitta; effetti e audio deduplicati. Tastiera e controller rimappabili. Test reale fra dispositivi/reti diverse con TURN. Prestazioni misurate. Non basta il locale o un bot.

## M3 — contenuti e distribuzione

Bilanciamento e nuovi personaggi/arene, sostituzione asset, miglioramento presentazione, distribuzioni desktop testate per sistema. Packaging, licenze, firme e integrazioni piattaforma documentati separatamente.

## Possibilità future, non implementare adesso

Allenamento/tutorial; matchmaking pubblico; account/profili/statistiche; ranked; replay come funzionalità utente (diverso dal replay tecnico di test); Steam inviti/achievement. Nessun negozio o framework generico anticipato.
