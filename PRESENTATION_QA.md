# EduGuard: Smart Attendance System - Presentation Q&A Guide

This guide prepares you for common and advanced questions that institutional reviewers or technical examiners might ask during your M5 presentation.

---

## 1. Security & Anti-Cheating (The "Secure Verification Chain")

**Q: How does your app prevent a student from sending a photo of the QR code to a friend who is not in class?**
*   **Answer:** We use **Geofencing**. When the student scans the code, the app captures their GPS coordinates and compares them to the lecturer's coordinates (stored when the session started). If the distance is greater than 100 meters, the scan is rejected. Additionally, we use **Dynamic QR codes** that refresh every 60 seconds, meaning a photo becomes useless almost immediately.

**Q: What if a student changes their phone's system time to bypass the 60-second QR expiry?**
*   **Answer:** The app is "time-hardened." We implemented a `TimeService` that uses **NTP (Network Time Protocol)** to fetch the actual global network time. The app ignores the phone's local clock and uses this synchronized time to validate the QR window, making time-spoofing impossible.

**Q: Can a student log in on multiple devices or have someone else log in for them?**
*   **Answer:** No, we implemented **Device Binding**. During registration, the student's unique hardware ID is saved to their Firestore profile. Upon login, the app checks if the current device matches the one on file. If not, access is denied. To change devices, an Admin must manually reset their ID.

**Q: How do you ensure the person holding the phone is actually the registered student?**
*   **Answer:** Before the scanner opens, the app enforces a **Biometric Gate**. The student must pass a fingerprint or face scan (using the `local_auth` package) to prove their identity before they are allowed to mark attendance.

---

## 2. Technical Architecture & Backend (Firebase)

**Q: Why did you choose Cloud Firestore over a traditional SQL database?**
*   **Answer:** Firestore provides **Real-time Streams**. This allows the Student Dashboard to instantly show a "Live Session" notification the moment a lecturer starts one, and allows lecturers to see the registry update live as students scan, without refreshing the page.

**Q: How do you handle thousands of attendance records efficiently?**
*   **Answer:** We use **Composite Indexing** for complex queries (like filtering by module AND date). We also designed a flat data structure to ensure that fetching a student's history doesn't require loading unnecessary data from other users.

**Q: How are "Absents" handled? Does the student have to do anything?**
*   **Answer:** Absents are handled automatically via a **Firestore Batch Write**. When a lecturer stops a session, the system identifies all students enrolled in that module who haven't scanned yet and writes an "Absent" record for them in a single, high-speed operation.

---

## 3. Flutter & UI/UX

**Q: How did you ensure the app remains usable in low-light classrooms?**
*   **Answer:** We implemented **Full Dark Mode support**. The app automatically detects the system theme and switches to high-contrast, low-brightness colors to ensure the QR scanner and text remain legible in all environments.

**Q: What is the benefit of using `IndexedStack` in your main screens?**
*   **Answer:** `IndexedStack` preserves the "State" of each tab. This means if a student is halfway through a search in their History and switches to the Home tab and back, their search results and scroll position are still there, providing a smoother user experience.

---

## 4. Online & Hybrid Classes (The "Flexibility" Question)

**Q: Your system relies on Geofencing. What happens during online classes where students are in different cities?**
*   **Answer:** EduGuard is built on a "Configurable Security" model. For online classes, the **Geofencing requirement can be disabled or widened** by the Lecturer. In this mode, the security chain shifts its focus to the other two layers:
    1.  **Biometric Gate**: Ensuring the registered student is the one marking presence.
    2.  **Dynamic QR Expiry**: Since the QR is shown via screen-share, it still expires every 60 seconds, ensuring students must be watching the live stream to catch the code.
*   **Future Pivot**: We would integrate with the video conferencing API (e.g., Zoom SDK) to detect if the student's camera is on or if they are actively participating in the session.

---

## 5. Scalability & Future Work

**Q: How would you scale this for a university with 50,000 students?**
*   **Answer:** We would move the "Automated Absence" logic to **Firebase Cloud Functions** (server-side) to reduce the load on the lecturer's device. We would also implement "Shard Counters" for attendance statistics to prevent database contention during peak scanning minutes.

**Q: Are there any features you planned but didn't implement?**
*   **Answer:** While we have geofencing and biometrics, a future improvement would be **Wi-Fi SSID Validation**, where the app checks if the student is connected to the specific campus router assigned to that lecture hall for an even tighter security loop.

---

## 5. Summary of Packages Used (Know your tools!)
*   **`mobile_scanner`**: High-speed QR engine.
*   **`geolocator`**: GPS and distance calculations.
*   **`local_auth`**: Biometric (Fingerprint/Face) integration.
*   **`ntp`**: Network time synchronization for anti-cheating.
*   **`device_info_plus`**: Hardware ID capture for device binding.
*   **`share_plus` & `csv`**: Reporting and data export.
