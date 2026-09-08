# Brief di progetto — requisiti dell'utente, 2026-09-08

Conservazione strutturata del brief iniziale; non è una dichiarazione di funzionalità completate. In caso di dubbio prevalgono le istruzioni originali dell'utente.

## Visione confermata

Fatal Kombat è un nome provvisorio. Picchiaduro laterale 2D per due persone, personaggi storici reinterpretati creativamente, ispirazione Mortal Kombat/Tekken per identità, risposta e impatto, senza movimento in profondità. Speciali con conseguenze tattiche vere su spazio, difesa e contromosse, non soltanto animazioni/danno diversi. Personaggi con attacchi/combo, movimento proprio, forze/debolezze, abilità storiche fantasiose e presentazione distinta. Proposte sostituibili: Leonida (difesa, scudo, ravvicinato, contrattacco), Nikola Tesla (elettricità, distanza, spazio).

## Esperienza e primo prodotto

Aprire gioco → creare stanza privata o codice amico → scegliere → pronto → partita online → risultato → proposta e accettazione rivincita. Online obbligatorio già nella prima versione giocabile; locale/bot solo ausili. Due personaggi, un'arena, due dispositivi su reti differenti, movimento/salto/parata, leggero/pesante, concatenamento semplice, due speciali ciascuno, salute/timer/indicatori, meglio di tre round, errori/disconnessioni comprensibili, tastiera/controller rimappabili.

## Presentazione

Grafica semplice, coerente, piacevole e sostituibile. Forme semplici ammesse nella prova tecnica, animazioni riconoscibili nella versione completa: idle, movimento, salto, atterraggio, attacchi, parata, danno, speciali, sconfitta. Silhouette/pose/colori distinguibili. Priorità a comandi/transizioni/leggibilità; suoni, effetti e camera rafforzano senza nascondere. Asset originali o compatibili con provenienza. Animazioni non determinano danni/collisioni/tempi.

## Ambiente e tecnologia

Mac con poco spazio, repository GitHub Codespaces. Strumenti/dipendenze/template nel Codespace, prova sul browser Mac. Godot stabile verificato e fissato, GDScript tipizzato, Compatibility, web inizialmente single thread, CLI import/check/export, GitHub, WebRTC, lobby/signaling separati, STUN/TURN configurabili. Verificare fonti ufficiali e librerie per manutenzione/licenza/compatibilità; spiegare problemi sostanziali e proporre alternativa prima di investire in premessa errata. Codespace è sviluppo; server persistenti futuri su VPS/gestiti.

## Architettura e rete

Separare simulazione/input/netcode/presentazione/contenuti/UI-ciclo partita/servizi-piattaforma. Resources o equivalenti con ID stabili. Aggiungere un personaggio principalmente con definizione, asset, mosse ed eventuali comportamenti nuovi; non cambiare protocollo e round. Evitare condizioni sparse sul nome e astrazione eccessiva. Parametri: salute, movimento, danno, startup/active/recovery, hit/hurtbox, costi, cooldown, risorse, effetti/condizioni, concatenamenti. Gate versione build/contenuti prima del match.

60 tick/s deterministici separati dal rendering. Input numerati, predizione remota, snapshot/restore/rollback/risimulazione, desync, casualità riproducibile, messaggi mancanti/tardivi/duplicati, finestra limitata e comportamento rete insufficiente. Non assumere fisica Godot deterministica browser-desktop; strategia numerica/collisioni verificata con replay/checksum. Stato completo anche proiettili, oggetti abilità, risorse, cooldown, effetti. Risimulazione senza audio/particelle/notifiche duplicate. P2P privato con signaling distinto da server autorevole, limiti fiducia documentati; TURN per NAT che impediscono diretto. Ranked richiede decisioni ulteriori.

## Crescita

Confermati: espansione personaggi/abilità/arene, grafica/animazione/audio, bilanciamento, futuro desktop commerciale incluso possibile Steam. Core condiviso web/desktop, browser isolato, Steam senza riscrittura. Documentare packaging/integrazioni/test senza presentare pubblicazione automatica. Possibilità future, non subito: tutorial/training, matchmaking, account/profili/statistiche, ranked, replay, Steam inviti/achievement. Niente negozi o sistemi generici non necessari.

## Lavoro iniziale, in ordine

1. Ispezionare repo/strumenti/risorse/spazio.
2. Ambiente riproducibile, Godot e template ufficiali corrispondenti, versioni registrate.
3. Struttura, README/ARCHITECTURE/ROADMAP/AGENTS, brief e decisioni conservati.
4. Build web arena/provvisori, comando rigenerazione e preview 0.0.0.0:8000.
5. Lobby/signaling seconda porta; endpoint HTTPS/WSS Codespaces, mai localhost del tester remoto.
6. WebRTC fra due client stessa stanza, input con tick.
7. Prova separata snapshot/restore/risimulazione rollback.
8. STUN/TURN e richiesta esatta di servizi/accessi mancanti.
9. Export desktop e dipendenze native presto; distinguere export da esecuzione su OS reale.
10. URL e istruzioni prova due client e risultati attesi. Se incompleto: versione coerente/riproducibile e stato preciso.

## Verifiche e modo di lavoro

60 FPS stabili sul dispositivo da misurare. Debug frame time, tick, RTT, rollback/desync, hit/hurtbox. Test determinismo/snapshot, diretto/TURN, timeout/disconnessioni, RTT 50/100/150 ms+jitter/perdita, web-desktop. Distinguere automatici / processi-finestre stessa macchina / dispositivi-reti reali; non inventare risultati.

Piano iniziale breve poi implementare, milestone piccole. Autonomia per scelte reversibili, documentare. Chiedere dati quando incidono, niente credenziali/accessi inventati. Non attivare servizi pagati o pubblicare esternamente senza autorizzazione; preparare deployment ammesso. Commit comprensibili e push al repo privato configurato; escludere segreti/cache/dipendenze/build. Resoconto finale: realizzato, prova, test, limiti, cosa procurare, prossima milestone. Obiettivo permanente: online divertente/reattivo, storici distintivi, contenuti espandibili, futuro desktop commerciale.
