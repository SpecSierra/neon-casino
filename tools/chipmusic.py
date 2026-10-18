#!/usr/bin/env python3
"""Soundtrack: CC0 chiptunes by Zane Little Music ("A Bag of Chips" and "Another Bag of Chips",
OpenGameArt). Downloads each track, trims silence, crossfades the end into the start so it loops
without a seam, encodes Ogg Vorbis into qml/music/, and writes qml/js/MusicTracks.js (loop
lengths and loudness-matching gains) plus qml/js/MusicCredits.js.

    python3 tools/chipmusic.py           # all tracks
Free-spin versions (<machine>_bonus) are the machine's track sped up 12% (a whole tone higher).
"""
import json, os, subprocess, sys, wave
import numpy as np

SR = 44100
FADE = 2.0           # crossfade seconds at the loop point
TAIL = 4.0           # silence after the loop: the player expects loop + tail
BASE = "https://opengameart.org/sites/default/files/"
PACKS = {"A Bag of Chips": "https://opengameart.org/content/10-free-chiptune-tracks-a-bag-of-chips",
         "Another Bag of Chips": "https://opengameart.org/content/10-more-chiptune-tracks-another-bag-of-chips",
         "Wednesday Night Funk Fusion": "https://opengameart.org/content/wednesday-night-funk-fusion",
         "Pixel Sprinter": "https://opengameart.org/content/pixel-sprinter",
         "Apple Cider": "https://opengameart.org/content/apple-cider",
         "Shortcuts": "https://opengameart.org/content/shortcuts",
         "Goober Dynamics": "https://opengameart.org/content/goober-dynamics-1",
         "Buddy Power": "https://opengameart.org/content/buddy-power-day-22",
         "Rhythm Factory": "https://opengameart.org/content/rhythm-factory",
         "Heroic Loop": "https://opengameart.org/content/heroic-loop",
         "Sparkling Cosmic Dust": "https://opengameart.org/content/sparkling-cosmic-dust",
         "Goober Dynamics": "https://opengameart.org/content/goober-dynamics-1",
         "Synesthesia": "https://opengameart.org/content/synesthesia",
         "Freeway Fumes": "https://opengameart.org/content/freeway-fumes",
         "Toy Soldiers": "https://opengameart.org/content/toy-soldiers",
         "Electronic Outlaw": "https://opengameart.org/content/electronic-outlaw",
         "Interstellar Fleet": "https://opengameart.org/content/interstellar-fleet-1"}
TRACKS = {   # app track: (file, title, pack)
    "lobby": ("starlight_city.wav", "Starlight City", "Another Bag of Chips"),
    "slots": ("sideways_city_0.wav", "Sideways City", "Another Bag of Chips"),
    "hacker": ("it_takes_a_hero_0.wav", "It Takes a Hero", "A Bag of Chips"),
    "tokyo": ("australis_frontier_loop.mp3", "Australis Frontier", "Australis Frontier"),
    "sunset": ("aura_horizon.wav", "Aura Horizon", "Another Bag of Chips"),
    "cascade": ("insect_factory_0.wav", "Insect Factory", "Another Bag of Chips"),
    "ways": ("the_world_is_ours_0.wav", "The World Is Ours", "A Bag of Chips"),
    "heist": ("backup_plan_0.wav", "Backup Plan", "Another Bag of Chips"),
    "bonus": ("100_victories.wav", "100 Victories", "A Bag of Chips"),
    "overload": ("dizzy_racing_0.wav", "Dizzy Racing", "A Bag of Chips"),
    "blackjack": ("the_cool_factor_0.wav", "The Cool Factor", "Another Bag of Chips"),
    "roulette": ("face_the_facts_0.wav", "Face the Facts", "A Bag of Chips"),
    "poker": ("poker_night.wav", "Poker Night", "Another Bag of Chips"),
    "baccarat": ("hush_hamlet.wav", "Hush Hamlet", "Another Bag of Chips"),
    "craps": ("old_tricks_1.wav", "Old Tricks", "Another Bag of Chips"),
    "keno": ("moms_workout_cd_0.wav", "Mom's Workout CD", "A Bag of Chips"),
    "mines": ("sinister_abode_0.wav", "Sinister Abode", "A Bag of Chips"),
    "plinko": ("space_cadet_training_montage.wav", "Space Cadet Training Montage", "A Bag of Chips"),
    "sicbo": ("stumble_around_0.wav", "Stumble Around", "A Bag of Chips"),
    "reboot": ("post-adventure_tea_party_0.wav", "Post-Adventure Tea Party", "A Bag of Chips"),
    "wheel": ("wednesday_night.mp3", "Wednesday Night Funk Fusion", "Wednesday Night Funk Fusion"),
    "hilo": ("pixel_sprinter_1.wav", "Pixel Sprinter", "Pixel Sprinter"),
    "scratch": ("apple_cider.wav", "Apple Cider", "Apple Cider"),
    "void": ("sparkling_cosmic_dust.wav", "Sparkling Cosmic Dust", "Sparkling Cosmic Dust"),
    "arcade": ("goober_dynamics_1.wav", "Goober Dynamics", "Goober Dynamics"),
    "abyss": ("synesthesia.wav", "Synesthesia", "Synesthesia"),
    "minis": ("freeway_fumes.wav", "Freeway Fumes", "Freeway Fumes"),
    "coinflip": ("toy_soldiers.wav", "Toy Soldiers", "Toy Soldiers"),
    "dice": ("electronic_outlaw.wav", "Electronic Outlaw", "Electronic Outlaw"),
    "tower": ("interstellar_fleet_1.mp3", "Interstellar Fleet", "Interstellar Fleet"),
}
# Other CC0 chiptune composers on OpenGameArt, for variety. Packs that ship as zips are
# unpacked into CACHE/<pack>/; RAW maps a cache name to its (url-encoded) file on the site.
ZIPS = {"poppunk": "3xblast_-_7_pop-punk_chiptune_tracks_0.zip",
        "loops12": "12_indie_game_music_loops_0.zip"}
