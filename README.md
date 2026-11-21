# HomeTrack (macOS)

A minimal SwiftUI Mac app that tracks three everyday household things in one place:

1. **Petrol**: fill-ups, mileage (km/l), cost per km
2. **Family snacks**: biscuits and snacks per family member
3. **Water cans**: stock, days left, buy-early advice, one smart reminder

Plus: daily score with **pass marks**, streaks, daily rewards, reports with charts,
calculators, your own note pages, AI prompts, onboarding + help, dark mode,
time-in-app tracking, screenshot and screen recording, easy copy of any report.

## Install
```
git clone https://github.com/theikbhal/hometrack-mac.git
cd hometrack-mac && ./install.sh
```
Needs macOS 13+ and Xcode (or command line tools). The script builds the app,
copies it to /Applications and adds a Desktop shortcut.

## How the daily score works
| Item | Points |
|---|---|
| Water ready at home | 40 |
| Snacks logged (or "no snacks today") | 30 |
| Today's spend within daily budget | 30 |

Default pass mark is 60. Passing days build your streak.

## Data
Stored locally in `~/Library/Application Support/HomeTrack/`. Nothing is uploaded.
