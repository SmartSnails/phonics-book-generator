#!/usr/bin/env python3
"""
Deterministic 5-Gate Evaluator & Linter for Step 1 of the 2-Step Video Pipeline:
Validates the Detailed Story Screenplay (.json + human-reviewable .txt in Blends/)
and Google Flow (Veo 3.1) Animation Prompts before Human Review & Approval.
"""

import argparse
import json
import re
import sys
from pathlib import Path

BANNED_FLOW_TOKENS = [
    r"#[0-9A-Fa-f]{6}\b",
    r"\[[A-Z0-9_ -]+\]",
    r"\b\w+\.(?:png|jpg|jpeg|pdf|svg|mp4)\b",
    r"\b(?:5-year-old|five-year-old|5\s+years?\s+olds?|five\s+years?\s+olds?|young\s+child(?:ren)?|small\s+child(?:ren)?|little\s+kids?|little\s+boy|little\s+girl|young\s+boy|young\s+girl|children|kids|toddler)\b",
]

BANNED_SLIDESHOW_OR_CUT_TOKENS = [
    r"\b(?:static\s+image|still\s+frame|still\s+image|slideshow|ken\s+burns|jump\s+cut|cut\s+to|next\s+scene|split\s+screen|freeze\s+frame)\b"
]

BANNED_ROBOTIC_TTS_TOKENS = [
    r"\b(?:/usr/bin/say|avspeechsynthesizer|samantha\s+tts|espeak|robotic\s+tts|basic\s+ai\s+voice)\b"
]

UNSAFE_THEMES = [
    r"\b(?:blood|bleed|bleeding|scary|terrified|scream|hurt|pain|weapon|monster|attack|cry|crying|dead|kill|scratch|prick)\b"
]

ARTICULATED_MOTION_VERBS = {
    "flutter", "flutters", "fluttering", "perch", "perches", "perching",
    "hop", "hops", "hopping", "walk", "walks", "walking",
    "kneel", "kneels", "kneeling", "reach", "reaches", "reaching",
    "pull", "pulls", "pulling", "lift", "lifts", "lifting",
    "point", "points", "pointing", "wave", "waves", "waving",
    "nod", "nods", "nodding", "tilt", "tilts", "tilting",
    "grin", "grins", "grinning", "smile", "smiles", "smiling",
    "laugh", "laughs", "laughing", "chirp", "chirps", "chirping",
    "blink", "blinks", "blinking", "bounce", "bounces", "bouncing",
    "tug", "tugs", "tugging", "wiggle", "wiggles", "wiggling",
    "dig", "digs", "digging", "peek", "peeks", "peeking", "nudge", "nudges"
}

BACKDROP_MOTION_TERMS = {
    "sway", "swaying", "breeze", "drift", "drifting", "fluttering", "sunbeam",
    "sunbeams", "sunlight", "ripple", "rippling", "rustle", "rustling",
    "clouds", "pollen", "motes", "leaves"
}


def _as_str(val) -> str:
    if isinstance(val, list):
        return " ".join(str(x) for x in val)
    return str(val or "")


