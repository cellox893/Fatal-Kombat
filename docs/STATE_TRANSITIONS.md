# Revisione fase 2 — 2026-09-09

## Aggiornamento fase 5 — 2026-09-10

La sezione storica sotto descrive la fase 2 senza buffer. Ora, per ciascun fighter, l'ordine è: KO da salute già zero → orientamento se neutral → campionamento storia/scadenza/riconoscimento comandi → consumo solo se già neutral → movimento/gravità/atterraggio → scadenza stun. Seguono hurtbox congelate, collisioni/danno/avanzamento mosse e KO dopo entrambi i colpi, come fase 4.

ATTACK, HITSTUN e BLOCKSTUN consentono registrazione ma vietano consumo. La scadenza non rivaluta input: primo avvio al tick successivo. Default validità 4 tick [pressione,pressione+4). Quindi la vecchia affermazione “nessun buffer implicito” vale soltanto con valid_ticks=1, configurazione mantenuta nei test di regressione. AIRBORNE ammette light ma non nuovi salti durante azione bloccante.

Entrare in hitstun cancella la mossa, non i comandi pendenti: continuano a scadere. KO e reset svuotano input_history e pending_commands. Danno letale a fine tick cancella anche comandi riconosciuti nello stesso tick. Compatibilità attuale lab-5/schema 3; dettagli e prova manuale in MOVES.md. Nessuna parata o hitstun applicati dai colpi.

Base: e3a298ef211c3580b891ff975374c774a5fa3644. Nessun difetto delle regole rilevato nei casi esaminati; aggiunta copertura dei confini di tick e del gate versione. Light e compatibilità lab-3 invariate.

## Combinazioni a fine tick

| Azione | IDLE | MOVING | AIRBORNE |
|---|---|---|---|
| NEUTRAL | sì | sì | sì |
| ATTACK | sì | no | sì |
| HITSTUN | sì | no | sì |
| BLOCKSTUN | sì | no | sì |
| KO | sì | no | sì |

MOVING indica richiesta orizzontale consentita, anche al limite arena; non garantisce spostamento effettivo. ATTACK/AIRBORNE mantiene gravità e velocità verticale, blocca movimento orizzontale e nuovo salto. Stesso vincolo per stun e KO. L'atterraggio porta la locomozione a IDLE senza annullare un'azione ancora in corso. BLOCKSTUN/AIRBORNE è ammesso dal nucleo: non costituisce una regola di parata aerea giocabile.

## Priorità del tick

1. Per ogni fighter, in ordine slot 0/1: salute già esaurita forza KO prima degli input.
2. Gli input sono valutati usando l'azione iniziale. Solo NEUTRAL può orientarsi, iniziare light, muoversi o saltare. La light ha precedenza sul salto se premuti insieme.
3. Movimento e gravità, poi atterraggio e aggiornamento locomozione. Input precedente aggiornato anche se l'azione lo blocca.
4. Decremento stun: N tick interamente bloccati; lo zero riporta NEUTRAL, senza rileggere l'input dello stesso tick.
5. Dopo il movimento di entrambi, attacchi in ordine slot 0/1: collisione/danno con il move_tick corrente, poi avanzamento mossa e fine recovery. Non si rivalutano input dopo fine attacco. Un attacco in recovery che termina non infligge danno.
6. Dopo entrambi gli attacchi, KO prevale su neutral/fine attacco/fine stun. Questo mantiene gli scambi letali simultanei.

Fine attacco e fine stun sono mutuamente esclusivi sullo stesso fighter. Entrambi possono coincidere con atterraggio e danno: testati in entrambi gli slot con danno letale e non letale. La collisione usa le posizioni dopo l'atterraggio. Il danno della light non produce stun e non interrompe l'attacco non letale.

## Ingresso, uscita e riproduzione

Ingresso ATTACK inizializza move, move_tick=0, hit=false. Hitstun interrompe attacco o altro stun; blockstun accetta solo NEUTRAL/BLOCKSTUN. Riapplicare stun sostituisce la durata, non la somma. Transizioni rifiutate non mutano lo stato. Entrare in stun cancella i dati mossa; uscire lascia timer zero. KO cancella mossa, timer e flag impatto; resta terminale fino al reset, continuando gravità e atterraggio. Reset ricrea tutto lo stato iniziale dai contenuti.

Snapshot profondi e checksum includono locomozione, azione e timer. Test preesistenti verificano rollback con input ritardati 2/5/9 tick attraverso scadenza stun, attacco e KO. Nuovi test confrontano anche l'intero snapshot e checksum dopo restore/risimulazione dei confini simultanei e del KO in volo.

Gli stun sono inizializzati tramite apply_stun nelle fixture: si verificano stati e durata, non colpi con hitstun né parate. Una futura applicazione deve avvenire nella simulazione riprodotta da step; chiamate esterne durante il match non vengono registrate dal rollback attuale. Round, input buffer e fase 3 restano esclusi.

## Compatibilità prima del match

MatchTransport invia FightSimulation.compatibility() alla creazione/ingresso: lab-3 più SHA256 dei byte JSON. Il server confronta l'intera stringa con quella della stanza PRIMA di assegnare ws.room o inserire il peer. Rifiuta con “Build o contenuti incompatibili”; il peer non può diventare pronto o avviare WebRTC. Il test lobby verifica lab-2 contro lab-3 a hash uguale e lab-3 con hash diverso, stanza con un solo peer e started=false, e successivo ingresso corretto.

È un confronto delle versioni dichiarate: il server non certifica il codice del client e non è anticheat. Due client vecchi uguali possono creare una propria stanza; il server non impone globalmente lab-3.

## Warning ICE del collaudo precedente

Testo esatto osservato durante cross-platform sul commit base:

```text
WARNING: rtc::impl::IceTransport::LogCallback@391: juice: Send failed, errno=101
     at: LogCallback (src/WebRTCLibPeerConnection.cpp:55)
PASS native Linux / browser WebRTC, confirmed=187 desync=0
```

Il comando terminò con exit code 0 dopo connessione e avanzamento a tick confermato 187 senza desync. “Non bloccante” descrive quell'esecuzione riuscita, non garantisce che ogni errore ICE sia innocuo. Il log non identifica interfaccia, destinazione o coppia candidata fallita: la causa precisa dell'invio fallito non è stata accertata.
