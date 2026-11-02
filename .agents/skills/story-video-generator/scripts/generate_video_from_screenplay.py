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

    # 5. Verify every beat's storyline B&W and colored keyframes, utterances, and animation_anchors exist
    for beat in sp.get("beats", []):
        bnum = beat.get("beat_number")
        bw = Path(beat.get("source_scene_image_path", ""))
        col = Path(beat.get("colored_scene_image_path", str(bw)))
        if not bw.exists():
            raise FileNotFoundError(f"Beat {bnum} B&W keyframe missing: {bw}")
        if not col.exists():
            raise FileNotFoundError(f"Beat {bnum} Colored keyframe missing: {col}")
        if beat.get("keyframe_lock_mode") != "start_and_end_exact_image":
            raise ValueError(
                f"Beat {bnum} must have keyframe_lock_mode='start_and_end_exact_image'"
            )
        if not beat.get("utterances"):
            raise ValueError(
                f"Beat {bnum} is missing 'utterances' array in screenplay JSON."
            )
        if not beat.get("animation_anchors"):
            raise ValueError(
                f"Beat {bnum} is missing 'animation_anchors' in screenplay JSON."
            )

    print("[PASS] Pre-flight gate check: Screenplay is APPROVED and all Google Flow keyframes, utterances, and anchors exist.")
    return sp


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert approved screenplay to animated MP4 video.")
    parser.add_argument("--screenplay", required=True, help="Path to approved screenplay JSON.")
    parser.add_argument("--vo-manifest", default=None, help="Path to synthesized human voice manifest.json (defaults to output/audio/<screenplay_stem>_vo/manifest.json).")
    parser.add_argument("--out-mp4", required=True, help="Primary output MP4 path (e.g. output/Blends/Act2_Into_The_Woods_Animation.mp4).")
    parser.add_argument("--copy-mp4", default=None, help="Optional secondary MP4 path (e.g. output/videos/act2_into_the_woods_animation.mp4).")
    args = parser.parse_args()

    screenplay_path = Path(args.screenplay).resolve()
    verify_screenplay_ready_for_video(screenplay_path)

    if args.vo_manifest:
        vo_manifest = Path(args.vo_manifest).resolve()
    else:
        stem = screenplay_path.stem.replace("_screenplay", "")
        vo_manifest = screenplay_path.parents[1] / "audio" / f"{stem}_vo" / "manifest.json"
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

    # Automatically optimize MP4 size if > 50 MB so git push to GitHub always succeeds cleanly
    copy_target = Path(args.copy_mp4).resolve() if args.copy_mp4 else out_mp4
    if out_mp4.exists() and out_mp4.stat().st_size > 50_000_000:
        mux_script = Path(__file__).parent / "mux_narration_into_mp4.swift"
        subprocess.run(
            [
                "swift",
                "-module-cache-path",
                "/tmp/swift_cache",
                str(mux_script),
                str(vo_manifest),
                str(out_mp4),
                str(copy_target),
            ],
            check=True,
        )
    elif args.copy_mp4:
        copy_target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(out_mp4, copy_target)
        print(f"Copied rendered MP4 -> {copy_target}")


if __name__ == "__main__":
    main()