RAW = {"jj_level1.mp3": "level1.mp3", "jj_level2.mp3": "level2.mp3", "jj_level3.mp3": "level3.mp3",
       "jj_boss.ogg": "Juhani%20Junkala%20%5BChiptune%20Adventures%5D%203.%20Boss%20Fight.ogg",
       "jj_stage2.ogg": "Juhani%20Junkala%20%5BChiptune%20Adventures%5D%202.%20Stage%202.ogg",
       "australis_frontier_loop.mp3": "Australis%20Frontier%20%28Loop%29.mp3",
       "abandoned_hopes.mp3": "Abandoned%20Hopes.mp3", "hello_world.wav": "Hello%20World_0.wav",
       "cand_shortcuts.mp3": "shortcuts.mp3", "cand_rhythm_factory.mp3": "rhythm_factory.mp3", "cand_heroic_loop_0.mp3": "heroic_loop_0.mp3",
       "cand_goober_dynamics_1.mp3": "goober_dynamics_1.mp3", "cand_buddy_power.mp3": "buddy_power.mp3"}
AUTHORS = {  # pack -> (composer, page)
    "6 C64 soundtracks": ("skrjablin", "https://opengameart.org/content/6-genuinely-c64-soundtracks-released-as-public-domain-may-2017"),
    "5 Chiptunes (Action)": ("Juhani Junkala / SubspaceAudio", "https://opengameart.org/content/5-chiptunes-action"),
    "4 Chiptunes (Adventure)": ("Juhani Junkala / SubspaceAudio", "https://opengameart.org/content/4-chiptunes-adventure"),
    "12 Music Loops": ("Juhani Junkala / SubspaceAudio", "https://opengameart.org/content/12-music-loops"),
    "7 Pop-Punk Chiptune tracks": ("3xBlast", "https://opengameart.org/content/7-pop-punk-chiptune-tracks"),
    "Australis Frontier": ("celestialghost8", "https://opengameart.org/content/australis-frontier"),
    "Dark Happy World": ("ansimuz", "https://opengameart.org/content/dark-happy-world"),
    "Kalypo": ("Spring Spring", "https://opengameart.org/content/kalypo"),
    "The Arplands": ("LordZintick", "https://opengameart.org/content/the-arplands"),
}
CAP = {"baccarat": 180, "hilo": 180, "rps": 180, "claw": 180, "darts": 180}     # seconds: very long pieces are cut (the loop crossfade covers the cut)
TRACKS.update({
    "baccarat": ("kalypo.mp3", "Kalypo", "Kalypo"),
    "war": ("dark-happy-world.ogg", "Dark Happy World", "Dark Happy World"),
    "mines": ("poppunk/3xBlast - If You're Thinking About Giving Up, Think Again Beause I Believe In You! (Looped).ogg", "If You're Thinking About Giving Up, Think Again Because I Believe In You!", "7 Pop-Punk Chiptune tracks"),
    "heist": ("the_arplands.ogg", "The Arplands", "The Arplands"),
    "abyss": ("glizzy_elf_forest_interrupted_by_grizzly_dwarf_thief_battle.wav", "Glizzy Elf Forest Interrupted by Grizzly Dwarf Thief Battle", "Another Bag of Chips"),
    "roulette": ("toy_soldiers.wav", "Toy Soldiers", "Toy Soldiers"),
    "keno": ("c64_uptempo_chiptune.ogg", "Uptempo Chiptune", "6 C64 soundtracks"),
    "craps": ("freddie_swamp.ogg", "Freddie Swamp", "6 C64 soundtracks"),
    "sicbo": ("shanty_c64.ogg", "Shanty", "6 C64 soundtracks"),
    "overload": ("jj_level3.mp3", "Level 3", "5 Chiptunes (Action)"),
    "hilo": ("cand_shortcuts.mp3", "Shortcuts", "Shortcuts"),
    "reboot": ("jj_level2.mp3", "Level 2", "5 Chiptunes (Action)"),
    "tower": ("jj_boss.ogg", "Boss Fight", "4 Chiptunes (Adventure)"),
    "minis": ("loops12/397 [Misc Extras] bgm_space_upbeat_F.ogg", "Space Upbeat", "12 Music Loops"),
    "ways": ("loops12/373 [Misc Extras] bgm_gojira_battle_A.ogg", "Gojira Battle", "12 Music Loops"),
    "rps": ("cand_rhythm_factory.mp3", "Rhythm Factory", "Rhythm Factory"),
    "race": ("loops12/218 [Super Action Chiptunes] bgm_stage_9.ogg", "Super Action Stage 9", "12 Music Loops"),
    "dice": ("cand_heroic_loop_0.mp3", "Heroic Loop", "Heroic Loop"),
    "plinko": ("poppunk/3xBlast - Now This Is A Waterpark! (Looped).ogg", "Now This Is A Waterpark!", "7 Pop-Punk Chiptune tracks"),
    "coinflip": ("poppunk/3xBlast - Let's Go, Olive Boy! (Looped).ogg", "Let's Go, Olive Boy!", "7 Pop-Punk Chiptune tracks"),
    "scratch": ("poppunk/3xBlast - Babe, You Look Poggers Tonight! (Looped).ogg", "Babe, You Look Poggers Tonight!", "7 Pop-Punk Chiptune tracks"),
    "arcade": ("poppunk/3xBlast - The Best Move Is To Keep Going (Looped).ogg", "The Best Move Is To Keep Going", "7 Pop-Punk Chiptune tracks"),
    "penalty": ("loops12/133 [Retro Sports] bgm_stage_final.ogg", "Retro Sports Final Stage", "12 Music Loops"),
    "balloon": ("poppunk/3xBlast - Thanks For Listening! (Looped).ogg", "Thanks For Listening!", "7 Pop-Punk Chiptune tracks"),
    "reddog": ("jj_stage2.ogg", "Stage 2", "4 Chiptunes (Adventure)"),
    "darts": ("freeway_fumes.wav", "Freeway Fumes", "Freeway Fumes"),
    "claw": ("cand_goober_dynamics_1.mp3", "Goober Dynamics", "Goober Dynamics"),
    "chests": ("cand_buddy_power.mp3", "Buddy Power", "Buddy Power"),
})
BONUS = ["hacker", "tokyo", "sunset", "cascade", "ways", "heist", "void", "arcade", "abyss"]
CACHE = os.environ.get("CHIP_CACHE", "/tmp/neoncasino-chips")
NAMES = {"lobby": "Lobby", "slots": "Neon Slots", "hacker": "Hacker Grid", "tokyo": "Neo Tokyo", "sunset": "Sunset Drive",
         "cascade": "Chain Reaction", "ways": "Neural Ways", "heist": "Data Heist", "bonus": "Free spins", "overload": "Overload",
         "blackjack": "Blackjack", "roulette": "Roulette", "poker": "Video Poker", "baccarat": "Baccarat", "craps": "Craps",
         "keno": "Keno", "mines": "Mines", "plinko": "Plinko", "sicbo": "Sic Bo", "reboot": "Reboot",
         "wheel": "Money Wheel", "hilo": "Hi-Lo", "scratch": "Scratch cards",
         "void": "Void Runner", "arcade": "Pixel Arcade", "abyss": "Abyss", "minis": "Mini games", "coinflip": "Coin Flip",
         "dice": "Dice", "tower": "Tower", "war": "Card War", "rps": "Rock Paper Scissors", "race": "Drone Race",
         "penalty": "Penalty Shootout", "reddog": "Red Dog", "balloon": "Balloon",
         "darts": "Darts", "claw": "Claw Machine", "chests": "Treasure Chests"}

