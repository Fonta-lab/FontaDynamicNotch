# Fonta's Dynamic Notch — working rules for Claude Code

The full product and technical spec is in `SPEC.md`. Read it fully at the start of every session before doing anything.

## The user
- The user does not write code and does not want to learn Swift. Explain progress and test steps in plain language, without jargon.
- After each milestone, give a short numbered checklist of what to try ("hover the notch, it should open after a short pause…") and ask for screenshots if something looks wrong.
- Ask before changing any decision written in SPEC.md. If something in the spec turns out to be impossible, explain why and propose an alternative.

## How to work
- Follow the milestones in SPEC.md §15 in order. Finish and get the user's OK on one milestone before starting the next.
- M0 is mandatory: report which risky features work on the user's macOS (27.2.1) before building on them.
- The project is generated with XcodeGen (`project.yml`). Never edit the `.xcodeproj` by hand; regenerate it.
- Build with `xcodebuild` after every meaningful change. Fix all errors and warnings before reporting.
- Commit to git after each completed step with a clear message.
- Keep files small and organized by feature (`Notch/`, `Services/`, `Features/Timers/`, `Settings/` …).

## Technical non-negotiables
- Never block the main thread (AppleScript, file I/O and image decoding go off-main).
- No polling loops while the notch is closed and idle (SPEC §12).
- Never launch Spotify by accident: check that it is running before scripting it.
- Private APIs (brightness, keyboard backlight) stay isolated behind protocols with an availability check; if unavailable, remove the UI.
- Sign with the user's Personal Team certificate, not ad-hoc, so macOS permissions persist between builds.
- Settings and state JSON must decode with defaults for missing keys.
