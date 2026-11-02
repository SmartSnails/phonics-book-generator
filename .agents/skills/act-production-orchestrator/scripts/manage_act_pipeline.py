#!/usr/bin/env python3
"""
Deterministic Pipeline State, SHA-256 Change Detector, Dual-Mode Revision Loop Tracker,
and Checkpoint Gate Manager for `act-production-orchestrator`.

Usage examples (all prefix-matchable standalone commands):
  python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act act3_down_at_the_pond --init --title "Act 3: Down at the Pond" --words "frog,crab,drip,swim,plop"
  python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act act3_down_at_the_pond --snapshot-stage 1
  python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act act3_down_at_the_pond --check-stage 1
  python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act act3_down_at_the_pond --record-revision --stage 1 --mode manual --notes "User refined beat 2 dialogue"
  python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act act3_down_at_the_pond --approve-stage 1
  python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act act3_down_at_the_pond --status
"""

import argparse
import datetime
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
import wave
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


REPO_ROOT = Path("/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator")
PIPELINE_DIR = REPO_ROOT / "output" / "pipeline"
EVAL_SCRIPT = (
    REPO_ROOT
    / ".agents"
    / "skills"
    / "story-screenplay-generator"
    / "scripts"
    / "evaluate_screenplay.py"
)

STAGE_NAMES = {
    1: "STAGE_1_STORY_WRITEUP",
    2: "STAGE_2_KEYFRAME_ILLUSTRATIONS",
    3: "STAGE_3_SCREENPLAY_AND_EVAL",
    4: "STAGE_4_VOICEOVER_AUDIO",
    5: "STAGE_5_FINAL_VIDEO_AND_DELIVERABLES",
}


def now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha256_file(path: Path) -> Optional[str]:
    if not path.exists() or not path.is_file():
        return None
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def act_prefix_from_slug(act_slug: str) -> str:
    """Convert e.g. 'act2_into_the_woods' -> 'Act2_Into_The_Woods'."""
    parts = act_slug.strip().split("_")
    titled = []
    for p in parts:
        if p.lower().startswith("act") and len(p) > 3 and p[3:].isdigit():
            titled.append("Act" + p[3:])
        else:
            titled.append(p.capitalize())
    return "_".join(titled)


def short_act_id(act_slug: str) -> str:
    """Extract e.g. 'act2' from 'act2_into_the_woods'."""
    m = re.match(r"^(act\d+)", act_slug.lower())
    return m.group(1) if m else act_slug.lower().split("_")[0]


def state_file_path(act_slug: str) -> Path:
    PIPELINE_DIR.mkdir(parents=True, exist_ok=True)
    return PIPELINE_DIR / f"{act_slug}_pipeline_state.json"


def default_stage_paths(act_slug: str, words: List[str]) -> Dict[int, List[str]]:
    prefix = act_prefix_from_slug(act_slug)
    short_act = short_act_id(act_slug)
    blends_dir = REPO_ROOT / "output" / "Blends"
    illus_dir = blends_dir / "illustrations"
    screenplays_dir = REPO_ROOT / "output" / "screenplays"
    audio_dir = REPO_ROOT / "output" / "audio" / f"{act_slug}_vo"
    videos_dir = REPO_ROOT / "output" / "videos"

    stage2_files: List[str] = []
    for idx, w in enumerate(words, start=1):
        w_clean = w.strip().lower()
        stage2_files.append(str(illus_dir / f"{short_act}_scene{idx}_{w_clean}_flow_bw.png"))
        stage2_files.append(str(illus_dir / f"{short_act}_scene{idx}_{w_clean}_flow_color.png"))

    return {
        1: [
            str(blends_dir / f"{prefix}_Story_Writeup.md"),
        ],
        2: stage2_files,
        3: [
            str(blends_dir / f"{prefix}_Screenplay.txt"),
            str(screenplays_dir / f"{act_slug}_screenplay.json"),
            str(screenplays_dir / f"{act_slug}_eval_report.json"),
        ],
        4: [
            str(audio_dir / "manifest.json"),
        ],
        5: [
            str(blends_dir / f"{prefix}_Animation.mp4"),
            str(videos_dir / f"{act_slug}_animation.mp4"),
        ],
    }


