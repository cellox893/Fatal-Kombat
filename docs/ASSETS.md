# Provenienza e licenze

- Arena, silhouette, scudo/lancia e anello elettrico: disegno procedurale originale scritto per questo repository in `game/presentation/main.gd`. Nessun asset da Mortal Kombat, Tekken o altri giochi, nessuna immagine o audio esterno. Pose segnaposto, non animazioni complete.
- Font: font di fallback distribuito con Godot, nessun file aggiuntivo vendorizzato.
- Godot: MIT, https://godotengine.org/license/ . Conservare gli avvisi appropriati nel prodotto distribuito.
- webrtc-native: MIT; archivio ufficiale 1.2.1, licenze dipendenze incluse sotto `game/addons/webrtc_native/LICENSE*` dopo setup. Non rimuoverle dal packaging finale. SHA256 registrato localmente al primo download; non una firma upstream. Il motore/template hanno invece checksum SHA512 ufficiali.
- ws: MIT, versione nel package-lock del servizio.
- Playwright: Apache-2.0, solo test e browser scaricati nel Codespace.

La licenza commerciale del codice del gioco non è stata scelta implicitamente. Prima della distribuzione raccogliere gli avvisi di tutte le dipendenze per OS e scegliere esplicitamente la licenza del prodotto. Fatal Kombat resta un nome di lavoro.
