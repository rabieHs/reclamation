# Reclamation App

A comprehensive application for managing technical support requests and equipment information for educational institutions. The application consists of a Django backend and a Flutter mobile frontend.

## Table of Contents

- [Setup and Installation](#setup-and-installation)
  - [Backend Setup](#backend-setup)
  - [Frontend Setup](#frontend-setup)
- [Running the Application](#running-the-application)
  - [Running the Backend Server](#running-the-backend-server)
  - [Running the Flutter App](#running-the-flutter-app)
- [Network Configuration](#network-configuration)
  - [Configuring Django Allowed Hosts](#configuring-django-allowed-hosts)
  - [Configuring Flutter Network Settings](#configuring-flutter-network-settings)
- [Features](#features)
- [Troubleshooting](#troubleshooting)

## Setup and Installation

### Backend Setup

1. Make sure you have Python 3.9+ installed on your system.

2. Clone the repository:
   ```bash
   git clone <repository-url>
   cd reclamation_app
   ```

3. Create a virtual environment and activate it:
   ```bash
   python -m venv venv
   # On Windows
   venv\Scripts\activate
   # On macOS/Linux
   source venv/bin/activate
   ```

4. Install the required dependencies:
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

5. Apply migrations:
   ```bash
   python manage.py migrate
   ```

6. Create a superuser (optional):
   ```bash
   python manage.py createsuperuser
   ```

### Frontend Setup

1. Make sure you have Flutter installed on your system. Follow the [official Flutter installation guide](https://flutter.dev/docs/get-started/install).

2. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```

3. Get the Flutter dependencies:
   ```bash
   flutter pub get
   ```

## Running the Application

### Running the Backend Server

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Start the Django development server:
   ```bash
   python manage.py runserver 0.0.0.0:8002
   ```

   This will start the server on port 8002 and make it accessible from other devices on your network.

### Running the Flutter App

1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```

2. Run the Flutter app:
   ```bash
   # For debugging on a connected device
   flutter run
   
   # To build an APK
   flutter build apk
   
   # To build an iOS app (Mac only)
   flutter build ios
   ```

## Network Configuration

### Configuring Django Allowed Hosts

The Django server needs to be configured to accept connections from your mobile device. This is done by adding the IP address of your device to the `ALLOWED_HOSTS` list in the Django settings.

1. Open the file `backend/gestion_reclamations/settings.py`

2. Find the `ALLOWED_HOSTS` setting and add your device's IP address:
   ```python
   ALLOWED_HOSTS = [
       '127.0.0.1',
       'localhost',
       '0.0.0.0',
       '10.0.2.2',  # Android emulator
       '192.168.1.63',  # Example IP address - replace with your own
       '192.168.1.90',  # Example IP address - replace with your own
       '10.10.68.72',   # Example IP address - replace with your own
       '172.16.13.142', # Example IP address - replace with your own
       # Add your device's IP address here
   ]
   ```

3. You may also need to update the `CORS_ALLOWED_ORIGINS` setting to include your device:
   ```python
   CORS_ALLOWED_ORIGINS = [
       "http://localhost:4200",
       "http://10.0.2.2:8002",
       "http://192.168.1.63:8002",
       "http://192.168.1.90:8002",
       "http://10.10.68.72:8002",
       "http://172.16.13.142:8002",
       # Add your device's URL here (http://YOUR_IP:8002)
   ]
   ```

4. Alternatively, for development purposes, you can set:
   ```python
   CORS_ALLOW_ALL_ORIGINS = True
   ALLOWED_HOSTS = ['*']
   ```
   
   **Note:** This is not recommended for production environments.

5. Save the file and restart the Django server.

### Configuring Flutter Network Settings

The Flutter app needs to know the IP address of the Django server to make API calls.

1. Open the file `mobile/lib/utils/network_config.dart`

2. Update the IP address in the following sections:
   ```dart
   static const List<String> possibleDevIps = [
     '172.16.13.142', // Current device IP address
     '127.0.0.1',     // localhost (for simulators)
     '10.0.2.2',      // Android emulator special IP
     '10.10.68.72',   // Mac's actual IP address
     '192.168.1.5',   // Common home network pattern
     '192.168.1.90',  // Add your device's IP address here
     // Add more IP addresses as needed
   ];

   // Current development machine IP - CHANGE THIS to your actual IP address
   static const String devMachineIp = '192.168.1.90'; // Replace with your IP

   // Get the base URL based on the platform
   static String getBaseUrl() {
     // Use the same IP for all platforms with port 8002
     return 'http://192.168.1.90:8002'; // Replace with your IP
   }

   // Get the API URL
   static String getApiUrl() {
     // Force use of the specified IP for API calls with port 8002
     return 'http://192.168.1.90:8002/api'; // Replace with your IP
   }
   ```

3. Save the file and rebuild the Flutter app.

### Finding Your IP Address

#### On Windows:
1. Open Command Prompt
2. Type `ipconfig` and press Enter
3. Look for the "IPv4 Address" under your active network adapter

#### On macOS:
1. Open System Settings
2. Go to Network > Wi-Fi > Details
3. Look for the IP Address field

#### On Linux:
1. Open Terminal
2. Type `ip addr` or `ifconfig` and press Enter
3. Look for the "inet" address under your active network adapter

## Features

- User authentication (login, register, forgot password)
- Technical specifications (fiche technique) for laboratories
- QR code scanning for equipment identification
- Reclamation creation and tracking
- Search functionality for reclamations and technical specifications
- User profile management

## Troubleshooting

### Connection Refused Errors

If you see a "Connection refused" error in the Flutter app:

1. Make sure the Django server is running
2. Check that the IP address in `network_config.dart` matches your server's IP
3. Ensure your device is on the same network as the server
4. Check if a firewall is blocking the connection
5. Verify that Django's `ALLOWED_HOSTS` includes your device's IP

### CORS Errors

If you see CORS-related errors:

1. Make sure `CORS_ALLOWED_ORIGINS` includes your device's URL
2. For development, you can set `CORS_ALLOW_ALL_ORIGINS = True`
3. Restart the Django server after making changes

### Flutter Build Errors

If you encounter build errors in Flutter:

1. Run `flutter clean` to clean the build cache
2. Run `flutter pub get` to refresh dependencies
3. Check for any outdated packages in `pubspec.yaml`