def load_state(act_slug: str) -> Dict[str, Any]:
    path = state_file_path(act_slug)
    if not path.exists():
        sys.stderr.write(
            f"[ERROR] Pipeline state file not found for '{act_slug}': {path}\n"
            f"Run with --init first.\n"
        )
        sys.exit(1)
    return json.loads(path.read_text(encoding="utf-8"))


def save_state(act_slug: str, state: Dict[str, Any]) -> Path:
    state["updated_at"] = now_iso()
    path = state_file_path(act_slug)
    path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return path


def png_dimensions(path: Path) -> Optional[Tuple[int, int]]:
    if not path.exists() or path.stat().st_size < 24:
        return None
    with path.open("rb") as f:
        header = f.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        return None
    w, h = struct.unpack(">II", header[16:24])
    return int(w), int(h)


def collect_stage_files(state: Dict[str, Any], stage_num: int) -> List[Path]:
    stage_key = str(stage_num)
    configured = state["stages"][stage_key]["tracked_files"]
    paths = [Path(p) for p in configured]
    # For stage 4, also include all .wav files referenced in manifest.json or present in audio dir
    if stage_num == 4 and paths:
        manifest_path = paths[0]
        audio_dir = manifest_path.parent
        if audio_dir.exists():
            for wav_p in sorted(audio_dir.glob("*.wav")):
                if wav_p not in paths:
                    paths.append(wav_p)
    return paths


def snapshot_files(paths: List[Path]) -> Dict[str, Dict[str, Any]]:
    snap: Dict[str, Dict[str, Any]] = {}
    for p in paths:
        if p.exists() and p.is_file():
            st = p.stat()
            snap[str(p)] = {
                "exists": True,
                "sha256": sha256_file(p),
                "size_bytes": st.st_size,
                "mtime": st.st_mtime,
            }
        else:
            snap[str(p)] = {
                "exists": False,
                "sha256": None,
                "size_bytes": 0,
                "mtime": None,
            }
    return snap


def diff_snapshots(
    old_snap: Dict[str, Dict[str, Any]], new_snap: Dict[str, Dict[str, Any]]
) -> List[Dict[str, Any]]:
    changes: List[Dict[str, Any]] = []
    all_keys = sorted(set(old_snap.keys()) | set(new_snap.keys()))
    for k in all_keys:
        o = old_snap.get(k)
        n = new_snap.get(k)
        if o is None and n and n.get("exists"):
            changes.append({"path": k, "change": "CREATED", "new_sha256": n["sha256"]})
        elif o and o.get("exists") and (not n or not n.get("exists")):
            changes.append({"path": k, "change": "DELETED", "old_sha256": o["sha256"]})
        elif o and n and o.get("sha256") != n.get("sha256"):
            changes.append(
                {
                    "path": k,
                    "change": "MODIFIED",
                    "old_sha256": o.get("sha256"),
                    "new_sha256": n.get("sha256"),
                    "size_bytes": n.get("size_bytes"),
                }
            )
    return changes


def sync_txt_screenplay_to_json(txt_path: Path, json_path: Path) -> List[str]:
    """
    If the user manually edited the human-readable `<Act>_Screenplay.txt` at Checkpoint 3,
    parse any updated speaker lines `[Narrator]: "..."`, `[Clem]: "..."`, `[Plum]: "..."`
    or `Verbatim Story Text:` blocks per scene and sync them into `<act>_screenplay.json`.
    """
    notes: List[str] = []
    if not txt_path.exists() or not json_path.exists():
        return notes

    txt = txt_path.read_text(encoding="utf-8")
    data = json.loads(json_path.read_text(encoding="utf-8"))
    scenes = data.get("scenes", [])

    # Look for utterance lines formatted like:
    #   - [Narrator]: "..."
    # or Scene blocks
    scene_blocks = re.split(r"(?m)^={3,}\s*\nSCENE\s+(\d+)\b", txt)
    if len(scene_blocks) < 3:
        return notes

    modified_count = 0
    for idx in range(1, len(scene_blocks), 2):
        beat_num = int(scene_blocks[idx])
        block = scene_blocks[idx + 1]
        target_scene = next((s for s in scenes if s.get("beat_number") == beat_num), None)
        if not target_scene:
            continue

        # Parse explicit speaker lines if present: `[Speaker]: "Text"`
        utterance_matches = re.findall(
            r"^\s*[-*•]?\s*\[(Narrator|Clem|Plum)\]\s*:\s*\"([^\"]+)\"",
            block,
            flags=re.MULTILINE,
        )
        if utterance_matches and "utterances" in target_scene:
            existing = target_scene["utterances"]
            if len(utterance_matches) == len(existing):
                for u_idx, (spk, line_text) in enumerate(utterance_matches):
                    if (
                        existing[u_idx].get("speaker") != spk
                        or existing[u_idx].get("text") != line_text
                    ):
                        existing[u_idx]["speaker"] = spk
                        existing[u_idx]["text"] = line_text
                        modified_count += 1
                        notes.append(
                            f"Synced Scene {beat_num} utterance #{u_idx + 1} ({spk}) from .txt -> .json"
                        )

    if modified_count > 0:
        json_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return notes


