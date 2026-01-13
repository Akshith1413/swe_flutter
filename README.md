# 🌱 SWE_AI_CROP — AI Crop Disease Detection & Advisory System

An AI-powered agriculture assistant that helps farmers detect crop diseases from leaf images and receive treatment recommendations using Computer Vision and AI.

---

## 🚜 Overview

**SWE_AI_CROP** is a farmer-focused intelligent agriculture support system that combines computer vision, backend inference APIs, and multilingual interfaces to make crop disease detection accessible and practical.

The system integrates:

- 📱 Mobile and Web UI
- 🧠 CNN-based disease detection
- 🤖 Advisory recommendation system
- 🌍 Multilingual support
- 🔊 Voice-ready interface hooks

The goal is to build a simple, usable AI tool for real-world farming scenarios.

---

## 🎯 Project Goal

This project aims to build an intelligent agriculture assistant that can:

- 🌿 Detect crop diseases from leaf images
- 💊 Suggest treatment recommendations
- 🌍 Support multiple Indian languages
- 📱 Work on Android and Web platforms
- ⚡ Provide fast AI inference through backend APIs

---

## 🧰 Tech Stack

### Frontend
- React (Vite)
- Tailwind CSS
- Context API
- Flutter (Mobile App)
- i18n Localization

### AI / ML
- TensorFlow / Keras
- EfficientNetB0 (Transfer Learning)
- PlantVillage Dataset

### Backend
- FastAPI (Inference API)
- CNN Model Integration
- Advisory generation module

### Deployment
- Vercel (Web Frontend)
- Backend API (local/server)

---

## 🏗️ Project Structure

```
SWE_AI_CROP
│
├── android/                 # Flutter Android build
├── ios/                     # Flutter iOS build
├── lib/                     # Flutter app source
├── src/                     # React web application
│   ├── components/
│   ├── pages/
│   ├── services/
│   ├── context/
│   ├── translations/
│   ├── utils/
│   ├── App.jsx
│   └── main.jsx
│
├── model/
│   └── crop_disease_model.h5
│
├── package.json
├── vite.config.js
└── README.md
```

---

## ✨ Current Features

### 👤 User Access
- Language selection
- Guest mode
- Login UI
- User profile screen

### 📸 Image Input
- Camera capture UI
- Image upload interface
- Preprocessing hooks

### 🧠 Disease Detection
- CNN training pipeline
- Model export support
- Image preprocessing utilities

### 🤖 Advisory System
- Advisory UI components
- AI service integration layer (API-ready)

### 🌍 Localization
Supported languages include:
English, Hindi, Tamil, Telugu, Kannada, Marathi, Bengali, Gujarati, Punjabi, Malayalam, Odia, Urdu, Assamese, Nepali, Sanskrit

---

## 🧪 CNN Model Training

Dataset: **PlantVillage**  
Architecture: **EfficientNetB0 (Transfer Learning)**  
Framework: **TensorFlow / Keras**

Model output:

```
crop_disease_model.h5
```

Training performed using GPU-enabled environments (Colab/Kaggle).

---

## 🔄 System Architecture

```
Farmer
  │
  ▼
Frontend (React / Flutter)
  │
  ▼
Backend API (FastAPI)
  │
  ▼
CNN Model Inference
  │
  ▼
Advisory Generator
  │
  ▼
UI Response + Guidance
```

---

## ▶️ Running the Web App (React)

Install dependencies:

```
npm install
```

Run locally:

```
npm run dev
```

Build project:

```
npm run build
```

---

## ▶️ Running the Mobile App (Flutter)

Install dependencies:

```
flutter pub get
```

Run app:

```
flutter run
```

Build APK:

```
flutter build apk
```


---

## 👥 Team Roles

| Name | Role |
|------|------|
| Bhuvaneshwari | DevOps Engineer |
| Dhanuja | Backend Engineer |
| Ramaroshinee | Full Stack Developer |
| Akshith | Frontend Developer |
| Saketh | Testing Engineer |

---

## 🌾 Vision

To build an AI-powered agriculture assistant that makes crop disease detection fast, accessible, and understandable for farmers.




// Unit 47 by RSAKETH

// Unit 73 by Akshith1413

// Unit 139 by DhanujaAnbalagan
