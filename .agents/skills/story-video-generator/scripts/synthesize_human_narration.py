#!/usr/bin/env python3
"""
Synthesizes engaging multi-character neural human voice narration for an approved
screenplay using Microsoft Azure Neural Voices (via edge-tts) and converts each
utterance into 44.1kHz 16-bit stereo PCM WAV files for frame-accurate animation
and lip-sync in render_screenplay_video.swift.

Strictly forbids basic macOS robotic TTS (/usr/bin/say, Samantha, etc.).
"""

import argparse
import asyncio
import json
import os
import subprocess
import sys
import wave
from pathlib import Path


VOICE_CAST = {
    "Narrator": {
        "voice": "en-US-AriaNeural",
        "rate": "-4%",
        "pitch": "+0Hz",
    },
    "Plum": {
        "voice": "en-US-JennyNeural",
        "rate": "+2%",
        "pitch": "+10Hz",
    },
    "Clem": {
        "voice": "en-US-AnaNeural",
        "rate": "+4%",
        "pitch": "+4Hz",
    },
}


# Exact verbatim storyline dialogue & narration breakdown for Act 1 ("In the Garden")
ACT1_SCENE_UTTERANCES = {
    1: [
        {
            "speaker": "Narrator",
            "text": "Plum fluttered down onto the garden fence.",
            "pause_after": 0.18,
        },
        {
            "speaker": "Plum",
            "text": "Follow me!",
            "pause_after": 0.18,
        },
        {
            "speaker": "Narrator",
            "text": "she chirped. Clem grinned and hopped over the gate.",
            "pause_after": 0.18,
        },
        {
            "speaker": "Clem",
            "text": "I'm right behind you!",
            "pause_after": 0.25,
        },
        {
            "speaker": "Narrator",
            "text": "Together they walked past rows of green plants, ready to see what the crop had grown this season.",
            "pause_after": 0.25,
        },
        {
            "speaker": "Plum",
            "text": "See all these matching spinach plants? When we grow a whole field of the exact same plant, that big group of plants is called a crop!",
            "pause_after": 0.65,
        },
    ],
    2: [
        {
            "speaker": "Narrator",
            "text": "Clem and Plum walk by the potato patch. Lovely green lush grown potato plants were swaying.",
            "pause_after": 0.22,
        },
        {
            "speaker": "Plum",
            "text": "A long time ago, gardeners used a little shovel called a spud to dig up treats from the ground. Because they used that shovel to find potatoes, people just started calling the potatoes spuds too!",
            "pause_after": 0.25,
        },
        {
            "speaker": "Clem",
            "text": "Look! Well, spud is just a secret, silly nickname for a potato!",
            "pause_after": 0.20,
        },
        {
            "speaker": "Narrator",
            "text": "said Clem, digging his hands into the soft dirt. Clem pulled out a round, dusty spud.",
            "pause_after": 0.18,
        },
        {
            "speaker": "Clem",
            "text": "Found one!",
            "pause_after": 0.22,
        },
        {
            "speaker": "Plum",
            "text": "Whenever you eat French fries or mashed potatoes, you are actually eating delicious spuds!",
            "pause_after": 0.65,
        },
    ],
    3: [
        {
            "speaker": "Narrator",
            "text": "Plum hopped closer and peeked into the hole. Something wiggled.",
            "pause_after": 0.22,
        },
        {
            "speaker": "Plum",
            "text": "A grub!",
            "pause_after": 0.18,
        },
        {
            "speaker": "Narrator",
            "text": "she said with a giggle.",
            "pause_after": 0.18,
        },
        {
            "speaker": "Plum",
            "text": "He's shy — say hello gently.",
            "pause_after": 0.70,
        },
    ],
    4: [
        {
            "speaker": "Narrator",
            "text": "Clem reached out to pet a leaf, but his sleeve caught on a thorny branch.",
            "pause_after": 0.22,
        },
        {
            "speaker": "Clem",
            "text": "Snag!",
            "pause_after": 0.18,
        },
        {
            "speaker": "Narrator",
            "text": "he laughed, tugging it free.",
            "pause_after": 0.18,
        },
        {
            "speaker": "Clem",
            "text": "Gotcha, you sneaky bush!",
            "pause_after": 0.85,
        },
    ],
}


def get_wav_duration(wav_path: Path) -> float:
    with wave.open(str(wav_path), "rb") as wf:
        frames = wf.getnframes()
        rate = wf.getframerate()
        return frames / float(rate)


async def synthesize_utterance(
    edge_tts_mod,
    text: str,
    speaker: str,
    mp3_path: Path,
    wav_path: Path,
) -> float:
    cfg = VOICE_CAST[speaker]
    communicate = edge_tts_mod.Communicate(
        text=text,
        voice=cfg["voice"],
        rate=cfg["rate"],
        pitch=cfg["pitch"],
    )
    await communicate.save(str(mp3_path))
    subprocess.run(
        [
            "/usr/bin/afconvert",
            "-f",
            "WAVE",
            "-d",
            "LEI16@44100",
            "-c",
            "2",
            str(mp3_path),
            str(wav_path),
        ],
        check=True,
    )
    return get_wav_duration(wav_path)


