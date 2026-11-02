---
trigger: always_on
description: Enforce 100% hands-off, prefix-matchable command execution across all skills so Antigravity never re-prompts for terminal permissions.
---

# Hands-Off Command Execution Rule (`always_on`)

To guarantee that user permission grants ("Always Allow") generalize via binary + subcommand prefix-matching and never re-prompt during multi-step skill execution:

1. **Strict Ban on Shell Chaining & Expansions in `run_command`**:
   - **NEVER** combine multiple commands with `&&`, `;`, `||`, pipes `|`, or newlines `\n`.
   - **NEVER** use command substitution `$(...)`, backticks, shell variables `$VAR`, or brace expansion `{a,b}`.
   - **NEVER** run inline `python3 -c "..."` one-liners or wrapper binaries (`env`, `xargs`, `eval`, `timeout`).

2. **Use Only Pre-Built Skill Scripts with Literal Paths**:
   - Every terminal operation must invoke one of these 3 exact prefix-matchable command shapes:
     - `python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/<skill>/scripts/<script>.py ...`
     - `swift -module-cache-path /tmp/swift_cache /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/<skill>/scripts/<script>.swift ...`
     - `git -C /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator <subcommand> ...`

3. **Consolidate Multi-Step Pipelines Inside Python Orchestrators**:
   - In **Step 1 (`story-screenplay-generator`)**, use `python3 .../evaluate_screenplay.py --input <screenplay.json> --output <report.json>`.
   - In **Step 2 (`story-video-generator`)**, use the single master orchestrator `python3 .../generate_video_from_screenplay.py --screenplay <screenplay.json> --out-mp4 <primary.mp4> --copy-mp4 <secondary.mp4>`, which internally invokes neural voice synthesis, `AVFoundation` video rendering, and hardware bitrate optimization via Python `subprocess.run` without separate shell calls.

4. **Workspace File Storage Only**:
   - Always write generated audio, keyframes, screenplays, and videos inside `/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/` (never `/tmp` for cross-step assets) to avoid macOS cross-sandbox permission blocks (`NSCocoaErrorDomain Code=257`).