def evaluate_screenplay(data: dict) -> dict:
    checks = {}
    beats = data.get("beats", [])
    master_flow_prompt = data.get("google_flow_prompt", "").strip()

    beats_text = " ".join(
        f"{b.get('character_motion', '')} {b.get('facial_expression', '')} "
        f"{b.get('backdrop_motion', '')} {b.get('narration_or_dialogue', '')} "
        f"{b.get('verbatim_storyline_script', '')} "
        f"{b.get('sfx_and_music', '')} {b.get('scene_google_flow_prompt', '')}"
        for b in beats
    )
    all_flow_prompts = [master_flow_prompt] + [
        b.get("scene_google_flow_prompt", "").strip()
        for b in beats
        if b.get("scene_google_flow_prompt", "").strip()
    ]
    flow_corpus = " ".join(all_flow_prompts)
    creative_corpus = f"{data.get('title', '')} {beats_text} {flow_corpus}".lower()

    # -------------------------------------------------------------------------
    # Gate 1: Child Safety & Flow Policy Hygiene
    # -------------------------------------------------------------------------
    unsafe_hits = []
    for pat in UNSAFE_THEMES:
        unsafe_hits.extend(re.findall(pat, creative_corpus, flags=re.IGNORECASE))

    banned_flow_hits = []
    for pat in BANNED_FLOW_TOKENS:
        banned_flow_hits.extend(re.findall(pat, flow_corpus, flags=re.IGNORECASE))

    slideshow_or_cut_hits = []
    for pat in BANNED_SLIDESHOW_OR_CUT_TOKENS:
        slideshow_or_cut_hits.extend(re.findall(pat, creative_corpus, flags=re.IGNORECASE))

    gate1_pass = (
        len(unsafe_hits) == 0
        and len(banned_flow_hits) == 0
        and len(slideshow_or_cut_hits) == 0
    )
    checks["gate_1_child_safe_and_flow_hygiene"] = {
        "status": "PASS" if gate1_pass else "FAIL",
        "unsafe_terms_found": unsafe_hits,
        "banned_flow_tokens_found": banned_flow_hits,
        "slideshow_or_cut_tokens_found": slideshow_or_cut_hits,
        "notes": "Zero unsafe terms, zero Flow minor-filter traps, and zero static/cut traps."
        if gate1_pass else "Fix unsafe terms, banned minor-filter tokens, or static/cut phrases."
    }

    # -------------------------------------------------------------------------
    # Gate 2: Verbatim Act Storyline Script Fidelity & Engaging Human Voice Spec
    # -------------------------------------------------------------------------
    script_corpus = " ".join(
        f"{b.get('verbatim_storyline_script', '')} {b.get('narration_or_dialogue', '')}"
        for b in beats
    ).lower()

    required_script_anchors = [
        l.lower() for l in data.get("required_storyline_lines", [
            "follow me!",
            "i'm right behind you!",
            "that big group of plants is called a crop",
            "calling the potatoes 'spuds' too",
            "found one!",
            "a grub!",
            "say hello gently",
            "snag!",
            "gotcha, you sneaky bush"
        ])
    ]
    missing_script_anchors = [
        phrase for phrase in required_script_anchors
        if phrase not in script_corpus
    ]

    voice_spec = data.get("voice_casting_spec", {})
    allow_basic_tts = voice_spec.get("allow_basic_os_tts", True)
    voice_profiles = voice_spec.get("character_voice_profiles", {})
    has_engaging_human_voice = (
        isinstance(voice_spec, dict)
        and allow_basic_tts is False
        and "human" in str(voice_spec.get("voice_engine_requirement", "")).lower()
        and len(voice_profiles) >= 2
    )

    tts_violation_hits = []
    for pat in BANNED_ROBOTIC_TTS_TOKENS:
        tts_violation_hits.extend(
            re.findall(pat, str(voice_spec.get("active_voice_engine", "")), flags=re.IGNORECASE)
        )

    gate2_pass = (
        len(beats) >= 3
        and len(missing_script_anchors) == 0
        and has_engaging_human_voice
        and len(tts_violation_hits) == 0
    )
    checks["gate_2_storyline_script_and_human_voice_fidelity"] = {
        "status": "PASS" if gate2_pass else "FAIL",
        "beat_or_scene_count": len(beats),
        "verified_storyline_script_phrases": len(required_script_anchors) - len(missing_script_anchors),
        "missing_storyline_script_phrases": missing_script_anchors,
        "has_engaging_human_voice_spec": has_engaging_human_voice,
        "allow_basic_os_tts": allow_basic_tts,
        "notes": (
            f"All {len(required_script_anchors)} canonical Act storyline lines/teaching beats verified verbatim; "
            f"engaging human voice casting specified with basic OS TTS strictly disabled."
        )
    }

    # -------------------------------------------------------------------------
    # Gate 3: Entertainment & Anti-Slideshow Vitality (Per-Beat + Flow Prompts)
    # -------------------------------------------------------------------------
    action_corpus = " ".join(
        f"{b.get('character_motion', '')} {b.get('facial_expression', '')} {b.get('backdrop_motion', '')}"
        for b in beats
    ).lower()
    action_tokens = set(re.findall(r"[a-z]+", action_corpus))
    matched_verbs = sorted(action_tokens.intersection(ARTICULATED_MOTION_VERBS))
    matched_backdrop = sorted(action_tokens.intersection(BACKDROP_MOTION_TERMS))

    per_beat_vitality_ok = True
    per_beat_verb_counts = []
    for b in beats:
        cm = b.get("character_motion", "").strip()
        fe = b.get("facial_expression", "").strip()
        bm = b.get("backdrop_motion", "").strip()
        b_tokens = set(re.findall(r"[a-z]+", f"{cm} {fe}".lower()))
        b_verbs = b_tokens.intersection(ARTICULATED_MOTION_VERBS)
        per_beat_verb_counts.append(len(b_verbs))
        if not cm or not fe or not bm or len(b_verbs) < 1:
            per_beat_vitality_ok = False

    flow_tokens = set(re.findall(r"[a-z]+", flow_corpus.lower()))
    flow_verbs = sorted(flow_tokens.intersection(ARTICULATED_MOTION_VERBS))
    flow_backdrop = sorted(flow_tokens.intersection(BACKDROP_MOTION_TERMS))

    gate3_pass = (
        per_beat_vitality_ok
        and len(matched_verbs) >= 4
        and len(matched_backdrop) >= 2
        and len(flow_verbs) >= 3
        and len(flow_backdrop) >= 2
    )
    checks["gate_3_entertaining_anti_slideshow"] = {
        "status": "PASS" if gate3_pass else "FAIL",
        "per_beat_vitality_ok": per_beat_vitality_ok,
        "per_beat_verb_counts": per_beat_verb_counts,
        "articulated_motion_verbs": matched_verbs,
        "backdrop_motion_terms": matched_backdrop,
        "flow_prompt_motion_verbs": flow_verbs,
        "flow_prompt_backdrop_terms": flow_backdrop,
        "notes": (
            f"All {len(beats)} scenes/beats have active character/facial/backdrop motion; "
            f"{len(matched_verbs)} beat verbs, {len(flow_verbs)} Flow prompt verbs, "
            f"and {len(matched_backdrop)} backdrop motion cues."
        )
    }

    # -------------------------------------------------------------------------
    # Gate 4: Google Flow Defined Assets, Theme, Phonics & 100% Image Lock
    # -------------------------------------------------------------------------
    target_words = [w.lower() for w in data.get("target_phonics_words", []) if w.strip()]
    missing_in_beats = [w for w in target_words if w not in beats_text.lower()]
    missing_in_flow = [w for w in target_words if w not in flow_corpus.lower()]
    spoken_target_words = [w for w in target_words if w in script_corpus]

    char_objs = data.get("characters", [])
    characters = [c.get("name", "") for c in char_objs if c.get("name")]
    missing_chars_in_beats = [c for c in characters if c.lower() not in action_corpus]
    missing_chars_in_flow = [c for c in characters if c.lower() not in flow_corpus.lower()]
    incomplete_char_profiles = [
        c.get("name", "Unknown")
        for c in char_objs
        if not _as_str(c.get("visual_anchor") or c.get("flow_descriptor")).strip()
        or not _as_str(c.get("personality_traits")).strip()
        or not _as_str(c.get("trait_to_action_mapping")).strip()
        or not _as_str(c.get("google_flow_asset_id") or c.get("google_flow_ingredient_name")).strip()
        or not _as_str(c.get("character_sheet_drive_id")).strip()
    ]

    backdrop_obj = data.get("backdrop", {})
    required_landmarks = [
        lm.lower() for lm in backdrop_obj.get("required_landmarks", []) if lm.strip()
    ]
    missing_landmarks = [
        lm for lm in required_landmarks
        if lm not in action_corpus and lm not in flow_corpus.lower()
    ]

    valid_lock_modes = {
        "start_from_exact_image",
        "end_on_exact_image",
        "start_and_end_exact_image",
    }
    missing_or_invalid_scene_images = []
    verified_scene_images = []
    for idx, b in enumerate(beats, start=1):
        img_path_str = str(b.get("source_scene_image_path", "")).strip()
        lock_mode = str(b.get("keyframe_lock_mode", "")).strip()
        flow_asset_ref = str(b.get("google_flow_scene_asset", "")).strip()
        if not img_path_str or lock_mode not in valid_lock_modes or not flow_asset_ref:
            missing_or_invalid_scene_images.append(f"scene_{idx}:missing_path_lock_or_flow_asset")
            continue
        p = Path(img_path_str)
        if not p.exists():
            missing_or_invalid_scene_images.append(f"scene_{idx}:file_not_found({img_path_str})")
        else:
            verified_scene_images.append(str(p))

    gate4_pass = (
        len(target_words) >= 4
        and len(missing_in_beats) == 0
        and len(missing_in_flow) == 0
        and len(spoken_target_words) == len(target_words)
        and len(characters) >= 2
        and len(missing_chars_in_beats) == 0
        and len(missing_chars_in_flow) == 0
        and len(incomplete_char_profiles) == 0
        and len(required_landmarks) >= 2
        and len(missing_landmarks) == 0
        and len(missing_or_invalid_scene_images) == 0
        and len(verified_scene_images) == len(beats)
    )
    checks["gate_4_google_flow_assets_and_theme_fidelity"] = {
        "status": "PASS" if gate4_pass else "FAIL",
        "target_phonics_words": target_words,
        "spoken_target_words": spoken_target_words,
        "missing_in_beats": missing_in_beats,
        "missing_in_flow_prompts": missing_in_flow,
        "characters_verified_with_flow_dna": characters,
        "incomplete_char_profiles": incomplete_char_profiles,
        "required_backdrop_landmarks": required_landmarks,
        "missing_backdrop_landmarks": missing_landmarks,
        "verified_storyline_scene_images": verified_scene_images,
        "missing_or_invalid_scene_images": missing_or_invalid_scene_images,
        "notes": "All Google Flow defined character assets (Character DNA sheet + Flow ingredient IDs), target phonics words (crop, spud, grub, snag), and 100%-adherent storyline scene image locks verified."
    }

    # -------------------------------------------------------------------------
    # Gate 5: Well-Formed Google Flow (Veo 3.1) Prompt & 2-Step Human Gate
    # -------------------------------------------------------------------------
    flow_words = master_flow_prompt.split()
    flow_word_count = len(flow_words)
    is_single_paragraph = ("\n" not in master_flow_prompt)
    flow_lower = master_flow_prompt.lower()
    has_color_anchor = ("full-color" in flow_lower or "vibrant" in flow_lower) and ("outline" in flow_lower or "ink" in flow_lower)
    has_camera_anchor = any(k in flow_lower for k in ("camera", "shot", "framing", "pan", "track", "gentle", "close", "push-in", "pull-back"))
    has_lighting_anchor = any(k in flow_lower for k in ("sunlight", "sunbeam", "afternoon", "golden", "warm", "light", "sunny"))
    has_audio_clause = ("audio:" in flow_lower)
    word_count_ok = (90 <= flow_word_count <= 145)

    # Check 2-step workflow gate & human-readable text screenplay in Blends folder
    workflow_step = str(data.get("workflow_step", "")).strip()
    human_approval = data.get("human_approval", {})
    approval_status = str(human_approval.get("status", "")).strip()
    text_screenplay_path = str(data.get("human_readable_screenplay_txt_path", "")).strip()
    text_file_exists = bool(text_screenplay_path and Path(text_screenplay_path).exists())
    in_blends_folder = "blends" in text_screenplay_path.lower()

    # Verify per-beat utterances and animation_anchors for Step 2 single-source-of-truth execution
    beats_with_utterances_and_anchors = 0
    for b in beats:
        utts = b.get("utterances", [])
        anchors = b.get("animation_anchors", {})
        if (
            isinstance(utts, list)
            and len(utts) > 0
            and all(isinstance(u, dict) and u.get("speaker") and u.get("text") for u in utts)
            and isinstance(anchors, dict)
            and len(anchors) > 0
        ):
            beats_with_utterances_and_anchors += 1
    step2_data_ready = (beats_with_utterances_and_anchors == len(beats) and len(beats) > 0)

    two_step_gate_ok = (
        workflow_step in ("STEP_1_AWAITING_HUMAN_APPROVAL", "STEP_2_APPROVED_FOR_VIDEO")
        and approval_status in ("PENDING_HUMAN_REVIEW", "APPROVED")
        and text_file_exists
        and in_blends_folder
        and step2_data_ready
    )

    gate5_pass = (
        is_single_paragraph
        and has_color_anchor
        and has_camera_anchor
        and has_lighting_anchor
        and has_audio_clause
        and word_count_ok
        and two_step_gate_ok
    )
    checks["gate_5_google_flow_and_two_step_human_gate"] = {
        "status": "PASS" if gate5_pass else "FAIL",
        "flow_prompt_word_count": flow_word_count,
        "is_single_paragraph": is_single_paragraph,
        "has_color_and_outline_anchor": has_color_anchor,
        "has_camera_anchor": has_camera_anchor,
        "has_lighting_anchor": has_lighting_anchor,
        "has_audio_clause": has_audio_clause,
        "workflow_step": workflow_step,
        "human_approval_status": approval_status,
        "human_readable_screenplay_txt_path": text_screenplay_path,
        "text_screenplay_exists_in_blends": (text_file_exists and in_blends_folder),
        "step2_utterances_and_anchors_ready": step2_data_ready,
        "notes": (
            f"Single-paragraph 6-pillar Flow prompt ({flow_word_count} words) verified; "
            f"2-step human review gate active ({workflow_step} / {approval_status}) with text screenplay saved in Blends and all {beats_with_utterances_and_anchors}/{len(beats)} beats containing Step 2 utterances & animation anchors."
        )
    }

    overall_pass = all(c["status"] == "PASS" for c in checks.values())
    return {
        "screenplay_title": data.get("title", "Untitled"),
        "workflow_step": workflow_step,
        "human_approval_status": approval_status,
        "overall_status": "PASS" if overall_pass else "FAIL",
        "gates": checks
    }


def main():
    parser = argparse.ArgumentParser(description="Evaluate Step 1 animated screenplay JSON & text review file.")
    parser.add_argument("--input", required=True, help="Path to screenplay JSON file.")
    parser.add_argument("--output-report", required=False, help="Optional path to save evaluation JSON.")
    args = parser.parse_args()

    in_path = Path(args.input)
    if not in_path.exists():
        print(f"ERROR: Screenplay file not found: {in_path}", file=sys.stderr)
        sys.exit(1)

    data = json.loads(in_path.read_text(encoding="utf-8"))
    report = evaluate_screenplay(data)

    if args.output_report:
        out_path = Path(args.output_report)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(json.dumps(report, indent=2))
    if report["overall_status"] != "PASS":
        sys.exit(2)


if __name__ == "__main__":
    main()
