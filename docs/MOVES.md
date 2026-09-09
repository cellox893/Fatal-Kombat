# Mosse guidate dai dati — fase 3

Il risolutore condiviso game/simulation/move_resolver.gd implementa soltanto behavior_id "melee". Non carica script dai contenuti e non seleziona logica tramite nomi dei fighter. La simulazione governa azioni/input/movimento/KO; il risolutore gestisce inizio, fase, collisione melee esistente, danno, singolo impatto e avanzamento mossa.

## Definire una mossa

Inserire in fighters.json, nell'array moves, una definizione con move_id univoco:

```json
{"move_id":"light","behavior_id":"melee","startup":5,"active":3,"recovery":12,
 "damage":8,"reach":72,"bottom":30,"top":90}
```

Il fighter la riferisce con moves.light = "light". La chiave light identifica l'azione collegata al bit 8; il valore può essere un qualsiasi move_id validato. Un nuovo ID melee riusa la stessa logica. Al momento non esistono altri comandi giocabili.

Obbligatori: ID leggibili, behavior noto, durate intere (startup/recovery >= 0, active > 0), danno/portata/top positivi, bottom >= 0 e top > bottom. Riferimenti mancanti, duplicati e behavior sconosciuti sono rifiutati dal catalogo. Eseguire scripts/test.sh prima della build. Non modificare il catalogo durante una sessione.

## Convenzione dei tick

Il tick della pressione è move_tick=0 PRIMA della risoluzione: nessun tick preliminare.

| Fase | Intervallo del tick risolto | Light |
|---|---|---|
| startup | 0 <= t < startup | 0–4 |
| active | startup <= t < startup+active | 5–7 |
| recovery | startup+active <= t < totale | 8–19 |

Dopo collisione e danno si incrementa move_tick. Al totale si cancellano ID, tick e flag hit e si torna neutral. Lo snapshot dopo un tick contiene il prossimo move_tick: la visualizzazione di fase non è prova che quel tick abbia già inflitto danno. Startup zero colpisce sul tick di pressione; recovery zero termina dopo l'ultimo tick attivo. Restrizioni di movimento e nuovo salto durano fino all'ultimo tick risolto; input non rivalutati a fine mossa. Direzione congelata, gravità attiva, un solo impatto e scambi simultanei restano invariati. Priorità complete in STATE_TRANSITIONS.md.

## Runtime, compatibilità ed estensioni

Runtime nel fighter: move (ID), move_tick, hit, facing e action, oltre a posizioni/salute/stati. Sono già inclusi negli snapshot profondi e nel checksum; nessun contatore nascosto nel risolutore. Fase e behavior sono derivati da ID e catalogo immutabile. Hitstun e KO cancellano il runtime tramite la stessa funzione clear; reset ricrea lo stato.

lab-3 resta invariato: regole, protocollo e formato runtime non cambiano. L'aggiunta obbligatoria di behavior_id cambia SHA256 dei byte del catalogo, incluso nel gate pre-match: client precedenti vengono rifiutati per hash diverso. Schema versione 1 è esteso con questo campo obbligatorio; il vecchio catalogo non è valido per il nuovo loader. Il gate confronta dichiarazioni del client, non certifica codice o integrità.

Per aggiungere in futuro un behavior: implementazione deterministica esplicita nel risolutore, ramo di dispatch e allowlist supports aggiornati insieme, validazione specifica dei parametri e test. Eventuale runtime nuovo deve entrare in snapshot/checksum; regole incompatibili richiedono aggiornamento lab-N. Nessun percorso script nei dati.

## Prove e limiti

test_moves.gd confronta una traccia di 720 tick catturata sulla simulazione di 4590713 prima della migrazione: digest 25bdfec7b19f6f648514f92903aef150b79cdc3bebcf1be07aefc625e87e85ab. Quattro scenari coprono input ripetibili, movimento, salto, distanza e KO. Verifica confini delle fasi, cleanup per interruzione/KO/reset, una definizione test_strike soltanto in memoria (2/1/3 tick, danno 13, portata 150), startup/recovery zero, replay snapshot/checksum e rollback 2/5/9 tick su entrambi i cataloghi.

Collisioni rettangolari fisse invariate. Nessuna hitbox per frame, command buffer, speciale, animazione, costo o cooldown di mossa. Nessuna applicazione di hitstun/blockstun da melee; test di stun esercitano esclusivamente lo stato. Il confronto golden riguarda le sequenze dichiarate, non una dimostrazione esaustiva su tutti gli input.
