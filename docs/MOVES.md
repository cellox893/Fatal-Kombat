# Mosse, hitbox e hurtbox — fase 4

Il risolutore condiviso implementa soltanto behavior_id "melee". Nessuno script dai dati e nessuna logica basata sul nome fighter. Schema contenuti 2; catalogo immutabile durante la sessione. Le mosse e i fighter sono risolti per ID stabili.

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

Schema 2 e gate lab-4: cambia il runtime/checksum. SHA256 dei byte JSON include tutte le geometrie, finestre e gruppi. Il server rifiuta lab-3 o hash diverso PRIMA di assegnare la stanza. Ricaricare entrambi i client; ricostruire vecchi export. Il gate confronta versioni dichiarate e non certifica integrità del codice.

Per aggiungere un behavior futuro: ramo deterministico esplicito nel risolutore, allowlist supports, validazione parametri e test; nuovo runtime in snapshot/checksum e nuova compatibilità per regole incompatibili. Nessun percorso script dai dati.

## Verifiche e limiti

Il golden di 720 tick resta 25bdfec7b19f6f648514f92903aef150b79cdc3bebcf1be07aefc625e87e85ab sulla proiezione ESATTA dei vecchi campi. Il checksum completo cambia intenzionalmente per il registro nuovo. Proiezione usata solo dal test; multiplayer usa tutti i campi.

Test: orientamenti e bordi, finestre, sovrapposizioni e permanenza, gruppi distinti, nuove istanze, variazioni hurtbox simmetriche fra slot, cleanup, snapshot prima/dopo impatto e rollback 2/5/9 tick con uguaglianza completa dello stato/checksum. Multi-hit e variazioni hurtbox soltanto nei dati in memoria dei test.

Limiti: due fighter/bersagli slot 0/1, nessun proiettile, command buffer, nuova mossa giocabile, animazione o modifica del trasporto. Simulazione indipendente da rendering e fisica Godot. La diagnostica legge gli stessi rettangoli; non decide collisioni.
