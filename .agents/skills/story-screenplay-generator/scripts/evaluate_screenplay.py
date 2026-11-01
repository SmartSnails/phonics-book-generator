#!/usr/bin/env python3
"""
Deterministic 5-Gate Evaluator & Linter for ~10-Second Animated Story Screenplays
and Google Flow (Veo 3.1) Animation Prompts.
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

UNSAFE_THEMES = [
    r"\b(?:blood|bleed|bleeding|scary|terrified|scream|hurt|pain|weapon|monster|attack|cry|crying|dead|kill|sharp\s+thorn|thorns?\s+hook|scratch|prick)\b"
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
    flow_prompt = data.get("google_flow_prompt", "").strip()

    # Corpus of actual creative content (excluding metadata arrays like target_phonics_words)
    beats_text = " ".join(
        f"{b.get('character_motion', '')} {b.get('facial_expression', '')} "
        f"{b.get('backdrop_motion', '')} {b.get('narration_or_dialogue', '')} "
        f"{b.get('sfx_and_music', '')} {b.get('audio_sfx', '')}"
        for b in beats
    )
    creative_corpus = f"{data.get('title', '')} {beats_text} {flow_prompt}".lower()

    # -------------------------------------------------------------------------
    # Gate 1: Child Safety & Flow Policy Hygiene
    # -------------------------------------------------------------------------
    unsafe_hits = []
    for pat in UNSAFE_THEMES:
        unsafe_hits.extend(re.findall(pat, creative_corpus, flags=re.IGNORECASE))

    banned_flow_hits = []
    for pat in BANNED_FLOW_TOKENS:
        banned_flow_hits.extend(re.findall(pat, flow_prompt, flags=re.IGNORECASE))

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
    # Gate 2: Child Friendliness & Pacing (Contiguous Beats & Spoken Word Budget)
    # -------------------------------------------------------------------------
    duration = float(data.get("target_duration_sec", 0))
    beat_duration_sum = 0.0
    timeline_contiguous = len(beats) >= 3
    expected_start = 0.0
    narration_words = []

    for b in beats:
        s_sec = float(b.get("start_sec", -1))
        e_sec = float(b.get("end_sec", -1))
        b_dur = e_sec - s_sec
        if b_dur < 1.5 or b_dur > 6.0 or abs(s_sec - expected_start) > 0.05:
            timeline_contiguous = False
        expected_start = e_sec
        beat_duration_sum += max(0.0, b_dur)

        vo = b.get("narration_or_dialogue", "").strip()
        if vo:
            narration_words.extend(vo.split())

    if abs(expected_start - duration) > 0.1:
        timeline_contiguous = False

    total_vo_words = len(narration_words)
    words_per_sec = round(total_vo_words / max(duration, 1.0), 2)
    duration_ok = (8.0 <= duration <= 12.0) and (abs(beat_duration_sum - duration) < 0.15)
    pacing_ok = (4 <= total_vo_words <= 24) and (words_per_sec <= 2.4)

    gate2_pass = duration_ok and timeline_contiguous and pacing_ok and len(beats) >= 3
    checks["gate_2_child_friendly_and_pacing"] = {
        "status": "PASS" if gate2_pass else "FAIL",
        "target_duration_sec": duration,
        "beat_count": len(beats),
        "timeline_contiguous": timeline_contiguous,
        "total_spoken_words": total_vo_words,
        "words_per_second": words_per_sec,
        "notes": f"{len(beats)} contiguous timed beats across {duration}s with {total_vo_words} spoken words ({words_per_sec} wps <= 2.4 wps)."
    }

    # -------------------------------------------------------------------------
    # Gate 3: Entertainment & Anti-Slideshow Vitality (Per-Beat + Flow Prompt)
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

    flow_tokens = set(re.findall(r"[a-z]+", flow_prompt.lower()))
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
            f"All {len(beats)} beats have active character/facial/backdrop motion; "
            f"{len(matched_verbs)} beat verbs, {len(flow_verbs)} Flow prompt verbs, "
            f"and {len(matched_backdrop)} backdrop motion cues."
        )
    }

    # -------------------------------------------------------------------------
    # Gate 4: Theme, Phonics, Character Traits & Backdrop Landmarks Fidelity
    # -------------------------------------------------------------------------
    target_words = [w.lower() for w in data.get("target_phonics_words", []) if w.strip()]
    narration_corpus = " ".join(b.get("narration_or_dialogue", "") for b in beats).lower()

    missing_in_beats = [w for w in target_words if w not in beats_text.lower()]
    missing_in_flow = [w for w in target_words if w not in flow_prompt.lower()]
    spoken_target_words = [w for w in target_words if w in narration_corpus]

    char_objs = data.get("characters", [])
    characters = [c.get("name", "") for c in char_objs if c.get("name")]
    missing_chars_in_beats = [c for c in characters if c.lower() not in action_corpus]
    missing_chars_in_flow = [c for c in characters if c.lower() not in flow_prompt.lower()]
    incomplete_char_profiles = [
        c.get("name", "Unknown")
        for c in char_objs
        if not _as_str(c.get("visual_anchor") or c.get("flow_descriptor")).strip()
        or not _as_str(c.get("personality_traits")).strip()
        or not _as_str(c.get("trait_to_action_mapping")).strip()
    ]

    backdrop_obj = data.get("backdrop", {})
    required_landmarks = [
        lm.lower() for lm in backdrop_obj.get("required_landmarks", []) if lm.strip()
    ]
    missing_landmarks = [
        lm for lm in required_landmarks
        if lm not in action_corpus and lm not in flow_prompt.lower()
    ]

    gate4_pass = (
        len(target_words) > 0
        and len(missing_in_beats) == 0
        and len(missing_in_flow) == 0
        and len(spoken_target_words) >= 1
        and len(characters) >= 1
        and len(missing_chars_in_beats) == 0
        and len(missing_chars_in_flow) == 0
        and len(incomplete_char_profiles) == 0
        and len(missing_landmarks) >= 0
        and len(required_landmarks) >= 2
        and len(missing_landmarks) == 0
    )
    checks["gate_4_theme_and_phonics_fidelity"] = {
        "status": "PASS" if gate4_pass else "FAIL",
        "target_phonics_words": target_words,
        "spoken_target_words": spoken_target_words,
        "missing_in_beats": missing_in_beats,
        "missing_in_flow_prompt": missing_in_flow,
        "characters_verified": characters,
        "missing_chars_in_beats": missing_chars_in_beats,
        "missing_chars_in_flow": missing_chars_in_flow,
        "incomplete_char_profiles": incomplete_char_profiles,
        "required_backdrop_landmarks": required_landmarks,
        "missing_backdrop_landmarks": missing_landmarks,
        "notes": "All target phonics words, character traits/anchors, and backdrop landmarks verified in beats and Flow prompt."
    }

    # -------------------------------------------------------------------------
    # Gate 5: Well-Formed Google Flow (Veo 3.1) Prompt Structure (6 Pillars)
    # -------------------------------------------------------------------------
    flow_words = flow_prompt.split()
    flow_word_count = len(flow_words)
    is_single_paragraph = ("\n" not in flow_prompt)
    flow_lower = flow_prompt.lower()
    has_color_anchor = ("full-color" in flow_lower or "vibrant" in flow_lower) and ("outline" in flow_lower or "ink" in flow_lower)
    has_camera_anchor = any(k in flow_lower for k in ("camera", "shot", "framing", "pan", "track", "gentle", "close", "push-in", "pull-back"))
    has_lighting_anchor = any(k in flow_lower for k in ("sunlight", "sunbeam", "afternoon", "golden", "warm", "light", "sunny"))
    has_audio_clause = ("audio:" in flow_lower)
    word_count_ok = (90 <= flow_word_count <= 145)

    gate5_pass = (
        is_single_paragraph
        and has_color_anchor
        and has_camera_anchor
        and has_lighting_anchor
        and has_audio_clause
        and word_count_ok
    )
    checks["gate_5_google_flow_well_formed"] = {
        "status": "PASS" if gate5_pass else "FAIL",
        "flow_prompt_word_count": flow_word_count,
        "is_single_paragraph": is_single_paragraph,
        "has_color_and_outline_anchor": has_color_anchor,
        "has_camera_anchor": has_camera_anchor,
        "has_lighting_anchor": has_lighting_anchor,
        "has_audio_clause": has_audio_clause,
        "notes": f"Single-paragraph 6-pillar Flow prompt ({flow_word_count} words, required 90-145) with style/outline, camera, lighting, and Audio clause."
    }

    overall_pass = all(c["status"] == "PASS" for c in checks.values())
    return {
        "screenplay_title": data.get("title", "Untitled"),
        "overall_status": "PASS" if overall_pass else "FAIL",
        "gates": checks
    }


def main():
    parser = argparse.ArgumentParser(description="Evaluate 10s animated screenplay JSON.")
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
