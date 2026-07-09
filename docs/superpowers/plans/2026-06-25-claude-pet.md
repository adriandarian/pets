# Claude Pet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS overlay pet that shows live Claude Code sessions across terminal and VS Code entrypoints.

**Architecture:** The app is a Swift Package with a testable `ClaudePetCore` scanner and a thin AppKit/SwiftUI overlay executable. The scanner reads `~/.claude/sessions/*.json`, filters dead PIDs, normalizes Claude statuses, and exposes sorted session models to the overlay.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit, SwiftUI, Swift Testing.

---

### Task 1: Session Scanner Core

**Files:**
- Create: `Sources/ClaudePetCore/ClaudeSession.swift`
- Create: `Sources/ClaudePetCore/ClaudeSessionScanner.swift`
- Test: `Tests/ClaudePetCoreTests/ClaudeSessionScannerTests.swift`

- [ ] Write failing tests for live PID filtering, newest-first sorting, title selection, and missing-status inference.
- [ ] Run `swift test --filter ClaudeSessionScannerTests` and verify the tests fail because scanner types do not exist.
- [ ] Implement `ClaudeSession`, `ClaudeDisplayStatus`, `ProcessInspecting`, `DarwinProcessInspector`, and `ClaudeSessionScanner`.
- [ ] Run `swift test --filter ClaudeSessionScannerTests` and verify the tests pass.

### Task 2: Overlay App

**Files:**
- Create: `Sources/ClaudePet/ClaudePetApp.swift`
- Create: `Sources/ClaudePet/ClaudePetStore.swift`
- Create: `Sources/ClaudePet/PetOverlayView.swift`

- [ ] Create an accessory macOS app that opens a transparent floating panel across Spaces.
- [ ] Poll `ClaudeSessionScanner` every two seconds on the main actor.
- [ ] Draw a compact Claude-themed pet and a session bubble listing live sessions and statuses.
- [ ] Run `swift build` and `swift run ClaudePet` to manually verify the overlay launches.

### Task 3: Scripts and Docs

**Files:**
- Create: `scripts/check.sh`
- Create: `scripts/run_app.sh`
- Create: `README.md`

- [ ] Add scripts matching the style of `/Users/dariana/personal/GHMenuBar`.
- [ ] Document how to build, run, and what data the app reads.
- [ ] Run `scripts/check.sh` and verify it passes.
