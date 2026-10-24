# Presentation Slides: EduGuard Smart Attendance System

Copy the content below into your presentation software (PowerPoint, Google Slides, or Canva).

---

### **Slide 1: Title Slide**
*   **Main Title:** EduGuard: Smart Attendance System
*   **Subtitle:** A High-Security, Real-Time Solution for Modern Institutions
*   **Presenter:** [Your Name]
*   **Technology:** Flutter | Firebase | Biometrics | Geofencing

---

### **Slide 2: The Problem**
*   **Bullet Points:**
    *   **Proxy Cheating:** Students signing in for absent friends.
    *   **Manual Errors:** Paper-based registers are slow and easy to lose.
    *   **Lack of Real-time Data:** Lecturers cannot see attendance trends instantly.
    *   **Time Fraud:** Manipulating device clocks to mark attendance after hours.

---

### **Slide 3: The Solution (EduGuard)**
*   **Content:** A cross-platform mobile application that creates a "Secure Verification Chain."
*   **Key Value Props:**
    *   Eliminates proxy attendance.
    *   Provides instant analytics for students and staff.
    *   Automated absence reporting.
    *   Cloud-synced and hardware-bound.

---

### **Slide 4: Role-Based Architecture**
*   **Student:** Scan QR, View history, Track attendance %, Receive alerts.
*   **Lecturer:** Create sessions, Generate Dynamic QRs, View/Edit registry, Export data.
*   **Admin:** Manage users, Courses/Modules, Reset device bindings, System monitoring.

---

### **Slide 5: The Secure Verification Chain (Security Layer 1)**
*   **Feature:** Biometric Gatekeeper
*   **Details:** 
    *   Mandatory Fingerprint/FaceID check via `local_auth`.
    *   Ensures the person holding the device is the registered student.
    *   Blocks unauthorized access to the scanner.

---

### **Slide 6: The Secure Verification Chain (Security Layer 2)**
*   **Feature:** Geofencing (GPS Validation)
*   **Details:**
    *   Captures Lecturer's coordinates when session starts.
    *   Compares Student's location during scan.
    *   **Rule:** Scan is rejected if distance > 100 meters.
    *   Eliminates "remote" scanning from outside the classroom.

---

### **Slide 7: The Secure Verification Chain (Security Layer 3)**
*   **Feature:** Dynamic Time-Synced QR
*   **Details:**
    *   QR code changes visually every **60 seconds**.
    *   Uses **NTP (Network Time Protocol)** synchronization.
    *   Ignores local phone clock to prevent "Time-Travel" cheating.
    *   Makes photos of QR codes useless within 1 minute.

---

### **Slide 8: Data Integrity & Automation**
*   **Deterministic IDs:** Prevents duplicate scans for the same session.
*   **Device Binding:** One account = One hardware device ID.
*   **Automated Absences:** 
    *   System performs a batch-write on session close.
    *   Identifies missing students and marks them 'Absent' automatically.

---

### **Slide 9: Technical Stack**
*   **Frontend:** Flutter (Single codebase for Android/iOS/Web).
*   **Backend:** Firebase Cloud Firestore (NoSQL, Real-time).
*   **Auth:** Firebase Authentication with Email Verification.
*   **Messaging:** Firebase Cloud Messaging (FCM) for session alerts.
*   **Data:** `csv` & `printing` for professional reporting.

---

### **Slide 10: Evaluation & Results**
*   **Performance:** Scans processed in < 500ms.
*   **Security:** Successfully rejected all "Off-site" and "Outdated QR" test attempts.
*   **UX:** High-contrast Dark Mode support and intuitive navigation tabs.

---

### **Slide 11: Future Work**
*   **Server-side Logic:** Moving absence marking to Cloud Functions.
*   **Beacon Support:** Using Bluetooth Low Energy (BLE) for indoor location accuracy.
*   **Analytics Dashboard:** Predictive modeling to identify at-risk students.

---

### **Slide 12: Conclusion & Q&A**
*   **Summary:** EduGuard isn't just an app; it's a hardened institutional tool for accountability and data-driven management.
*   **Closing:** Thank you for your time.
*   **Questions?**