def fetch(fn):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, fn)
    if not os.path.exists(path):
        if "/" in fn:                       # a track inside a zipped pack: fetch + unpack the pack
            pack = fn.split("/")[0]
            z = os.path.join(CACHE, pack + ".zip")
            subprocess.run(["curl", "-s", "-L", "-m", "300", "-o", z, BASE + ZIPS[pack]], check=True)
            os.makedirs(os.path.join(CACHE, pack), exist_ok=True)
            subprocess.run(["unzip", "-oq", z, "-d", os.path.join(CACHE, pack)], check=True)
        else:
            subprocess.run(["curl", "-s", "-L", "-m", "180", "-o", path, BASE + RAW.get(fn, fn)], check=True)
    return path

def decode(path, speed=1.0):
    af = "asetrate=%d,aresample=%d" % (int(SR * speed), SR) if speed != 1.0 else "anull"
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-af", af, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype(np.float64)

def loopable(x, max_seconds=None):
    level = np.abs(x).max(axis=1)
    on = np.where(level > 0.01)[0]
    x = x[on[0]:on[-1] + 1]
    if max_seconds and len(x) > max_seconds * SR:
        x = x[:int(max_seconds * SR)]
    f = int(FADE * SR)
    ramp = np.linspace(0, 1, f)[:, None]
    body = x[:-f].copy()
    body[:f] = x[:f] * ramp + x[-f:] * (1 - ramp)          # the end flows into the start
    return body

