<div align="center">

# LNAT Forge

**A native iOS companion for LNAT Section A & Section B preparation — built with SwiftUI & SwiftData.**  
Free, open-source, offline-first, and ad-free forever.

![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-1E3A8A?style=flat-square&logo=apple&logoColor=white)
![Swift 5](https://img.shields.io/badge/Swift-5-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI & SwiftData](https://img.shields.io/badge/Framework-SwiftUI%20%2B%20SwiftData-0F172A?style=flat-square)
![Dependencies](https://img.shields.io/badge/Dependencies-0-047857?style=flat-square)
![Offline](https://img.shields.io/badge/Mode-100%25%20Offline-BE185D?style=flat-square)

</div>

---

## Overview

**LNAT Forge** is a focused, distraction-free iPhone app for preparing for the Law National Aptitude Test (LNAT). It brings together structured Section A reasoning lessons and drills, full-length 95-minute mock papers, distractor-trap and pacing diagnostics, an editorial passage reader, and 5-minute Section B essay outline sprints—with zero accounts, zero tracking, zero ads, and zero third-party dependencies.

---

## Content at a Glance

| Study Module | Scope | Details |
| :--- | :--- | :--- |
| **Section A Skills** | **6 core topics** | *Main Conclusion*, *Unstated Assumptions*, *Logical Flaws*, *Strengthen & Weaken*, *Strict Inference*, *Parallel Reasoning* |
| **Interactive Story Cards** | **30 cards** | 12 concept primers + 18 drills (2 lessons & 3 drills per skill) |
| **Full-Length Mock Papers** | **2 papers** | Official Test Version 1 & Version 2 — 12 passages · 42 questions · 95 mins each (23 unique passages) |
| **Quick Sessions** | **18-minute sprints** | 2 randomized unique passages for daily timed pacing practice |
| **Section B Essay Prompts** | **19 prompts** | *Law & Ethics*, *Politics & Society*, *Economics & Tech*, and *Culture & Rights* |

---

## Key Features

### 1. Learn — Section A Skill Decks
- **6-Skill Hub (`LearnTabView`):** Tracks lesson and drill completion across all six LNAT Section A reasoning categories.
- **4-Slide Story Cards (`StoryCardView`):** Each primer or drill walks step-by-step through **Concept / Argument Hook → Key Clue Spotlight → Worked Example or Drill → Logic & Distractor Trap Breakdown**, with horizontal card-slide swipes and instant feedback.

### 2. Review — Practice Papers & Editorial Passage Reader
- **Timed Exam Runner (`MockExamRunnerView`):** Supports full 95-minute papers and 18-minute Quick Sessions with:
  - **Split**, **Passage**, and **Question** layout modes.
  - Live `A-` / `A+` serif typography scaling (`14pt`–`18.5pt`).
  - Question flagging, countdown warnings, and an interactive `QuestionGridSheet` (*All*, *Remaining*, *Flagged*).
- **Detailed Post-Exam Diagnostics (`MockReviewView` / `PastAttemptReviewView`):** Summarizes score, accuracy, average time per question, a ranked **Common Mistakes** trap breakdown, and expandable option-by-option explanations.
- **Read-Only Passage Reader (`PassageReaderView`):** Tap any passage under `ALL PASSAGES` for a clean, distraction-free editorial reading view (`17pt` serif typography with generous line spacing and native horizontal-scrolling table rendering for structured passages such as *A Global Dilemma*).

### 3. Progress — Mastery, Trap Patterns & Backups
- **Diagnostics Engine (`DiagnosticsEngine`):** Computes topic mastery (`80%+` accuracy across at least 5 graded questions per skill), applies mild mock-miss decay, flags slow pacing (`> 135s` target), surfaces your most frequent distractor traps, and links directly into targeted practice.
- **Settings & Data Management (`SettingsSheetView`):** Includes appearance switching, lifetime study counters, portable JSON backup export/import, and study history reset.

### 4. Essays — Section B 5-Minute Outline Sprints
- **Structured Outline Composer (`EssaysTabView`):** Filter 19 essay prompts by category, shuffle or step through prompts, toggle collapsible **Essay Angle** tension hints, run a built-in `05:00` sprint timer, and draft structured 5-part outlines (*Thesis*, *First Argument*, *Second Argument*, *Counterargument*, *Conclusion*).
- **Saved Outlines History:** Review, edit, or delete previously saved essay plans directly on device.

### Native iOS Craft
- **Sakura Light & Pastel Dusk Themes:** Adaptive light and dark palettes (`LNATTheme`) with automatic system tracking or instant header toggling.
- **Instagram-Style Tab Paging:** Grab and swipe smoothly between **Learn**, **Review**, **Progress**, and **Essays** with a live-tracking floating capsule tab bar (`RootTabView`).
- **Native Edge-Swipe Navigation:** Left-edge swipe-to-go-back enabled across pushed sub-views via a lightweight `UIViewControllerRepresentable` bridge (`NavigationPopGestureSupport`).
- **Taptic Engine Haptics:** SwiftUI `.sensoryFeedback` integration across tab switches, filter pills, navigation transitions, theme toggles, and answer submissions.

---

## Architecture & Project Structure

LNAT Forge is built purely with Apple's native frameworks (**SwiftUI**, **SwiftData**, and thin **UIKit** bridges for window interface style, keyboard visibility, and interactive pop gestures), requiring zero external Swift packages or CocoaPods.

```text
LNATForge-iOS/
├── LNATForge.xcodeproj/              # Xcode project & shared scheme
├── Resources/
│   ├── Assets.xcassets/              # App icon & accent color
│   ├── Info.plist                    # Portrait iPhone app configuration
│   ├── storyDeck.json                # 30 Section A primer & drill cards
│   ├── mockTests.json                # Paper 1 & Paper 2 passages and questions
│   └── section-b-prompts.json        # 19 Section B prompts with key tensions
└── Sources/
    ├── App/
    │   ├── LNATForgeApp.swift        # App entry point & SwiftData model container
    │   ├── RootTabView.swift         # Header, interactive tab pager & floating tab bar
    │   ├── CreditPopupView.swift     # Centered dedication & credit modal overlay
    │   └── NavigationPopGestureSupport.swift
    ├── Models/
    │   ├── ContentStore.swift        # Bundled JSON loader & indexed content store
    │   ├── LNATContentModels.swift   # Codable content, telemetry & backup DTOs
    │   └── SwiftDataModels.swift     # QuestionAttempt, MockSessionRecord, SavedOutline, CompletedCardRecord
    ├── Services/
    │   ├── BackupService.swift       # JSON backup export, import & history reset
    │   ├── DiagnosticsEngine.swift   # Mastery, decay, pacing & trap analytics
    │   └── StudyPersistence.swift    # SwiftData persistence helpers
    ├── Theme/
    │   ├── LNATTheme.swift           # Sakura Light & Pastel Dusk palettes
    │   └── Haptics.swift             # UIKit haptic helpers
    └── Views/
        ├── Learn/                    # LearnTabView, FocusedDeckView, StoryCardView
        ├── Review/                   # ReviewTabView, PassageReaderView, MockExamRunnerView,
        │                             # MockReviewView, QuestionGridSheet, ExamBuilder, FormattedBlockView
        ├── Progress/                 # ProgressTabView, SettingsSheetView
        └── Essays/                   # EssaysTabView
```

---

## Getting Started

### Prerequisites
- macOS with **Xcode 15.4+** (or newer)
- **iOS 17.0+** Simulator or physical iPhone

### Run in Xcode
1. Clone the repository:
   ```bash
   git clone https://github.com/tomcsvan/LNATForge-iOS.git
   cd LNATForge-iOS
   ```
2. Open `LNATForge.xcodeproj` in Xcode.
3. Select an iPhone Simulator (or your connected iPhone) and press `⌘R` to build and run.

### Build from the Command Line
```bash
xcodebuild \
  -project LNATForge.xcodeproj \
  -scheme LNATForge \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  build
```

---

## Privacy, Data & Backups

- **100% On-Device Storage:** All answered questions (`QuestionAttempt`), completed mock papers (`MockSessionRecord`), essay plans (`SavedOutline`), and card progress (`CompletedCardRecord`) are stored locally using **SwiftData**. Nothing leaves your device.
- **Portable JSON Backups:** Export your complete study history to `lnat-forge-backup-YYYY-MM-DD.json` or restore an existing backup anytime from **Progress → Settings**.

---

## Contributing & Dedication

Contributions, bug reports, content corrections, and pull requests are warmly welcome! Feel free to open an issue or submit a PR to help make LNAT prep more accessible for students everywhere.

> “Crafted in a quiet West Coast town, fueled by good coffee and late nights, and sparked by lil Isla’s LNAT prep. Open-sourced for the world. Freely yours to study, remix, and conquer. Free, open, and ad-free forever”

<div align="center">

**© Tom Legacy**

</div>
