# BFPAS – Broiler Feed-Pecking Analysis System
This is a app that is used alongside the Raspberry Pi system that infers behavioral anomalies in chicken feed-pecking. This study hopes to find correlation between feeding behavior through feed-pecking and early health monitoring. 

The app is developed in flutter, as per the researchers' working knowledge on app development is with this framework. 

# Quick Start

## Prerequisites
- Flutter SDK (stable channel) — https://flutter.dev/docs/get-started/install
- Java 17 (install via SDKMAN: `sdk install java 17.0.10-tem` or in `Oracle website`)
- Android Studio or VS Code with Flutter extension
- Android device with USB debugging ON, or an emulator

### 1. Clone this repository
Use either of the options below:

    HTTP: https://github.com/UchiteL0515/Broiler-Feed-Pecking-Analysis-System---BFPAS.git
    SSH : git@github.com:UchiteL0515/Broiler-Feed-Pecking-Analysis-System---BFPAS.git


### 2. Install dependencies
    
    flutter pub get

### 3. Run on connected Android device or emulator

    flutter run

# Seed Demo
The app has demo data set up for SQLite database. These demo chicken records are used for testing the app functionality. 

### Steps to seed demo data
First, make sure that main.dart has this import:
```
import 'database/database_seeder.dart'
```
The file should already be inside the repo when cloned

Then insert this block inside main() just before runApp():
```
if(kDebugMode) await DatabaseSeeder.seed();
```

Demo data should start to seed inside database, wait until finished then the data should be updated on the homescreen.

# Project Structure
```
lib/
├── main.dart                        # App entry point + theme
├── screens/
│   └── home_screen.dart             # Main homepage (status + chicken grid)
├── services/
│   └── connection_service.dart      # Pi connection state (Wi-Fi)
└── widgets/
    └── connection_status_badge.dart # Reusable connected/disconnected badge
```

# Current Skeleton Features
- ✅ App "connected" status always shown
- ✅ Raspberry Pi 4 connection status (disconnected / connecting / connected)
- ✅ "Connect to Pi" button with simulated 2-second Wi-Fi handshake
- ✅ Stat cards: Total / Normal / Anomaly placeholders
- ✅ Filter chips: View All / Normal / Anomaly
- ✅ Empty state changes based on Pi connection

# Next Steps
- [ ] Wi-Fi socket / HTTP polling from Pi after successful handshake
- [ ] SQLite schema + `sqflite` setup
- [ ] Chicken card grid with ID + Normal/Anomaly badge
- [ ] Chicken detail view with live feed + behavioral data