def encode(name, body):
    out = np.concatenate([body, np.zeros((int(TAIL * SR), 2))])
    out *= 0.95 / (np.abs(out).max() + 1e-9)
    tmp = "/tmp/neoncasino-%s.wav" % name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((out * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "1.5", "qml/music/%s.ogg" % name], check=True)
    os.remove(tmp)
    rms = 20 * np.log10(np.sqrt(np.mean(body ** 2)) + 1e-9) + 20 * np.log10(0.95 / (np.abs(out).max() + 1e-9) * (np.abs(out).max() + 1e-9))
    return int(round(len(body) * 1000 / SR)), rms

if __name__ == "__main__":
    os.makedirs("qml/music", exist_ok=True)
    loops, rms = {}, {}
    jobs = [(k, k, 1.0, CAP.get(k)) for k in TRACKS] + [(k + "_bonus", k, 1.12, 75) for k in BONUS]
    for name, src, speed, cap in jobs:
        body = loopable(decode(fetch(TRACKS[src][0]), speed), cap)
        body *= 0.95 / (np.abs(body).max() + 1e-9)
        loops[name], rms[name] = encode(name, body)
        rms[name] = 20 * np.log10(np.sqrt(np.mean(body ** 2)) + 1e-9)
        print("%-14s %6.1fs  %5.1f dBFS  %4d KB" % (name, loops[name] / 1000, rms[name], os.path.getsize("qml/music/%s.ogg" % name) // 1024))
    quiet = min(rms.values())
    gains = {k: round(10 ** ((quiet - v) / 20), 3) for k, v in rms.items()}
    with open("qml/js/MusicTracks.js", "w") as f:
        f.write(".pragma library\n// Generated by tools/chipmusic.py. loopMs: loop length (the file is longer by a silent\n"
                "// tail). gain: loudness match, every track scaled to the quietest one.\n")
        f.write("var loopMs = { " + ", ".join("%s: %d" % (k, loops[k]) for k in sorted(loops)) + " }\n")
        f.write("var gain = { " + ", ".join("%s: %.3f" % (k, gains[k]) for k in sorted(gains)) + " }\n")
    def credit(k):
        f, title, pack = TRACKS[k]
        if pack in AUTHORS:
            who, url = AUTHORS[pack]
            return {"track": NAMES[k], "title": title, "by": who + " · " + pack + " · CC0", "url": url}
        return {"track": NAMES[k], "title": title, "by": "Zane Little Music · " + (pack if pack != title else "single") + " · CC0", "url": PACKS[pack]}
    credits = [credit(k) for k in TRACKS]
    with open("qml/js/MusicCredits.js", "w") as f:
        f.write(".pragma library\n// Generated by tools/chipmusic.py\nvar credits = " + json.dumps(credits, indent=1, ensure_ascii=False) + "\n")
