# EduGuard: Smart Attendance System - Technical Documentation

## 1. Executive Summary
**EduGuard** is a high-security, cross-platform mobile solution designed to automate attendance tracking in educational institutions. It leverages Flutter for the front end and Firebase for the back end, utilizing biometrics, geofencing, and synchronized dynamic QR codes to eliminate common "proxy" attendance cheating methods.

## 2. System Architecture
The application follows a **Modular Clean Architecture**, separating services (Firebase, Time, Notifications) from UI components.

### Core Technology Stack
*   **Framework**: Flutter (Dart)
*   **Backend**: Firebase (Authentication, Cloud Firestore, Cloud Messaging)
*   **Location Services**: Geolocator API
*   **Security**: Local Auth (Biometrics), Device Info Plus (Device Binding)
*   **Reliability**: NTP (Network Time Protocol) synchronization via `ntp` package.

---

## 3. Core Functional Components

### 3.1 Advanced Authentication Suite
*   **Email Verification**: All users (Students and Lecturers) must verify their institutional email before accessing the dashboard.
*   **Device Binding**: During registration, the application captures the unique hardware ID (`androidId` on Android or `identifierForVendor` on iOS). The account is "locked" to this device in Firestore, preventing students from sharing login credentials to have friends sign them in.
*   **Biometric Gatekeeper**: Before the QR scanner opens, the system invokes `local_auth` to perform a fingerprint or face scan, ensuring the person holding the device is the registered student.

### 3.2 The "EduGuard" Security Protocol (Anti-Cheating)
The system uses a triple-validation check to mark attendance:

1.  **Synchronized Dynamic QR**: 
    *   QR codes consist of a `SessionID` appended with a `TimeBlock`.
    *   **TimeBlock**: The code changes every **60 seconds**.
    *   **Time Sync**: To prevent students from bypassing this by changing their phone's clock, the app uses a `TimeService` that fetches network time via NTP.
2.  **Geofencing**: 
    *   When a lecturer starts a session, their GPS coordinates are stored.
    *   During scanning, the student’s GPS is captured. The system calculates the distance.
    *   Access is denied if the student is >100 meters away from the classroom/lecturer.
3.  **Active Session Check**: 
    *   The scanner verifies the `isActive` flag in Firestore in real-time. Once a lecturer stops the session, no further scans are accepted even if the QR code is still visually valid.

### 3.3 Automatic Absence Marking
At the conclusion of a session, the system performs a **Firestore Batch Write**:
*   Identifies all students enrolled in the module.
*   Cross-references them with the "Present/Late" list.
*   Any student without a record is automatically marked as **"Absent"**, ensuring a complete and accurate daily register.

---

## 4. Data Model (Cloud Firestore)

### `users` Collection
*   `uid`: Unique ID (Firebase Auth).
*   `role`: Student, Lecturer, or Admin.
*   `deviceId`: Hardware ID for binding.
*   `enrolledModules`: Array of strings (modules the student is attending).
*   `modules`: Array of modules assigned to the lecturer.

### `sessions` Collection
*   `sessionId`: Unique identifier for the current lecture.
*   `courseName`: Name of the module.
*   `isActive`: Boolean (True while QR is active).
*   `latitude`/`longitude`: Coordinates of the lecturer.
*   `expiresAt`: Auto-expiry timestamp (e.g., 60 minutes).

### `attendance` Collection
*   `studentUid`: Reference to the student.
*   `status`: "Present", "Late", or "Absent".
*   `distanceFromLecturer`: Distance recorded during the scan.
*   `timestamp`: Server-side timestamp.

---

## 5. UI/UX Features
*   **Role-Based Dashboards**: Distinct interfaces for Admin, Lecturer, and Student.
*   **Real-time Analytics**: Students see an attendance "Health Bar" (Percentage) on their home screen calculated from their total sessions.
*   **Export Engine**: Reports are generated as **CSV files** using the `csv` package and shared via the native system sheet using `share_plus`.
*   **Push Notifications**: Integrated with **Firebase Cloud Messaging (FCM)**. Students receive an alert the moment a lecturer starts a session.
*   **Adaptive Theme**: Supports Light and Dark modes.

---

## 7. Feature Implementation Status (M4 vs M5)

| Feature | Status | Implementation Detail |
| :--- | :--- | :--- |
| **Role-Based Auth** | Implemented (M4) | Firebase Auth + Firestore 'role' field routing. |
| **Student Registration** | Implemented (M4) | Automated profile creation + Email verification. |
| **QR Generation** | Implemented (M4) | Lecturer creates session with auto-expiry. |
| **Biometric Gate** | Implemented (M5) | **Mandatory** Fingerprint/Face scan before scanning QR. |
| **Geofencing** | Implemented (M5) | Blocks scans if student distance > 100m from lecturer. |
| **Dynamic QR** | Implemented (M5) | QR changes every 60s; uses NTP sync to prevent time-spoofing. |
| **Duplicate Prevention**| Implemented (M5) | Uses `${sessionId}_${uid}` path to enforce 1 record/session. |
| **Hardened Admin** | Implemented (M5) | "Add Lecturer" creates real Firebase Auth accounts securely. |
| **Auto-Absence** | Implemented (M5) | Batch-marks non-scanners as 'Absent' on session close. |

## 8. Evaluation & Test Matrix (M5 Evidence)

The following matrix represents the verification logic tested during the M5 hardening phase.

| Test ID | Scenario | Steps | Expected Result | Result |
| :--- | :--- | :--- | :--- | :--- |
| **T01** | Proxy Attempt (Remote) | Student scans photo of QR from home. | **REJECTED**: Geofencing detects >100m distance. | PASS |
| **T02** | Time Spoofing | Student changes phone clock to reuse old QR. | **REJECTED**: NTP sync validates real-time window. | PASS |
| **T03** | Duplicate Scan | Student scans QR twice for same session. | **SUCCESS**: Original record is merged (No duplicates). | PASS |
| **T04** | Closed Session | Student scans QR after Lecturer stops session. | **REJECTED**: `isActive` flag check fails. | PASS |
| **T05** | Device Sharing | Student logs into a friend's phone. | **REJECTED**: Device ID mismatch with Firestore binding. | PASS |
| **T06** | Identity Theft | Unauthorized user opens scanner. | **REJECTED**: Biometric check fails. | PASS |

