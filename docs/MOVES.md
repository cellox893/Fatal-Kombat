# Mosse, collisioni e command buffer — fase 5

## Comandi — 2026-09-10

Schema 3, gate lab-5. Il catalogo commands associa command_id a move_id; ciascun fighter abilita command_ids. La light:

```json
{"command_id":"light_press","move_id":"light","button":8,
 "valid_ticks":4,"priority":0,"sequence":[],"sequence_ticks":12}
```

Solo fronte 0→1 del bit 8 (J). Tenere premuto non ripete. L'avvio usa command.move_id; moves.light resta un riferimento di catalogo validato preesistente, non decide più l'avvio.

Pressione p valida in [p,p+valid_ticks). Default 4: circa 66,7 ms a 60 Hz, con anticipo massimo di 3 tick (50 ms) sull'esecuzione. Scartata a p+4. valid_ticks=1 significa solo tick corrente, buffering disattivato. Finestra configurabile 1..32, breve scelta iniziale da collaudare.

Un solo vincitore riconosciuto per fronte: priority maggiore, poi command_id lessicograficamente minore. Stesso ordine nel consumo dei pending; per lo stesso ID, pressione più vecchia prima. Candidati perdenti sullo stesso fronte non vengono accodati. Ogni comando consumato è rimosso; pressioni distinte possono accodare attacchi distinti, se non scadono.

Cronologia: ultimi 32 campioni [tick,bits,facing]. Pending: massimo 16 coppie [command_id,tick_pressione]. Un fronte ogni due tick e validità massima 32 limitano già la coda; limite difensivo elimina il più vecchio in caso di eccesso. Scadenza prima di riconoscimento/consumo, a ogni tick vivo.

sequence=[] è light semplice. Fixture [-1,0,1] indica indietro/neutro/avanti, completata da J con ultima direzione mantenuta. sequence_ticks delimita [t-sequence_ticks+1,t], inclusi entrambi gli estremi, massimo 32. Si comprimono campioni direzionali consecutivi uguali; la sequenza deve coincidere con un suffisso consecutivo, senza saltare direzioni estranee. Duplicati adiacenti nella definizione rifiutati.

Direzione relativa = (destra−sinistra) × facing DEL CAMPIONE. Opposti simultanei e nessuna direzione valgono neutro. Facing registrato dopo orientamento neutral, prima del movimento; congelato durante attacco/stun. Un cambio lato non reinterpreta il passato. Una direzione mantenuta conta nei campioni della finestra anche se iniziata prima. Una nuova pressione J può riusare la sequenza ancora presente: viene consumato il token di pressione, non la storia.

Non esiste input giù: questa fase prepara sequenze orizzontali, non un quarto di cerchio completo o una speciale. La fixture sequence_move è solo una copia light in memoria, caricata dal validatore.

Registrazione durante ATTACK/HITSTUN/BLOCKSTUN, esecuzione solo in NEUTRAL a inizio tick. Nessuna cancellazione anticipata. AIRBORNE permette la light come prima; niente salto bufferizzato o variazioni di gravità. KO, anche da danno a fine tick, e reset cancellano storia/coda.

Light a tick 0 termina dopo il 19; primo avvio successivo 20. Pressioni a 17/18/19 sopravvivono; a 16 scadono. Stun: si attende il tick successivo a quello che porta il timer a zero. Nessuna rivalutazione a fine tick.

Snapshot/checksum includono input_history e pending_commands. Il consumo è rappresentato dalla rimozione, senza log illimitato. Rollback ricostruisce storia/riconoscimento/consumo dagli input corretti.

Prova manuale: ricaricare entrambi i browser, stessa stanza, pronti e vicini. Premere J, rilasciare, ripremere verso fine colpo (circa 0,28–0,32 s dalla prima pressione): parte una seconda light dopo recovery. J mantenuto produce un solo attacco; seconda pressione molto precoce scade. I confini precisi sono coperti dai test, non dal timing manuale.

Compatibilità corrente: lab-5 e SHA256 del catalogo comprendente commands/command_ids. Client lab-4 o hash diverso rifiutati prima della stanza. Le specifiche geometriche della fase 4 sotto restano valide.

Il risolutore condiviso implementa soltanto behavior_id "melee". Nessuno script dai dati e nessuna logica basata sul nome fighter. Schema contenuti 3; catalogo immutabile durante la sessione. Le mosse e i fighter sono risolti per ID stabili.

## Definizione della light

```json
{
  "move_id": "light", "behavior_id": "melee",
  "startup": 5, "active": 3, "recovery": 12, "damage": 8,
  "hit_groups": ["light_hit"],
  "hitboxes": [
    {"box_id":"fist","group_id":"light_hit","from":5,"to":8,
     "x":0,"y":-90,"width":72,"height":60}
  ],
  "hurtbox_windows": []
}
```

Il fighter riferisce moves.light = "light" e possiede hurtboxes base:
`[{"box_id":"body","x":-24,"y":-113,"width":48,"height":113}]`.
Sostituiti reach/bottom/top e hurt_width/hurt_height: unica fonte geometrica sono i rettangoli. damage resta comune a tutti i gruppi della mossa.

## Coordinate e bordi

Origine: posizione dei piedi del fighter, x positivo verso destra e y positivo verso il basso. Il rettangolo locale (x,y,width,height) è scritto per facing=+1, verso destra. In coordinate mondo:
- facing +1: left = fighter.x + x;
- facing -1: left = fighter.x - x - width;
- top = fighter.y + y; dimensioni invariate.

Tutte le operazioni di collisione sono intere. Sovrapposizione stretta su entrambi gli assi: bordi o angoli soltanto a contatto NON colpiscono. Con la light e hurtbox base: distanza orientata > -24 e < 96; intervallo verticale identico al precedente. Nessuna variazione delle regole della light rilevata nella traccia di riferimento.

