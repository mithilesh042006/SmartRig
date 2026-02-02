# Smart PC Builder & Performance Predictor

## 1. Project Overview

Smart PC Builder & Performance Predictor is a cross-platform mobile application that allows users to virtually build a custom PC by selecting individual components.  
The app validates compatibility, predicts real-world performance (FPS, power usage), compares market prices, and provides direct purchase links for each component.

The application is built using **Flutter** and connects **directly to Firebase** for authentication and database services.  
No custom backend is used in the initial phase. E-commerce APIs are integrated directly into the Flutter application.

---

## 2. Problem Statement

- PC component compatibility is complex and error-prone
- Users cannot easily estimate real-world gaming or workload performance
- Prices vary across platforms and are difficult to compare
- Beginners lack structured guidance when building a PC

---

## 3. Solution

A guided PC-building platform that:
- Suggests compatible components
- Predicts gaming and system performance
- Displays real-time prices and shopping links
- Calculates total cost and power requirements
- Highlights bottlenecks and optimization suggestions

---

## 4. Target Users

- First-time PC builders
- Gamers
- Content creators
- Budget-conscious buyers
- PC enthusiasts

---

## 5. Core Features

### 5.1 Guided PC Builder
Users build a PC step-by-step by selecting:
- CPU
- GPU
- Motherboard
- RAM
- Storage (SSD/HDD/NVMe)
- Power Supply (PSU)
- Case
- Cooling system

---

### 5.2 Component Recommendation System
- Displays all available products
- Filters by price, brand, and use case
- Direct purchase links

---

### 5.3 Price Comparison & Shopping Links
- Direct e-commerce API integration
- Affiliate links
- Total cost calculation

---

### 5.4 Compatibility Validation Engine
- Rule-based validation inside Flutter
- Socket, size, power, and cooling checks

---

### 5.5 Performance Prediction Engine
- Local calculation using benchmark data
- FPS, power usage, bottleneck estimation

---

### 5.6 Save, Share & Export
- Firebase Authentication
- Firestore for saved builds
- PDF export

---

## 6. Tech Stack

- Flutter (Frontend)
- Firebase Authentication
- Firebase Firestore
- Firebase Storage
- E-commerce APIs

---

## 7. System Architecture

Flutter App → Firebase → E-commerce APIs

---

## 8. Firestore Schema

Users, Components, Builds, Games

---

## 9. Monetization

Affiliate links, sponsored listings, future premium features

---

## 10. MVP Scope

PC builder, compatibility checks, pricing, FPS prediction, save builds

---

## 11. Future Enhancements

Backend services, ML prediction, community builds

---

## 12. License

TBD
