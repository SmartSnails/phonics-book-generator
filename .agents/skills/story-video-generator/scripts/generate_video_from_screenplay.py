#!/usr/bin/env python3
"""
Step 2 Master Orchestrator: Converts a Human-Approved Screenplay into an
Animated Storybook Video (.mp4).

Enforces:
1. Step 1 5-Gate Screenplay Rubric Evaluation + Explicit Human Approval Status
2. Anti-Robotic-TTS Gate (Strictly bans /usr/bin/say, AVSpeechSynthesizer, Samantha)
3. 100% Google Flow Character & Storyline Coloring Page Keyframe Lock
4. Verbatim Act Storyline Narration via Multi-Character Neural Human Voices
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


BANNED_TTS = {"/usr/bin/say", "avspeechsynthesizer", "samantha", "espeak"}


def verify_screenplay_ready_for_video(screenplay_path: Path) -> dict:
    if not screenplay_path.exists():
        raise FileNotFoundError(f"Screenplay JSON not found: {screenplay_path}")

    with open(screenplay_path, "r", encoding="utf-8") as f:
        sp = json.load(f)

    # 1. Verify Step 1 5-Gate Evaluator passes
    eval_script = (
        screenplay_path.parents[2]
        / ".agents/skills/story-screenplay-generator/scripts/evaluate_screenplay.py"
    )
    if eval_script.exists():
        res = subprocess.run(
            [sys.executable, str(eval_script), "--input", str(screenplay_path)],
            capture_output=True,
            text=True,
        )
        if res.returncode != 0:
            raise RuntimeError(
                f"Screenplay failed Step 1 evaluation:\n{res.stdout}\n{res.stderr}"
            )

    # 2. Verify Human Approval Gate
    approval = sp.get("human_approval", {})
    if approval.get("status") != "APPROVED":
        raise PermissionError(
            f"STOP: Screenplay human_approval.status is '{approval.get('status')}' "
            "(must be 'APPROVED' before Step 2 video generation can run)."
        )

    # 3. Verify Human-Readable .txt Screenplay exists in Blends folder
    txt_path = Path(sp.get("human_readable_screenplay_txt_path", ""))
    if not txt_path.exists():
        raise FileNotFoundError(
            f"Human-readable screenplay text file missing in Blends folder: {txt_path}"
        )

    # 4. Verify Voice Casting Spec bans basic OS TTS
    vc = sp.get("voice_casting_spec", {})
    if vc.get("allow_basic_os_tts", True) is not False:
        raise ValueError("voice_casting_spec.allow_basic_os_tts must be false.")
    active_engine = str(vc.get("active_voice_engine", "")).lower()
    for banned in BANNED_TTS:
        if banned in active_engine:
            raise ValueError(f"Banned robotic TTS engine detected: {active_engine}")

    # 5. Verify every beat's storyline B&W and colored keyframes exist on disk
    for beat in sp.get("beats", []):
        bw = Path(beat.get("source_scene_image_path", ""))
        col = Path(beat.get("colored_scene_image_path", str(bw)))
        if not bw.exists():
            raise FileNotFoundError(f"Beat {beat.get('beat_number')} B&W keyframe missing: {bw}")
        if not col.exists():
            raise FileNotFoundError(f"Beat {beat.get('beat_number')} Colored keyframe missing: {col}")
        if beat.get("keyframe_lock_mode") != "start_and_end_exact_image":
            raise ValueError(
                f"Beat {beat.get('beat_number')} must have keyframe_lock_mode='start_and_end_exact_image'"
            )

    print("[PASS] Pre-flight gate check: Screenplay is APPROVED and all Google Flow keyframes exist.")
    return sp


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert approved screenplay to animated MP4 video.")
    parser.add_argument("--screenplay", required=True, help="Path to approved screenplay JSON.")
    parser.add_argument("--vo-manifest", default="output/audio/act1_human_vo/manifest.json", help="Path to synthesized human voice manifest.json.")
    parser.add_argument("--out-mp4", required=True, help="Primary output MP4 path (e.g. output/Blends/Act1_In_The_Garden_Animation.mp4).")
    parser.add_argument("--copy-mp4", default=None, help="Optional secondary MP4 path (e.g. output/videos/act1_in_the_garden_animation.mp4).")
    args = parser.parse_args()

    screenplay_path = Path(args.screenplay).resolve()
    verify_screenplay_ready_for_video(screenplay_path)

    vo_manifest = Path(args.vo_manifest).resolve()
    if not vo_manifest.exists():
        synth_script = Path(__file__).parent / "synthesize_human_narration.py"
        subprocess.run(
            [
                sys.executable,
                str(synth_script),
                "--screenplay",
                str(screenplay_path),
                "--out-dir",
                str(vo_manifest.parent),
            ],
            check=True,
        )

    swift_script = Path(__file__).parent / "render_screenplay_video.swift"
    out_mp4 = Path(args.out_mp4).resolve()
    subprocess.run(
        [
            "swift",
            "-module-cache-path",
            "/tmp/swift_cache",
            str(swift_script),
            str(vo_manifest),
            str(out_mp4),
        ],
        check=True,
    )

    if args.copy_mp4:
        copy_path = Path(args.copy_mp4).resolve()
        copy_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(out_mp4, copy_path)
        print(f"Copied rendered MP4 -> {copy_path}")


if __name__ == "__main__":
    main()