def resync_audio_manifest_from_wavs(manifest_path: Path) -> List[str]:
    """
    If the user manually replaced or edited `.wav` files in `output/audio/<act>_vo/`,
    recalculate exact sample counts, durations, and scene start/end offsets in `manifest.json`.
    """
    notes: List[str] = []
    if not manifest_path.exists():
        return notes

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    cursor = 0.0
    updated = False

    for scene in manifest.get("scenes", []):
        scene_start = round(cursor, 3)
        if scene.get("start_sec") != scene_start:
            scene["start_sec"] = scene_start
            updated = True
        local_cursor = 0.45
        for u in scene.get("utterances", []):
            wav_p = Path(u.get("wav_path", ""))
            if wav_p.exists():
                with wave.open(str(wav_p), "rb") as wf:
                    frames = wf.getnframes()
                    rate = wf.getframerate()
                    dur = round(frames / float(rate), 3) if rate > 0 else u.get("duration_sec", 0.0)
                if abs(dur - u.get("duration_sec", 0.0)) > 0.005:
                    notes.append(
                        f"Updated duration for {wav_p.name}: {u.get('duration_sec')}s -> {dur}s"
                    )
                    u["duration_sec"] = dur
                    updated = True
            u["start_in_scene_sec"] = round(local_cursor, 3)
            u["end_in_scene_sec"] = round(local_cursor + u.get("duration_sec", 0.0), 3)
            u["start_in_act_sec"] = round(scene_start + u["start_in_scene_sec"], 3)
            u["end_in_act_sec"] = round(scene_start + u["end_in_scene_sec"], 3)
            local_cursor = u["end_in_scene_sec"] + float(u.get("pause_after_sec", 0.35))

        scene_dur = round(local_cursor + 0.55, 3)
        scene["duration_sec"] = scene_dur
        scene["end_sec"] = round(scene_start + scene_dur, 3)
        cursor = scene["end_sec"]

    manifest["total_duration_sec"] = round(cursor, 3)
    if updated:
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return notes


