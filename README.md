# Callminder ⏰📱
**Google Solution Challenge 2026 Prototype**

Callminder is not just another to-do list. It is a social accountability network designed to aggressively tackle procrastination. Built with Flutter, Firebase, and AI, Callminder allows users to set tasks and grants trusted friends the power to remotely trigger full-screen "Nudge" alarms to ensure those tasks get done. 

## 🚀 Features

* **The Remote Nudge:** Bypassing standard silent notifications, trusted connections can trigger a Native Android Full-Screen Intent that wakes up the device with a customized Call Screen.
* **AI-Powered Task Creation:** Don't want to type out all the details? Use the conversational AI Creator to instantly parse your natural language into a structured Callminder with dates, times, and recurrence rules.
* **Classic Minders:** A robust manual creation tool for precise control over Task Name, Details, Date, Time, and complex Repetition rules.
* **Social Accountability:** Connect with friends, manage permissions, and track reminder history to see who is actually staying on top of their goals.
* **Granular Customization:** Full Dark/Light mode theme support, customizable snooze timers, and granular notification sound settings.

## 🛠️ Tech Stack

* **Frontend:** Flutter (Dart)
* **Backend:** Firebase (Firestore Database, Authentication)
* **Auth:** Native Android Google Sign-In
* **AI Integration:** Llama 3 (via Groq/OpenRouter) for natural language processing
* **Native Android:** `fullScreenIntent` and WakeLock management for aggressive alarm delivery.

## ⚙️ Installation & Setup

1. **Clone the repository**
 
