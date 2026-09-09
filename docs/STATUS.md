# Stato corrente

Revisione di chiusura fase 2: [transizioni e priorità](STATE_TRANSITIONS.md). Nessuna correzione delle regole necessaria; aggiunti test per atterraggio/scadenza/danno simultanei, KO in volo e rifiuto versione/contenuti prima del match. La fase 3 resta non avviata.

## Fase 2 — macchina a stati deterministica (2026-09-09)

Locomozione intera separata (IDLE, MOVING, AIRBORNE) e azione intera (NEUTRAL, ATTACK, HITSTUN, BLOCKSTUN, KO). Entrambe, insieme a stun_ticks, sono incluse negli snapshot profondi e nel checksum. La light conserva startup/active/recovery, danno, direzione, singolo impatto e scambi simultanei.

Hitstun e blockstun sono transizioni della simulazione con durata esplicita, esercitate dai test tramite apply_stun; la light non le applica e non esiste ancora un comando di parata. Una futura mossa dovrà applicarle dentro step affinché l'evento venga riprodotto durante rollback; chiamarle dalla presentazione durante una partita non è supportato. Lo stun blocca input per N tick, interrompe l'attacco e mantiene la gravità; blockstun non può cancellare attacco/hitstun. Nessun input buffer introdotto.

A salute zero il fighter entra in KO dopo la risoluzione di entrambi gli attacchi, resta soggetto alla gravità e non può muoversi o attaccare fino al reset. Non è un sistema round/risultati. Gate compatibilità lab-3 per stato/checksum nuovi; formato pacchetti, WebRTC, signaling e rollback invariati. Ricaricare entrambi i client; vecchie build lab-2 vengono rifiutate. Fase 3 non avviata.

## Fase 1 — modello contenuti stabilizzato (2026-09-09)

Completata la prima fase del refactoring dei contenuti. `fighters.json` usa ora `schema_version: 1`, `fighter_id`, `move_id` e `default_fighters` con riferimenti espliciti. `FightContent` carica, indicizza e valida i dati prima della simulazione; i fighter della sessione sono ID leggibili, non indici dell'array.

La simulazione usa salute, velocità, salto, hurtbox e riferimenti alle mosse dalle definizioni validate. In particolare il reset inizializza la salute dal campo `health` del fighter selezionato. La compatibilità resta `lab-2` perché il protocollo e le regole effettive non sono cambiati; l'hash dei contenuti nel gate lobby cambia con il nuovo file.

Non sono stati modificati WebRTC, signaling, rollback, pacchetti input, TURN, animazioni o contenuti di combattimento. La prossima fase autorizzabile è la macchina a stati simulata; non è inclusa qui.
