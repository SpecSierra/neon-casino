# Neon Casino

A cyberpunk casino roguelike for Sailfish OS.

- **10 slot machines**: four classic 3x3 machines with their own features (multiplier ladder,
  overflow combo, stacking spirit, turbo), Chain Reaction (connect-3 cascades), Neural Ways
  (megaways), Data Heist (hold & win), Void Runner (infinity reels), Pixel Arcade (slots meets
  bingo) and Abyss (a fruit machine with holds and nudges). Free spins, retriggers, bonus buy.
- **Tables**: blackjack, roulette, video poker, baccarat, craps, sic bo, keno, mines, plinko and
  Overload (crash).
- **15 mini games**: Hi-Lo, Tower, Coin Flip, Dice, Money Wheel, Scratch cards, Drone Race,
  Rock Paper Scissors, Card War, Penalty, Red Dog, Balloon, Darts, Claw machine, Treasure chests.
- **Progressive jackpots** (Mini / Major / Grand) on every bet; a vault and session limits; stats.
- **REBOOT**: go broke and you get one try at a mini-game (Drone or Firewall) to keep the run.

Each run starts with ¤100 neon credits (play money). Climb as high as you can: every tier you reach
(¤250, ¤500, ¤1 000, ¤2 500 …) raises the table minimum and lets you draft one perk for the run.
Drop below the minimum bet and the run is over. Your lifetime wagers unlock new perks for
future runs (see the Perk codex in the pull-down menu).

Play money only (¤ neon credits) — no real-money gambling, nothing to buy.

## Layout

| Path | What |
|---|---|
| `qml/harbour-neoncasino.qml` | window, perk-draft / game-over routing |
| `qml/components/Game.qml` | the save: run state, perks, tiers, bust check (singleton) |
| `qml/js/` | table maths (`Slots.js`, `Cards.js`, `Roulette.js`), perks, money, LocalStorage |
| `qml/pages/` | hub, every game, the slot and mini-game lobbies, perk draft, game over, reboot games, codex, stats |
| `tools/gen-assets.py`, `tools/gen-sounds.py` | regenerate the PNG art, icons and WAV sounds |
| `tools/kenosim.py` | Keno paytables: exact RTP per number of picks, `--write` makes `qml/js/KenoConfig.js` |
| `tools/machinesim.py`, `tools/jscheck.js` | Chain Reaction, Neural Ways, Data Heist: Python models + tuning, then a check/refine against the real JS engines in Node |
| `tools/slotsim.py` | the slot machines: definitions, exact RTP, `--tune` writes `qml/js/SlotThemes.js` |
| `tools/abysssim.py`, `tools/voidsim.py`, `tools/arcadesim.py` | Abyss (exact, best play), Void Runner and Pixel Arcade (Monte Carlo): tuning + their config JS |
| `tools/chipmusic.py` | the soundtrack: fetches the CC0 tracks, makes seamless loops, writes `MusicTracks.js` / `MusicCredits.js` |
| `tools/make-fonts.py`, `tools/gen-ui.py` | app fonts with the credit-chip sign; the cut-steel UI chrome |

QML only (runs under `sailfish-qml`), no compiled code, so the RPM is `noarch` and passes the
Harbour validator.

## Build

```sh
./build-rpm.sh            # → dist/harbour-neoncasino-<ver>-1.noarch.rpm
```

Needs only `rpmbuild`. Install on the phone with `pkcon install-local` or `rpm -U`.

## Fonts

`qml/fonts/NeonDisplay.ttf` and `NeonMono.ttf` are Chakra Petch Bold and Share Tech Mono (SIL Open
Font License 1.1, originals and licences in `tools/fonts-src/`), renamed as the licence requires and
with the app's currency sign, the credit chip, drawn into the ¤ slot by `tools/make-fonts.py`.
UI chrome is drawn by `tools/gen-ui.py`.

## Music
Every track is a CC0 (public domain) chiptune from OpenGameArt: "A Bag of Chips", "Another Bag of
Chips" and singles by Zane Little Music; "5 Chiptunes (Action)", "4 Chiptunes (Adventure)" and
"12 Music Loops" by Juhani Junkala / SubspaceAudio; pieces by ansimuz, celestialghost8, Spring Spring,
LordZintick; C64 pieces by skrjablin; "7 Pop-Punk Chiptune tracks" by 3xBlast. All are credited in the app under Music
credits. `tools/chipmusic.py`
downloads the tracks, trims them, crossfades each end into its start for a seamless loop, makes
the sped-up free-spin versions and writes `qml/js/MusicTracks.js` / `MusicCredits.js`.
