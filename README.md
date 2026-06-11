GCV-AI – Garage Custom Vision AI

Project Overview

GCV-AI is an AI-powered vehicle customisation application. The system allows users to upload a vehicle image, detect vehicle components, apply AI-generated modifications, save customised builds, and locate nearby services.

The project contains two main parts:

* Flutter mobile application – user interface, upload, customisation controls, Firebase login/storage.
* FastAPI backend – image processing, Roboflow detection, SAM segmentation, Stable Diffusion integration.

⸻

Main Technologies

* Flutter / Dart
* Firebase Authentication
* Firebase Storage
* Python
* FastAPI
* Roboflow
* Segment Anything Model (SAM)
* Stable Diffusion Forge / WebUI API
* Rembg
* Google Maps URL launcher

⸻

Folder Structure

gcv_mobile_app/
│
├── lib/
│   ├── screens/
│   │   ├── garage_screen.dart
│   │   └── profile_screen.dart
│   │
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── gallery_service.dart
│   │   └── gcv_api_service.dart
│   │
│   └── widgets/
│       └── garage/
│
├── android/
├── assets/
└── pubspec.yaml

The backend is located in the Python backend folder and contains the FastAPI main.py file.

⸻

Requirements

Before running the project, make sure the following are installed:

* Flutter SDK
* Android Studio or Android Emulator
* Python 3.10
* Required Python packages
* Firebase project configuration
* Stable Diffusion Forge/WebUI running with API enabled

⸻

1. Run the Stable Diffusion API

Start Stable Diffusion Forge/WebUI with API enabled.

Example:

cd stable-diffusion-webui
./webui.sh --api --nowebui

The backend expects Stable Diffusion to be available at:

http://127.0.0.1:7861/sdapi/v1/img2img

⸻

2. Run the FastAPI Backend

Open a terminal in the backend folder.

Install dependencies if required:

pip install fastapi uvicorn pillow numpy requests opencv-python rembg torch torchvision segment-anything inference-sdk

Run the backend:

python3 -m uvicorn main:app --host 0.0.0.0 --port 8010

If successful, the terminal should show that Uvicorn is running.

The backend will be available at:

http://127.0.0.1:8010

API documentation can be checked at:

http://127.0.0.1:8010/docs

⸻

3. Run the Flutter Mobile App

Open a new terminal in the Flutter app folder:

cd gcv_mobile_app
flutter pub get
flutter run

The application should launch on the selected Android emulator or connected Android device.

⸻

4. Important API Configuration

In the Flutter app, backend communication is handled in:

lib/services/gcv_api_service.dart

If using the Android emulator, the backend URL may need to use:

http://10.0.2.2:8010

If using a physical Android device, replace the backend URL with the Mac’s local network IP address, for example:

http://192.168.x.x:8010

⸻

5. Firebase Setup

Firebase is used for:

* user registration
* login
* profile management
* saving customised vehicle builds

Firebase-related code is located in:

lib/services/auth_service.dart
lib/services/gallery_service.dart

The Firebase configuration file must be present in the Flutter project.

For Android, this is usually:

android/app/google-services.json

⸻

6. Main Files to Review

Main App Screen

lib/screens/garage_screen.dart

This file controls:

* image upload
* category selection
* AI modification workflow
* detection/debug mode
* save build function
* Google Maps service search

Backend Communication

lib/services/gcv_api_service.dart

This file sends images and modification requests from Flutter to FastAPI.

Authentication

lib/services/auth_service.dart

This file handles Firebase login, registration, logout and profile updates.

Gallery / Build Saving

lib/services/gallery_service.dart

This file uploads saved vehicle builds to Firebase Storage.

Backend Processing

main.py

This file handles:

* FastAPI endpoints
* background removal
* Roboflow detection
* SAM segmentation
* Stable Diffusion image generation

⸻

7. Application Workflow

1. User logs in or registers.
2. User uploads a vehicle image.
3. Backend removes background and detects vehicle parts.
4. Roboflow identifies components such as body, wheels, windows and lights.
5. SAM attempts to generate segmentation masks.
6. User selects a modification category.
7. Stable Diffusion applies the selected modification.
8. User saves the customised build.
9. User can search for nearby services using Google Maps.

⸻

8. Known Limitations

The prototype is functional, but some limitations remain:

* Some modifications are not fully photorealistic.
* Wheel and aero modifications may have placement issues.
* Stable Diffusion uses detected regions and masks, so results depend on detection accuracy.
* SAM segmentation may occasionally fail and the system may use bounding-box fallback.
* Performance depends on available hardware.

These limitations are discussed in the dissertation evaluation section.

⸻

9. Troubleshooting

Backend not connected

Check that FastAPI is running:

python3 -m uvicorn main:app --host 0.0.0.0 --port 8010

Also check the backend URL in:

lib/services/gcv_api_service.dart

Stable Diffusion not responding

Check that Stable Diffusion is running with API enabled:

./webui.sh --api --nowebui

Flutter dependencies issue

Run:

flutter clean
flutter pub get
flutter run

Android emulator storage issue

If installation fails due to storage, uninstall the old app:

adb uninstall com.example.gcv_mobile_app

Then run again:

flutter run

⸻

10. Notes for Assessment

The project is a working proof-of-concept. The core functionality demonstrates successful integration between a Flutter mobile application, Firebase cloud services, FastAPI backend communication, computer vision detection, segmentation, and generative AI-based vehicle customisation.