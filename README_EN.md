# FocusLive (FocusScreen) 📱✨

[中文说明文档](./README.md) | [English Documentation](./README_EN.md)

[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-blue.svg?style=for-the-badge&logo=apple)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-blueviolet.svg?style=for-the-badge&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-red.svg?style=for-the-badge&logo=apple)](https://developer.apple.com/documentation/swiftdata)
[![ActivityKit](https://img.shields.io/badge/ActivityKit-Live--Activities-brightgreen.svg?style=for-the-badge&logo=apple)](https://developer.apple.com/documentation/activitykit)

> **FocusLive** is an iOS application built around **Live Activities** and **Dynamic Island**. Task groups automatically sync to the lock screen and Dynamic Island. Users can check off completed items directly on the lock screen card, syncing the changes back to the main app database in real-time.

---

> [!IMPORTANT]
> This repository maintains a complete **Architecture Specification**, **Core Feature Overview**, **Audit Bug-Fix Log**, and **Milestone Roadmap** as the single source of truth.

---

## 1. Core Features 🚀

- 📌 **Lock Screen Live Activities & Dynamic Island**: Task groups automatically create lock screen cards; Dynamic Island supports Compact and Expanded views. Directly tap to complete tasks on lock screen with instant database persistence.
- 🤖 **AI Executive Focus Summary (Humanizer Engine)**:
  - Dedicated **AI Summary Tab** calling OpenRouter API (`inclusionai/ling-2.6-flash`).
  - **All-Task Type Gathering**: Collects all active incomplete tasks across all groups (Todos, Daily Check-Ins, Reminders).
  - **Humanized Natural Language Prompt**: Replaces rigid corporate buzzwords with a warm, natural, conversational summary like a personal manager previewing your day.
  - **Task Fingerprint Protection**: Computes hash fingerprints to ensure API calls are ONLY made upon task creation, deletion, edit, or completion. Reuses local persistence cache on view switches to prevent redundant API costs.
  - **Pro Feature & 1 Free Trial per Device**: Provides 1 free trial for every device, with seamless paywall sheet presentation upon consumption.
- 🎨 **Lock Screen Customization & Adaptive Layout**:
  - Transparent / Opaque background modes, custom photo wallpaper import (`PhotosPicker`) with high-fidelity lock screen preview.
  - **140% Dynamic AI Card Font Scaling**: Maximum font size scaled up to 140% (18pt), dynamically stepping down (18pt~12pt) and adjusting vertical padding (12pt~16pt) based on text length to prevent any text clipping.
  - 11 font text colors with adaptive high-contrast rendering.
- 🧪 **Lab UI Visual Styles (11 Distinct Aesthetics)**:
  - `Ambient Glass` (Default refraction glassmorphism)
  - `Neo Brutal` (High contrast thick borders & offset shadows)
  - `Editorial` (Magazine serif typography & accent rules)
  - `Terminal` (Matrix green hacker terminal monospaced aesthetic)
  - `Aurora` (Multi-stop iridescent neon gradients)
  - `Glassmorphism` / `Flat Receipt` / `Skeuomorphism` / `Material You` / `Minimal` / `Bold Stats`
- 📅 **Task Types & Repeat Engine**: Supports `Todo`, `Daily Check-In`, and `Reminders`. Automatically calculates next dates for daily, weekly, monthly, and yearly recurring tasks.
- 🔒 **Face ID Privacy Space**: Encrypts private groups and tasks, automatically masking sensitive items in lock screen and main UI.
- 🔔 **Smart Reminders & Notifications**: Countdowns rendered dynamically by the system (`Text(timerInterval:)`).
- 🛍️ **StoreKit 2 Subscriptions**:
  - **Monthly Pro**: `com.qingteng.FocusLive.pro.monthly`
  - **Yearly Pro**: `com.qingteng.FocusLive.pro.yearly`
- ⚡ **Shortcuts & Siri Intents**: Built-in App Intents for creating groups and adding tasks via Siri.

---

## 2. Architecture & Project File Hierarchy 🛠️

```
+-------------------------------------------------------------------+
|                            App Group                              |
|                    group.com.QingTeng.FocusLive                   |
|                        (FocusLive.store)                          |
+---------------------------------+---------------------------------+
                                  |
            +---------------------+---------------------+
            |                                           |
            v                                           v
+-----------------------+                   +-----------------------+
|        Main App       |                   |   Widget Extension    |
| ([FocusLiveApp.swift](file:///Users/qingteng/Downloads/%E9%A1%B9%E7%9B%AE%E4%BB%A3%E7%A0%81_Projects/%E6%88%91%E7%9A%84%E5%88%B6%E4%BD%9C/FocusLive/FocusLive/FocusLive/FocusLiveApp.swift))  |                   |  ([FocusWidgetBundle.swift](file:///Users/qingteng/Downloads/%E9%A1%B9%E7%9B%AE%E4%BB%A3%E7%A0%81_Projects/%E6%88%91%E7%9A%84%E5%88%B6%E4%BD%9C/FocusLive/FocusLive/FocusWidget/FocusWidgetBundle.swift))  |
+-----------------------+                   +-----------------------+
|  SwiftUI Views        |                   |  LockScreen Widget    |
|  ActivityManager      |                   |  Dynamic Island       |
|  AISummaryService     |                   |  HomeScreen Widget    |
+-----------------------+                   +-----------------------+
            ^                                           |
            |           Lock Screen Intent Trigger      |
            +-------------------------------------------+
                     ToggleTaskIntent (@MainActor)
```

| Layer | File | Responsibilities |
| :--- | :--- | :--- |
| **Data Models** | [TaskModel.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/TaskModel.swift) | `TaskGroup` / `TaskItem` (SwiftData `@Model`), `TaskGroupSnapshot` IPC snapshot |
| **Data Migration** | [DataMigration.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/DataMigration.swift) | SwiftData `VersionedSchema` + `MigrationPlan` schema migrations |
| **AI Engine** | [AISummaryService.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/AISummaryService.swift) | OpenRouter API integration, `.env` key loader, JSON schema enforcer |
| **Live Activities** | [ActivityManager.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/ActivityManager.swift) | Activity creation, hash diff updates, AI Summary & smart reminders |
| **Lock Screen Intent** | [ToggleTaskIntent.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/ToggleTaskIntent.swift) | `LiveActivityIntent`, direct store persistence on `@MainActor` |
| **Shortcuts Intents** | [ShortcutsIntents.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/ShortcutsIntents.swift) | Siri & iOS Shortcuts AppIntents integration |
| **Widgets** | [FocusActivityWidget.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusWidget/FocusActivityWidget.swift) | Lock screen & Dynamic Island UI; [FocusTaskWidget.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusWidget/FocusTaskWidget.swift) Home widgets |
| **Main Views** | [ContentView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/ContentView.swift) | Task list, filtering, group cards ([TaskGroupCard.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/TaskGroupCard.swift)), task rows ([TaskRow.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/TaskRow.swift)) |
| **AI Tab View** | [AISummaryView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/AISummaryView.swift) | AI Summary tab page with real-time refresh and task breakdown |
| **Lab UI** | [LabView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/LabView.swift) | Experimental design system selector with 11 aesthetics |
| **Settings & StoreKit** | [LiveActivitySettingsView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/LiveActivitySettingsView.swift) | Settings view with photo wallpaper preview; [SubscriptionView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/SubscriptionView.swift) In-App Purchases |
| **Design System** | [Theme.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/Theme.swift) / [AppSupport.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/AppSupport.swift) | Global Design Tokens, Logger, repeat task engine |

---

## 3. Environment & Build Setup 🛠️

- **iOS Target**: iOS 17.0+
- **Xcode**: Xcode 15.0+
- **App Group Identifier**: `group.com.QingTeng.FocusLive`
- **URL Scheme**: `focuslive://` (`toggle` / `sync` / `end`)

### Build Verification Command

```bash
xcodebuild -scheme FocusLive -project FocusLive.xcodeproj -derivedDataPath ./build -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build
```

---

## 4. Documentation Index 📂

- 📘 [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md): ActivityKit & IPC Architecture Guide
- ⚡ [QUICKSTART.md](./QUICKSTART.md): Quickstart & Testing Instructions
- ✅ [SETUP_CHECKLIST.md](./SETUP_CHECKLIST.md): Provisioning & Target Checklist
- 📋 [CHANGELOG.md](./CHANGELOG.md): Version History
