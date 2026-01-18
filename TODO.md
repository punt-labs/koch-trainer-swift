# Koch Trainer - TODO

## Completed Features

### ✅ Smart Practice Reminder System (Completed)

Implemented spaced repetition intervals and streak tracking with local notifications.

**What was built:**
- `PracticeSchedule` model with intervals, streaks, and level review dates
- `IntervalCalculator` service (doubles on ≥90%, maintains 70-89%, resets <70%)
- `StreakCalculator` service (consecutive calendar days)
- `NotificationManager` with anti-nag policy (max 2/day, 4-hour gap, quiet hours)
- `NotificationSettings` for user preferences
- HomeView streak card with personal best indicator
- HomeView "Due now" / "Next: relative time" indicators
- SettingsView notification toggles and streak display
- Migration support for existing users (calculates streak from history)
- 25 unit tests for calculators

---

## Future Features

### Streak Milestone Celebrations
- Add celebration UI on milestones (7, 30, 100 days)
- Consider confetti animation or badge system

---

## Improvements

### Deploy to Real Device
Steps to run the app on a physical iPhone/iPad:

1. **Apple Developer Account**
   - Free account: Can deploy to personal devices for 7 days (app expires, must re-deploy)
   - Paid account ($99/year): Deploy indefinitely, distribute via TestFlight/App Store

2. **Xcode Signing Configuration**
   - Open project in Xcode
   - Select KochTrainer target > Signing & Capabilities
   - Set Team to your Apple ID
   - Set Bundle Identifier to something unique (e.g., com.yourname.kochtrainer)
   - Enable "Automatically manage signing"

3. **Trust Developer on Device** (first time only)
   - On iPhone: Settings > General > VPN & Device Management
   - Tap your developer profile and tap "Trust"

4. **Build & Run**
   - Connect device via USB
   - Select device in Xcode's destination picker
   - Press Run (Cmd+R)

### Optional: TestFlight Distribution
For sharing with beta testers (requires paid developer account):
- Archive build (Product > Archive)
- Upload to App Store Connect
- Add testers via TestFlight

## Bugs

(empty)