async def run_synthesis(screenplay_path: Path, out_dir: Path) -> None:
    import importlib
    import time
    import urllib.request
    from datetime import datetime as dt, timezone as tz
    from email.utils import parsedate_to_datetime

    Path("/tmp/edge_tts_pkg").mkdir(parents=True, exist_ok=True)
    if "/tmp/edge_tts_pkg" not in sys.path:
        sys.path.insert(0, "/tmp/edge_tts_pkg")
    importlib.invalidate_caches()
    try:
        import edge_tts
        import edge_tts.communicate
        from edge_tts.drm import DRM
    except ImportError:
        subprocess.run(
            [
                sys.executable,
                "-m",
                "pip",
                "install",
                "--quiet",
                "--target",
                "/tmp/edge_tts_pkg",
                "edge-tts",
            ],
            check=True,
        )
        importlib.invalidate_caches()
        import edge_tts
        import edge_tts.communicate
        from edge_tts.drm import DRM

    # Calibrate clock skew against real server UTC Date header (since local clock may be in Nov 2026)
    for url in ("https://www.microsoft.com", "https://www.bing.com", "https://www.google.com"):
        try:
            req = urllib.request.Request(url, method="HEAD")
            with urllib.request.urlopen(req, timeout=5) as resp:
                date_hdr = resp.headers.get("Date")
                if date_hdr:
                    server_ts = parsedate_to_datetime(date_hdr).timestamp()
                    local_ts = dt.now(tz.utc).timestamp()
                    DRM.clock_skew_seconds = server_ts - local_ts
                    print(f"Calibrated clock skew: {DRM.clock_skew_seconds:.1f}s (server Date: {date_hdr})")
                    break
        except Exception:
            continue

    def _skewed_date_to_string() -> str:
        return time.strftime(
            "%a %b %d %Y %H:%M:%S GMT+0000 (Coordinated Universal Time)",
            time.gmtime(DRM.get_unix_timestamp()),
        )

    edge_tts.communicate.date_to_string = _skewed_date_to_string

    with open(screenplay_path, "r", encoding="utf-8") as f:
        screenplay = json.load(f)

    out_dir.mkdir(parents=True, exist_ok=True)
    scenes_manifest = []
    global_cursor = 0.0

    for beat in screenplay.get("beats", []):
        bnum = int(beat["beat_number"])
        target_word = beat["target_word"]
        utterances = beat.get("utterances") or ACT1_SCENE_UTTERANCES.get(bnum, [])
        if not utterances:
            utterances = [
                {
                    "speaker": "Narrator",
                    "text": beat.get("verbatim_storyline_script", ""),
                    "pause_after": 0.6,
                }
            ]

        scene_start = global_cursor
        lead_in_sec = 0.95  # Let the coloring page -> storybook color reveal breathe
        local_cursor = lead_in_sec
        beat_items = []

        for idx, u in enumerate(utterances, start=1):
            speaker = u["speaker"]
            text = u["text"]
            mp3_path = out_dir / f"scene{bnum}_{idx:02d}_{speaker.lower()}.mp3"
            wav_path = out_dir / f"scene{bnum}_{idx:02d}_{speaker.lower()}.wav"
            dur = await synthesize_utterance(edge_tts, text, speaker, mp3_path, wav_path)
            item = {
                "index": idx,
                "speaker": speaker,
                "voice": VOICE_CAST[speaker]["voice"],
                "text": text,
                "wav_path": str(wav_path),
                "start_in_scene_sec": round(local_cursor, 4),
                "end_in_scene_sec": round(local_cursor + dur, 4),
                "duration_sec": round(dur, 4),
            }
            beat_items.append(item)
            local_cursor += dur + u.get("pause_after", 0.25)

        tail_hold_sec = 1.05  # Lock 100% back onto the exact storyline image at scene end
        scene_duration = max(9.5, round(local_cursor + tail_hold_sec, 3))
        scenes_manifest.append(
            {
                "beat_number": bnum,
                "target_word": target_word,
                "scene_start_sec": round(scene_start, 4),
                "scene_end_sec": round(scene_start + scene_duration, 4),
                "scene_duration_sec": scene_duration,
                "source_scene_image_path": beat["source_scene_image_path"],
                "colored_scene_image_path": beat.get(
                    "colored_scene_image_path", beat["source_scene_image_path"]
                ),
                "animation_anchors": beat.get("animation_anchors", {}),
                "utterances": beat_items,
            }
        )
        global_cursor += scene_duration

    manifest = {
        "screenplay_path": str(screenplay_path),
        "voice_engine": "Microsoft Azure Neural Multi-Speaker Human Voices (edge-tts)",
        "voice_cast": VOICE_CAST,
        "total_duration_sec": round(global_cursor, 3),
        "scenes": scenes_manifest,
    }
    manifest_path = out_dir / "manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(f"Synthesized {len(scenes_manifest)} scenes ({global_cursor:.2f}s total) -> {manifest_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Synthesize human narration for screenplay.")
    parser.add_argument("--screenplay", required=True, help="Path to approved screenplay JSON.")
    parser.add_argument("--out-dir", default=None, help="Directory for WAV files and manifest.json (defaults to output/audio/<screenplay_stem>_vo).")
    args = parser.parse_args()
    sp_path = Path(args.screenplay).resolve()
    if args.out_dir:
        out_dir = Path(args.out_dir).resolve()
    else:
        stem = sp_path.stem.replace("_screenplay", "")
        out_dir = sp_path.parents[1] / "audio" / f"{stem}_vo"
    asyncio.run(run_synthesis(sp_path, out_dir))


if __name__ == "__main__":
    main()
