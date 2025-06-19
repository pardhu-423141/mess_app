

Flutter SDK

Android Studio or VS Code

Git

Java JDK 17+

Android SDK (with ndk;23.1.7779620 if your project uses native C++)

🔁 STEP 1: Fork the Repository
Go to your GitHub repository in a browser.

Click on the "Fork" button (top-right).

GitHub will create a copy of your repo under your friend's account.

💻 STEP 2: Clone the Forked Repository
Open a terminal and run:

bash
Copy
Edit
git clone https://github.com/<friend-username>/<your-repo-name>.git
cd <your-repo-name>
🔧 STEP 3: Set Up Flutter
Run these commands to set up the project:

bash
Copy
Edit
flutter pub get         # Downloads dependencies
flutter doctor          # Checks environment
If flutter doctor reports issues, resolve them (especially Android SDK and JDK).

🧹 STEP 4: Clean and Prepare
bash
Copy
Edit
flutter clean           # Cleans previous builds
flutter pub get         # Again, just to ensure dependencies are in place
⚙️ STEP 5: Set NDK (if needed)
If your project needs NDK:

In Android Studio:

Go to File > Settings > SDK Tools

Check NDK (Side by Side)

Click Show Package Details

Check 23.1.7779620 and Apply

In android/build.gradle.kts, ensure this is added:

kotlin
Copy
Edit
android {
    ndkVersion = "23.1.7779620"
}
If the project does NOT use C++ or native libraries, just comment out or remove NDK-related code in build.gradle.kts.

📱 STEP 6: Run the App on a Device
Connect an Android phone with USB Debugging enabled, or start an Android emulator.

Then run:

bash
Copy
Edit
flutter run
