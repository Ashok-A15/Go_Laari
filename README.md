# Go Laari Projects

Welcome to the Go Laari workspace! This directory contains the source code for the Go Laari logistics platform. The platform is divided into two separate Flutter applications to cater to our different user bases:

## 📱 Applications

### 1. Golorry Customer App (`golorry_customer_app-master`)
The customer-facing application used to book lorries for logistics and goods transportation. 
- **Features:**
  - Dedicated lorry vehicle selection.
  - Smooth booking flow and step-by-step navigation.
  - Real-time driver location tracking.
  - Map route polylines and marker rendering.
  - Post-trip completion and feedback rating.

### 2. Golorry Owner/Driver App (`golorry_owner_driver_app_master`)
The application designed for vehicle owners and drivers to manage delivery requests and perform their logistics jobs.
- **Features:**
  - Receive and accept customer booking requests.
  - Broadcast live location for customer tracking.
  - In-app navigation and trip lifecycle management.

## 🛠 Prerequisites

Make sure you have the following installed on your machine to run these projects:
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter plugins.
- Xcode (for iOS development, requires macOS).

## 🚀 Getting Started

Since these are two separate Flutter projects, you need to run them individually. 

1. **Open a terminal** and navigate into the app you want to run:
   ```bash
   # For the Customer App
   cd golorry_customer_app-master

   # OR for the Driver App
   cd golorry_owner_driver_app_master
   ```

2. **Fetch all dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application** on an attached device or emulator:
   ```bash
   flutter run
   ```

## 🔄 Version Control
Both projects are maintained as independent repositories. Please ensure you are committing and pushing from inside their respective folders.
