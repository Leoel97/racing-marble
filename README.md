# Racing Marble

Gioco mobile di corse di biglie: la biglia avanza da sola e la sterzi inclinando il telefono,
su piste fatte di giocattoli e oggetti di casa. Gare da 4, in solo contro 3 avversari guidati dal gioco.

- Motore: Godot 4.4 (GDScript), solo Android per ora
- Build: ogni push su `main` compila l'APK e lo pubblica nella release **latest**

## Installare

Dal telefono apri la pagina Releases della repo, scarica `racing-marble.apk` e installalo
(Android chiede di consentire l'installazione da questa fonte).

## Struttura

- `scripts/main.gd` - stati di gioco, interfaccia, camera, classifica
- `scripts/track.gd` - pista, ostacoli, checkpoint, scenografia (tutto generato da codice)
- `scripts/marble.gd` - biglia del giocatore (fisica + sensori)
- `scripts/ai_marble.gd` - avversari guidati dal gioco
- `scripts/marble_look.gd` - aspetto delle biglie
