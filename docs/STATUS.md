# Stato corrente

## Fase 1 — modello contenuti stabilizzato (2026-09-09)

Completata la prima fase del refactoring dei contenuti. `fighters.json` usa ora `schema_version: 1`, `fighter_id`, `move_id` e `default_fighters` con riferimenti espliciti. `FightContent` carica, indicizza e valida i dati prima della simulazione; i fighter della sessione sono ID leggibili, non indici dell'array.

La simulazione usa salute, velocità, salto, hurtbox e riferimenti alle mosse dalle definizioni validate. In particolare il reset inizializza la salute dal campo `health` del fighter selezionato. La compatibilità resta `lab-2` perché il protocollo e le regole effettive non sono cambiati; l'hash dei contenuti nel gate lobby cambia con il nuovo file.

Non sono stati modificati WebRTC, signaling, rollback, pacchetti input, TURN, animazioni o contenuti di combattimento. La prossima fase autorizzabile è la macchina a stati simulata; non è inclusa qui.
