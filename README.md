# EduGuard: Smart Attendance System

EduGuard is a collaborative academic group project that aims to improve attendance management in educational institutions. Built with Flutter and Dart, the application integrates Firebase services and mobile device capabilities to support attendance tracking, user authentication, and session management.

## Features

- **Role-Based Access:** Separate access for students, lecturers, and administrators.
- **Authentication:** User registration, login, and email verification.
- **QR-Code Attendance:** Scan QR codes to record attendance for lecture sessions.
- **Biometric Verification:** Supports biometric authentication before attendance scanning.
- **Location Validation:** Uses GPS-based distance checks to help verify attendance location.
- **Attendance Tracking:** Records attendance statuses and helps monitor attendance percentages.
- **Session Management:** Supports lecturer-led attendance sessions.
- **Reports:** Supports attendance report generation and sharing.
- **Push Notifications:** Uses Firebase Cloud Messaging.
- **Theme Options:** Supports light and dark modes.

## Technology Stack

- **Programming Language:** Dart
- **Framework:** Flutter
- **Backend Services:** Firebase Authentication, Cloud Firestore
- **Notifications:** Firebase Cloud Messaging
- **Location Services:** Geolocator
- **Biometrics:** Local Auth
- **Time Synchronisation:** NTP
- **Reporting:** CSV and Share Plus

## System Overview

EduGuard is designed to help educational institutions manage attendance digitally. Its features aim to reduce proxy attendance, prevent duplicate records, and improve the reliability of attendance tracking through QR-code validation, location checks, and session controls.

## Project Structure

- `lib/` — Dart application source code, screens, services, utilities, and widgets.
- `android/` — Android platform configuration and application files.
- `ios/` — iOS platform files, if included.
- `test/` — Automated tests, if included.
- `pubspec.yaml` — Flutter project dependencies and configuration.

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Android Studio or another supported development environment
- Firebase project configuration

### Installation

1. Clone this repository:

   ```bash
   git clone YOUR_REPOSITORY_URL
   ```

2. Navigate to the project directory:

   ```bash
   cd smart_attendance
   ```

3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. Configure Firebase using the project's authorised setup instructions.

5. Run the application:

   ```bash
   flutter run
   ```

Note: The repository URL, project directory, and Firebase setup instructions should be adjusted to match the published repository.

## Academic Group Project

EduGuard was developed collaboratively as an academic group project. It demonstrates the application of mobile development, cloud-based services, database management, and digital attendance verification.

## Future Improvements

- Expand automated testing and security validation.
- Improve attendance analytics and reporting.
- Refine the user experience based on feedback.
- Strengthen backend access controls and validation.

## Acknowledgements

Developed collaboratively as part of an academic project.
