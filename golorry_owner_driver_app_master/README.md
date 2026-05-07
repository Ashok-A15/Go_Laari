# Golorry Owner & Driver App

This is the owner and driver-facing Flutter application for the **Go Laari** logistics platform. It provides vehicle owners and drivers with the tools they need to receive bookings, manage logistics jobs, and navigate to customer locations.

## 🚀 Features

- **Job Management**: Receive, review, and accept incoming logistics and transport booking requests from customers.
- **Live Location Broadcasting**: Broadcast real-time location data allowing customers to track the incoming lorry.
- **Navigation Assistance**: In-app routing capabilities to help drivers reach pick-up and drop-off destinations.
- **Trip Lifecycle**: Update trip statuses (e.g., Arrived, On the way, Job Completed) to keep customers informed.
- **Earnings & History**: Track completed jobs and logistics history.

## 🛠 Prerequisites

- Flutter SDK (latest stable version recommended)
- Android Studio / Visual Studio Code (with Flutter extensions)
- Setup for an Android Emulator or physical device (physical device recommended for location-based testing).

## 💻 Getting Started

To run this application locally, follow these steps:

1. **Clone the repository** (if not already done) and navigate to the project directory:
   ```bash
   cd golorry_owner_driver_app_master
   ```

2. **Get packages**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

## 🏗 Architecture & Technologies

- **Framework**: Flutter
- **Language**: Dart
- **Location Services**: Extensive use of geolocation permissions to track and broadcast the driver's location.
- **Backend/Database**: Integrates with backend services (e.g., Firebase) to receive bookings and upload real-time location points.

## 🤝 Contribution

Make sure you are committing changes locally to this specific repository folder (`golorry_owner_driver_app_master`) and pushing to the relevant owner/driver app remote on GitHub.
