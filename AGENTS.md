# Istruzioni di progetto

Leggere README.md, docs/BRIEF.md, ARCHITECTURE.md, ROADMAP.md e docs/VALIDATION.md. Conservare l'obiettivo: picchiaduro storico 2D online con abilità che cambiano le scelte tattiche.

Lavorare per milestone piccole verificabili. GDScript tipizzato, Godot fissato da scripts/setup.sh, renderer Compatibility, web single thread. Installare solo nel Codespace, non sul Mac. Non aggiornare motore/template o librerie senza aggiornare pin, checksum e verifiche.

Simulation deve restare senza browser, clock, Input, grafica o fisica Godot. Stato intero e snapshot profondi; verificare risimulazione e checksum. Nomi personaggio non devono pilotare logica sparsa. Contenuti con ID stabili; nuove mosse senza cambiare round/protocollo. Aggiornare versione compatibilità quando cambiano regole.

Separare verifiche automatiche, due peer sulla stessa macchina, e prove reali multi-rete. Non chiamare completo il rollback o multiplayer per il solo movimento. Niente promesse di FPS senza misure. Dichiarare limiti ed errori.

Eseguire scripts/test.sh e build del target cambiato. Per rete eseguire test browser e test nativo pertinenti. Tenere documenti allineati ai risultati. Asset originali o licenziati con provenienza registrata. Niente segreti, node_modules, .godot, binari scaricabili o build in Git.

Commit piccoli e comprensibili; il proprietario ha autorizzato commit/push al remote privato configurato. Non rendere pubbliche porte o servizi, non distribuire all'esterno né attivare spese senza autorizzazione. Documentare credenziali mancanti in modo preciso. Non introdurre account, ranked, negozi, Steam o sistemi futuri non richiesti.