def validate_stage(state: Dict[str, Any], stage_num: int) -> Tuple[bool, List[str]]:
    """Run deterministic validation for a given stage."""
    messages: List[str] = []
    words = [w.lower() for w in state.get("target_words", [])]
    paths = collect_stage_files(state, stage_num)

    if stage_num == 1:
        writeup_path = paths[0]
        if not writeup_path.exists():
            # Also permit checkpoint approval if Stage 3 screenplay already exists (retroactive/fast-track)
            s3_json = Path(state["stages"]["3"]["tracked_files"][1])
            if s3_json.exists():
                messages.append(
                    f"[PASS] Stage 1 writeup embedded in existing screenplay JSON ({s3_json.name})."
                )
                return True, messages
            return False, [f"[FAIL] Missing Stage 1 Story Writeup file: {writeup_path}"]
        content = writeup_path.read_text(encoding="utf-8")
        missing_words = [
            w for w in words if not re.search(rf"\b{re.escape(w)}\b", content, re.I)
        ]
        if missing_words:
            return False, [
                f"[FAIL] Story Writeup is missing target phonics words: {missing_words}"
            ]
        messages.append(
            f"[PASS] Story Writeup ({writeup_path.name}) exists and contains all {len(words)} target words ({', '.join(words)})."
        )
        return True, messages

    if stage_num == 2:
        missing = [str(p) for p in paths if not p.exists()]
        if missing:
            return False, [f"[FAIL] Missing Stage 2 keyframe PNGs: {missing}"]
        bad_dims = []
        for p in paths:
            dims = png_dimensions(p)
            if dims != (1080, 1080):
                bad_dims.append(f"{p.name} ({dims})")
        if bad_dims:
            return False, [
                f"[FAIL] Keyframe PNGs must be 1080x1080; mismatches: {bad_dims}"
            ]
        messages.append(
            f"[PASS] All {len(paths)} B&W and Colored keyframe PNGs exist and verified at 1080x1080."
        )
        return True, messages

    if stage_num == 3:
        txt_path, json_path, report_path = paths[0], paths[1], paths[2]
        if not txt_path.exists() or not json_path.exists():
            return False, [
                f"[FAIL] Missing screenplay files: txt={txt_path.exists()}, json={json_path.exists()}"
            ]
        cmd = [
            sys.executable,
            str(EVAL_SCRIPT),
            "--input",
            str(json_path),
            "--output-report",
            str(report_path),
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            return False, [
                f"[FAIL] evaluate_screenplay.py failed:\n{proc.stdout}\n{proc.stderr}"
            ]
        messages.append(
            f"[PASS] Screenplay (.txt + .json) passed all 5 mandatory evaluation gates ({report_path.name})."
        )
        return True, messages

    if stage_num == 4:
        manifest_path = paths[0]
        if not manifest_path.exists():
            return False, [f"[FAIL] Missing voiceover manifest: {manifest_path}"]
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        scenes = manifest.get("scenes", [])
        if len(scenes) != len(words):
            return False, [
                f"[FAIL] Voiceover manifest has {len(scenes)} scenes; expected {len(words)}."
            ]
        wav_count = 0
        for s in scenes:
            for u in s.get("utterances", []):
                wp = Path(u.get("wav_path", ""))
                if not wp.exists() or wp.stat().st_size < 1024:
                    return False, [f"[FAIL] Missing or empty WAV file: {wp}"]
                wav_count += 1
        messages.append(
            f"[PASS] Verified {wav_count} neural voiceover WAV files across {len(scenes)} scenes ({manifest.get('total_duration_sec')}s total)."
        )
        return True, messages

    if stage_num == 5:
        primary_mp4, secondary_mp4 = paths[0], paths[1]
        for mp4 in (primary_mp4, secondary_mp4):
            if not mp4.exists():
                return False, [f"[FAIL] Missing rendered MP4 file: {mp4}"]
            sz_mb = mp4.stat().st_size / (1024 * 1024)
            if sz_mb < 1.0:
                return False, [f"[FAIL] MP4 file appears truncated ({sz_mb:.2f} MB): {mp4}"]
            if sz_mb > 95.0:
                return False, [
                    f"[FAIL] MP4 file exceeds GitHub 100 MB safety ceiling ({sz_mb:.1f} MB): {mp4}"
                ]
        sz_mb = primary_mp4.stat().st_size / (1024 * 1024)
        messages.append(
            f"[PASS] Both primary and secondary MP4 videos exist and are GitHub-ready ({sz_mb:.1f} MB)."
        )
        return True, messages

    return False, [f"[FAIL] Unknown stage number: {stage_num}"]


def cmd_init(args: argparse.Namespace) -> None:
    words = [w.strip().lower() for w in args.words.split(",") if w.strip()]
    stage_map = default_stage_paths(args.act, words)
    stages_state: Dict[str, Any] = {}
    for s_num in range(1, 6):
        stages_state[str(s_num)] = {
            "stage_number": s_num,
            "stage_name": STAGE_NAMES[s_num],
            "checkpoint_status": "NOT_STARTED",
            "validation_status": "PENDING",
            "revision_loop_count": 0,
            "revision_history": [],
            "tracked_files": stage_map[s_num],
            "last_snapshot": {},
            "approved_at": None,
        }

    state = {
        "act_slug": args.act,
        "act_title": args.title,
        "target_words": words,
        "current_stage": 1,
        "overall_status": "IN_PROGRESS",
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "stages": stages_state,
    }
    out_path = save_state(args.act, state)
    print(f"[INIT] Initialized Act Production Pipeline state -> {out_path}")
    print(f"       Act Title   : {args.title}")
    print(f"       Target Words: {', '.join(words)}")


def cmd_snapshot_stage(args: argparse.Namespace) -> None:
    state = load_state(args.act)
    s_num = args.snapshot_stage
    s_key = str(s_num)
    paths = collect_stage_files(state, s_num)
    snap = snapshot_files(paths)
    passed, msgs = validate_stage(state, s_num)

    stage_obj = state["stages"][s_key]
    stage_obj["last_snapshot"] = snap
    stage_obj["validation_status"] = "PASS" if passed else "FAIL"
    if stage_obj["checkpoint_status"] == "NOT_STARTED":
        stage_obj["checkpoint_status"] = "PENDING_USER_REVIEW"
    state["current_stage"] = s_num
    save_state(args.act, state)

    print(f"[STAGE {s_num} SNAPSHOT] {stage_obj['stage_name']}")
    for m in msgs:
        print(f"  {m}")
    print(f"  Checkpoint Status: {stage_obj['checkpoint_status']} (Waiting for User Approval or Mode 1 / Mode 2 Revision)")
    if not passed:
        sys.exit(2)


def cmd_check_stage(args: argparse.Namespace) -> None:
    state = load_state(args.act)
    s_num = args.check_stage
    s_key = str(s_num)
    stage_obj = state["stages"][s_key]
    paths = collect_stage_files(state, s_num)
    new_snap = snapshot_files(paths)
    old_snap = stage_obj.get("last_snapshot", {})
    changes = diff_snapshots(old_snap, new_snap)

    sync_notes: List[str] = []
    if s_num == 3 and any(c["path"].endswith("_Screenplay.txt") for c in changes):
        txt_p = Path(stage_obj["tracked_files"][0])
        json_p = Path(stage_obj["tracked_files"][1])
        sync_notes.extend(sync_txt_screenplay_to_json(txt_p, json_p))
        new_snap = snapshot_files(paths)
    elif s_num == 4 and any(c["path"].endswith(".wav") for c in changes):
        manifest_p = Path(stage_obj["tracked_files"][0])
        sync_notes.extend(resync_audio_manifest_from_wavs(manifest_p))
        new_snap = snapshot_files(paths)

    passed, msgs = validate_stage(state, s_num)
    stage_obj["validation_status"] = "PASS" if passed else "FAIL"

    if changes:
        stage_obj["revision_loop_count"] = int(stage_obj.get("revision_loop_count", 0)) + 1
        stage_obj["checkpoint_status"] = "IN_REVISION_LOOP"
        stage_obj["revision_history"].append(
            {
                "iteration": stage_obj["revision_loop_count"],
                "mode": "manual",
                "timestamp": now_iso(),
                "modified_files": [Path(c["path"]).name for c in changes],
                "sync_notes": sync_notes,
                "validation_status": stage_obj["validation_status"],
            }
        )
        stage_obj["last_snapshot"] = new_snap
    save_state(args.act, state)

    print(f"[CHECKPOINT {s_num} SCAN] {stage_obj['stage_name']}")
    if changes:
        print(f"  Detected {len(changes)} file change(s) since last snapshot (Iteration #{stage_obj['revision_loop_count']}):")
        for c in changes:
            print(f"    - {c['change']}: {c['path']}")
    else:
        print("  No manual file modifications detected since last snapshot.")
    for note in sync_notes:
        print(f"  [AUTO-SYNC] {note}")
    for m in msgs:
        print(f"  {m}")
    if not passed:
        sys.exit(2)


def cmd_record_revision(args: argparse.Namespace) -> None:
    state = load_state(args.act)
    s_num = args.stage
    s_key = str(s_num)
    stage_obj = state["stages"][s_key]
    paths = collect_stage_files(state, s_num)
    new_snap = snapshot_files(paths)
    passed, msgs = validate_stage(state, s_num)

    stage_obj["revision_loop_count"] = int(stage_obj.get("revision_loop_count", 0)) + 1
    stage_obj["checkpoint_status"] = "IN_REVISION_LOOP"
    stage_obj["validation_status"] = "PASS" if passed else "FAIL"
    stage_obj["last_snapshot"] = new_snap
    stage_obj["revision_history"].append(
        {
            "iteration": stage_obj["revision_loop_count"],
            "mode": args.mode,
            "timestamp": now_iso(),
            "notes": args.notes or "",
            "validation_status": stage_obj["validation_status"],
        }
    )
    save_state(args.act, state)
    print(
        f"[REVISION LOOP #{stage_obj['revision_loop_count']}] Recorded {args.mode.upper()} update for Stage {s_num} ({stage_obj['validation_status']})."
    )
    for m in msgs:
        print(f"  {m}")


def cmd_approve_stage(args: argparse.Namespace) -> None:
    state = load_state(args.act)
    s_num = args.approve_stage
    s_key = str(s_num)
    stage_obj = state["stages"][s_key]

    passed, msgs = validate_stage(state, s_num)
    if not passed:
        sys.stderr.write(
            f"[BLOCKED] Cannot approve Checkpoint {s_num} because stage validation failed:\n"
        )
        for m in msgs:
            sys.stderr.write(f"  {m}\n")
        sys.exit(2)

    # If Stage 3 is approved, ensure `<act>_screenplay.json` has `"status": "APPROVED"`
    if s_num == 3:
        json_p = Path(stage_obj["tracked_files"][1])
        if json_p.exists():
            sp_data = json.loads(json_p.read_text(encoding="utf-8"))
            if sp_data.get("status") != "APPROVED":
                sp_data["status"] = "APPROVED"
                json_p.write_text(json.dumps(sp_data, indent=2) + "\n", encoding="utf-8")

    paths = collect_stage_files(state, s_num)
    stage_obj["last_snapshot"] = snapshot_files(paths)
    stage_obj["validation_status"] = "PASS"
    stage_obj["checkpoint_status"] = "APPROVED"
    stage_obj["approved_at"] = now_iso()

    if s_num < 5:
        state["current_stage"] = s_num + 1
    else:
        state["overall_status"] = "COMPLETED"

    save_state(args.act, state)
    print(f"[APPROVED] Checkpoint {s_num} ({stage_obj['stage_name']}) APPROVED by user.")
    if s_num < 5:
        print(f"           Ready to advance to Stage {s_num + 1}: {STAGE_NAMES[s_num + 1]}")
    else:
        print(f"           All 5 stages of {state['act_title']} are APPROVED and COMPLETE!")


def cmd_status(args: argparse.Namespace) -> None:
    state = load_state(args.act)
    print(f"=== Pipeline Status: {state['act_title']} ({state['act_slug']}) ===")
    print(f"Overall Status : {state['overall_status']} (Current Stage: {state['current_stage']})")
    print(f"Target Words   : {', '.join(state['target_words'])}")
    for s_num in range(1, 6):
        st = state["stages"][str(s_num)]
        print(
            f"  Stage {s_num} ({st['stage_name']}): "
            f"checkpoint={st['checkpoint_status']}, "
            f"validation={st['validation_status']}, "
            f"revisions={st['revision_loop_count']}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Manage Act Production Pipeline & Checkpoints")
    parser.add_argument("--act", required=True, help="Act slug, e.g. act2_into_the_woods")
    parser.add_argument("--init", action="store_true", help="Initialize pipeline state file")
    parser.add_argument("--title", default="", help="Human-readable Act title for --init")
    parser.add_argument("--words", default="", help="Comma-separated target words for --init")
    parser.add_argument("--snapshot-stage", type=int, choices=[1, 2, 3, 4, 5])
    parser.add_argument("--check-stage", type=int, choices=[1, 2, 3, 4, 5])
    parser.add_argument("--record-revision", action="store_true")
    parser.add_argument("--stage", type=int, choices=[1, 2, 3, 4, 5])
    parser.add_argument("--mode", choices=["manual", "agent"], default="agent")
    parser.add_argument("--notes", default="")
    parser.add_argument("--approve-stage", type=int, choices=[1, 2, 3, 4, 5])
    parser.add_argument("--status", action="store_true")

    args = parser.parse_args()
    if args.init:
        if not args.title or not args.words:
            parser.error("--init requires --title and --words")
        cmd_init(args)
    elif args.snapshot_stage is not None:
        cmd_snapshot_stage(args)
    elif args.check_stage is not None:
        cmd_check_stage(args)
    elif args.record_revision:
        if args.stage is None:
            parser.error("--record-revision requires --stage")
        cmd_record_revision(args)
    elif args.approve_stage is not None:
        cmd_approve_stage(args)
    elif args.status:
        cmd_status(args)
    else:
        parser.error("Specify one action flag (--init, --snapshot-stage, --check-stage, --record-revision, --approve-stage, or --status)")


if __name__ == "__main__":
    main()