## Finestre e tick

Intervalli [from,to): from incluso, to escluso; tick assoluti dall'inizio della mossa, non dalla fase active. Le hitbox devono stare interamente nella fase active. Box distinti possono sovrapporsi nel tempo/spazio. Identificatori box univoci nell'array; group_id deve appartenere a hit_groups.

La pressione inizia con move_tick=0. Startup [0,5), active [5,8), recovery [8,20). Collisioni risolte al tick corrente, poi incremento; dopo il tick 19 si torna neutral e si pulisce il runtime. Startup/recovery zero ammessi, active strettamente positiva. Uno snapshot dopo step contiene il prossimo tick mossa: il rettangolo diagnostico visualizza quella fase.

hurtbox_windows contiene intervalli con from, to e boxes (stesso formato delle hurtbox base). Durante una finestra, boxes SOSTITUISCE l'intero insieme base; fuori si usa il base. Esempio:
`{"from":5,"to":6,"boxes":[{"box_id":"raised","x":-24,"y":-300,"width":48,"height":20}]}`.
Finestre entro [0,durata totale), non sovrapposte; array boxes non vuoto. Nessuna invulnerabilità tramite array vuoto in questa fase.

## Istanza e registro deterministici

All'avvio attack_sequence del fighter aumenta di uno; attack_id = [slot, sequence], unico nella sessione anche per mosse riavviate nello stesso tick da codice futuro. Al reset la sequenza riparte: l'ID è locale alla sessione, non globale.

hit_targets è un array ordinato di coppie [group_id, target_slot], appartenente all'istanza attiva. La coppia viene aggiunta al primo impatto. Qualsiasi rettangolo dello stesso gruppo che tocchi qualsiasi hurtbox del bersaglio infligge damage UNA volta per istanza. Permanenza, rientro e rettangoli sovrapposti non raddoppiano il danno. Gruppi distinti possono colpire separatamente, anche nello stesso tick, nell'ordine dichiarato. Nuova istanza: registro vuoto, bersaglio nuovamente colpibile.

move, move_tick, hit, attack_sequence, attack_id, hit_targets e gli stati già esistenti sono inclusi in snapshot profondi e checksum. hit è mantenuto per diagnostica e confronto storico; non decide più la collisione. Fine attacco, hitstun e KO cancellano ID attivo/registro/mossa; sequenza mantenuta fino al reset. Nessuna cache runtime nel risolutore.

## Ordine del tick

1. Input, movimento, gravità/atterraggio e scadenza stun come nella fase 2.
2. Congelamento delle hurtbox MONDO dei due fighter, con il tick mossa corrente, prima di avanzare qualunque attacco.
3. Attaccanti slot 0/1, unico avversario 1-slot, gruppi nell'ordine hit_groups, hitbox e hurtbox nell'ordine dei dati. Unione delle sovrapposizioni nel gruppo; poi danno e registrazione della coppia una sola volta.
4. Ogni attacco avanza dopo la sua risoluzione; KO applicato solo dopo entrambi.

Gli attacchi simultanei, anche letali, scambiano danno. Il congelamento evita che l'avanzamento/fine mossa dello slot 0 cambi le hurtbox viste dallo slot 1. La light non ha variazioni hurtbox: equivalenza mantenuta. Non ci sono scontri fra attacchi, priorità di mosse, hitstop, spinte o interruzione automatica da danno non letale. Un KO già presente resta un bersaglio geometrico, come prima, con salute bloccata a zero. Gli stun restano API testate del nucleo, non effetti della light né parate giocabili.

## Validazione e compatibilità

Richiesti campi geometrici interi, dimensioni positive, ID leggibili/univoci, group_id esistenti, finestre valide e behavior noto. Valori numerici del catalogo finiti e limitati in valore assoluto a 1.000.000, oltre ai vincoli di segno del campo, per evitare overflow delle operazioni geometriche. Finestre hurtbox sovrapposte rifiutate. Un gruppo dichiarato senza finestre non causa danni.

Schema 3 e gate lab-5: cambiano regole buffer e runtime/checksum. SHA256 dei byte JSON include comandi, geometrie, finestre e gruppi. Il server rifiuta lab-4 o hash diverso PRIMA di assegnare la stanza. Ricaricare entrambi i client; ricostruire vecchi export. Il gate confronta versioni dichiarate e non certifica integrità del codice.

Per aggiungere un behavior futuro: ramo deterministico esplicito nel risolutore, allowlist supports, validazione parametri e test; nuovo runtime in snapshot/checksum e nuova compatibilità per regole incompatibili. Nessun percorso script dai dati.

## Verifiche e limiti

Il golden di 720 tick resta 25bdfec7b19f6f648514f92903aef150b79cdc3bebcf1be07aefc625e87e85ab sulla proiezione ESATTA dei vecchi campi. Il checksum completo cambia intenzionalmente per il registro nuovo. Proiezione usata solo dal test; multiplayer usa tutti i campi.

Test: orientamenti e bordi, finestre, sovrapposizioni e permanenza, gruppi distinti, nuove istanze, variazioni hurtbox simmetriche fra slot, cleanup, snapshot prima/dopo impatto e rollback 2/5/9 tick con uguaglianza completa dello stato/checksum. Multi-hit e variazioni hurtbox soltanto nei dati in memoria dei test.

Limiti: due fighter/bersagli slot 0/1, nessun proiettile, nuova mossa giocabile, animazione o modifica del trasporto. Command buffer della light e sequenze orizzontali come descritto sopra. Simulazione indipendente da rendering e fisica Godot. La diagnostica legge gli stessi rettangoli; non decide collisioni.
