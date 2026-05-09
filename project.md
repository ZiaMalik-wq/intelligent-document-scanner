# AI-Powered Document Scanner & OCR System

# Complete Backend + Frontend Implementation Guide

---

# PROJECT OVERVIEW

Build a production-grade AI-powered document scanning system with:

* Flutter mobile frontend
* Python FastAPI backend
* OpenCV document processing
* OCR extraction
* Searchable PDF generation
* AI-powered enhancements

---

# FINAL TECH STACK

## Frontend

* Flutter
* Dart
* Riverpod / Provider
* Camera package
* HTTP package
* Image package
* PDF viewer package

## Backend

* FastAPI
* OpenCV
* Tesseract OCR
* EasyOCR
* NumPy
* Pillow
* PyMuPDF
* SQLAlchemy
* PostgreSQL
* Redis (optional)

## Deployment

* Docker
* Nginx
* GitHub Actions
* Render/Railway/AWS

---

# GIT WORKFLOW REQUIREMENTS

## IMPORTANT DEVELOPMENT RULE

After EVERY:

* completed feature
* completed phase
* bug fix milestone
* API module
* UI module

The system MUST:

1. Create a new Git branch
2. Commit clean code
3. Push branch to GitHub
4. Open Pull Request (optional)
5. Merge only after testing

---

# BRANCH NAMING CONVENTION

## Backend Branches

```bash
backend/setup-project
backend/auth-system
backend/document-upload
backend/edge-detection
backend/perspective-correction
backend/image-enhancement
backend/ocr-engine
backend/searchable-pdf
backend/history-management
backend/ai-document-classification
backend/docker-deployment
```

---

## Frontend Branches

```bash
frontend/setup-ui
frontend/navigation-system
frontend/camera-module
frontend/document-overlay
frontend/crop-screen
frontend/ocr-preview
frontend/export-system
frontend/history-screen
frontend/authentication-ui
frontend/settings-screen
```

---

# COMMIT MESSAGE RULES

## Examples

```bash
feat: added document edge detection pipeline
feat: implemented perspective correction
feat: added searchable PDF generation
fix: corrected OCR confidence filtering
refactor: optimized image preprocessing
```

---

# BACKEND IMPLEMENTATION GUIDE

# BACKEND ARCHITECTURE

```text
FastAPI Backend
    ↓
REST APIs
    ↓
Image Processing Service
    ↓
OpenCV Pipeline
    ↓
OCR Service
    ↓
Export Service
    ↓
Database Layer
```

---

# BACKEND FOLDER STRUCTURE

```text
backend/
│
├── app/
│   ├── api/
│   ├── core/
│   ├── models/
│   ├── schemas/
│   ├── services/
│   ├── utils/
│   ├── database/
│   ├── middleware/
│   ├── ocr/
│   ├── cv/
│   └── exports/
│
├── uploads/
├── processed/
├── tests/
├── docker/
├── requirements.txt
├── Dockerfile
└── main.py
```

---

# BACKEND PHASES

# PHASE 1 — PROJECT SETUP

## Objectives

* Initialize FastAPI project
* Configure virtual environment
* Setup PostgreSQL
* Setup Docker
* Setup linting and formatting

---

## Install Dependencies

```bash
pip install fastapi uvicorn opencv-python pillow numpy pytesseract easyocr sqlalchemy psycopg2-binary python-multipart python-jose passlib bcrypt pymupdf reportlab
```

---

## Deliverables

* FastAPI running
* Health endpoint
* Docker setup
* PostgreSQL connection
* Environment variables
* Logging system

---

## Required APIs

```http
GET /health
```

---

## Git Requirements

### Branch

```bash
git checkout -b backend/setup-project
```

### Push

```bash
git add .
git commit -m "feat: initialized backend architecture"
git push origin backend/setup-project
```

---

# PHASE 2 — AUTHENTICATION SYSTEM

## Features

* JWT authentication
* User registration
* Login
* Refresh tokens
* Password hashing

---

## APIs

```http
POST /auth/register
POST /auth/login
POST /auth/refresh
GET /auth/me
```

---

## Database Tables

### users

```sql
id
name
email
password_hash
created_at
```

---

## Security Requirements

* bcrypt hashing
* JWT tokens
* Access + refresh token system
* Secure password validation

---

## Git Branch

```bash
git checkout -b backend/auth-system
```

---

# PHASE 3 — DOCUMENT UPLOAD SYSTEM

## Features

* Upload image
* Upload PDF
* Validate file types
* File size validation
* Store uploads
* Generate unique filenames

---

## Supported Formats

* JPG
* PNG
* JPEG
* WEBP
* PDF
* TIFF

---

## APIs

```http
POST /documents/upload
GET /documents/{id}
DELETE /documents/{id}
```

---

## Requirements

* Max size: 20MB
* Prevent duplicate uploads
* Auto cleanup temp files
* Metadata extraction

---

## Git Branch

```bash
git checkout -b backend/document-upload
```

---

# PHASE 4 — DOCUMENT EDGE DETECTION

## Purpose

Detect physical document boundaries.

---

## OpenCV Pipeline

```text
Image
 → Resize
 → Grayscale
 → Gaussian Blur
 → Canny Edge Detection
 → Contour Detection
 → Polygon Approximation
 → Detect Largest Rectangle
```

---

## Required Features

* Detect 4 corners
* Detect largest contour
* Draw overlay borders
* Return corner coordinates
* Manual correction support

---

## API

```http
POST /scanner/detect-edges
```

---

## Response

```json
{
  "corners": [
    {"x": 100, "y": 50},
    {"x": 450, "y": 60},
    {"x": 460, "y": 700},
    {"x": 90, "y": 710}
  ]
}
```

---

## Git Branch

```bash
git checkout -b backend/edge-detection
```

---

# PHASE 5 — PERSPECTIVE CORRECTION

## Purpose

Convert skewed document into flat scan.

---

## Required Algorithms

* Homography transform
* Perspective warp
* Coordinate normalization

---

## OpenCV Functions

```python
cv2.getPerspectiveTransform()
cv2.warpPerspective()
```

---

## Features

* Auto crop
* Flatten document
* Maintain quality
* Auto rotate

---

## API

```http
POST /scanner/correct-perspective
```

---

## Git Branch

```bash
git checkout -b backend/perspective-correction
```

---

# PHASE 6 — IMAGE ENHANCEMENT PIPELINE

## Purpose

Improve OCR accuracy.

---

## Features

* Noise removal
* Sharpening
* Adaptive thresholding
* Brightness correction
* Contrast enhancement
* Shadow removal

---

## Scan Modes

### Color

### Grayscale

### Black & White

### High Contrast

### Receipt Mode

---

## OpenCV Operations

```python
cv2.adaptiveThreshold()
cv2.fastNlMeansDenoising()
cv2.equalizeHist()
```

---

## API

```http
POST /scanner/enhance
```

---

## Git Branch

```bash
git checkout -b backend/image-enhancement
```

---

# PHASE 7 — OCR ENGINE

## OCR Engines

### Primary

* Tesseract OCR

### Secondary

* EasyOCR

---

## Features

* Multi-language OCR
* Bounding boxes
* Confidence scoring
* Structured text extraction
* Handwriting support

---

## Supported Languages

* English
* Urdu
* Arabic
* Hindi

---

## APIs

```http
POST /ocr/extract
POST /ocr/extract-handwriting
```

---

## OCR Response

```json
{
  "text": "Invoice Number 12345",
  "confidence": 94,
  "blocks": []
}
```

---

## Git Branch

```bash
git checkout -b backend/ocr-engine
```

---

# PHASE 8 — SEARCHABLE PDF GENERATION

## Features

* Searchable PDF
* OCR text layer
* Highlighted text
* Downloadable PDF

---

## Libraries

* PyMuPDF
* ReportLab

---

## APIs

```http
POST /export/pdf
POST /export/docx
POST /export/txt
```

---

## Git Branch

```bash
git checkout -b backend/searchable-pdf
```

---

# PHASE 9 — DOCUMENT HISTORY MANAGEMENT

## Features

* Save scans
* Rename scans
* Delete scans
* Search scans
* Pagination

---

## Database Tables

### scans

```sql
id
user_id
original_file
processed_file
ocr_text
created_at
```

---

## APIs

```http
GET /history
GET /history/{id}
DELETE /history/{id}
```

---

## Git Branch

```bash
git checkout -b backend/history-management
```

---

# PHASE 10 — AI DOCUMENT CLASSIFICATION

## Purpose

Automatically detect document type.

---

## Categories

* Invoice
* Receipt
* Resume
* Passport
* ID Card
* Contract
* Form

---

## AI Options

* CNN classifier
* Transformers
* Rule-based NLP

---

## API

```http
POST /ai/classify-document
```

---

## Git Branch

```bash
git checkout -b backend/ai-document-classification
```

---

# PHASE 11 — TABLE EXTRACTION

## Features

* Detect tables
* Extract rows
* Export CSV
* Export Excel

---

## Libraries

* Camelot
* Tabula
* PaddleOCR Layout

---

## APIs

```http
POST /tables/extract
```

---

## Git Branch

```bash
git checkout -b backend/table-extraction
```

---

# PHASE 12 — DEPLOYMENT & DEVOPS

## Features

* Dockerization
* GitHub Actions
* Nginx reverse proxy
* CI/CD pipeline
* Production environment variables

---

## Deliverables

* Dockerfile
* docker-compose.yml
* CI/CD workflows
* Production deployment guide

---

## Git Branch

```bash
git checkout -b backend/docker-deployment
```

---

# BACKEND TESTING REQUIREMENTS

## Unit Tests

* OCR testing
* Edge detection testing
* Perspective correction testing
* Authentication testing

---

## Integration Tests

* Full document processing pipeline
* Upload to export flow

---

# FRONTEND IMPLEMENTATION GUIDE

# FRONTEND ARCHITECTURE

```text
Flutter App
    ↓
State Management
    ↓
API Layer
    ↓
Scanner UI
    ↓
OCR Results UI
```

---

# FRONTEND FOLDER STRUCTURE

```text
frontend/
│
├── lib/
│   ├── core/
│   ├── screens/
│   ├── widgets/
│   ├── services/
│   ├── providers/
│   ├── models/
│   ├── utils/
│   └── routes/
│
├── assets/
├── test/
└── pubspec.yaml
```

---

# FRONTEND PHASES

# PHASE 1 — FLUTTER PROJECT SETUP

## Tasks

* Initialize Flutter project
* Configure app theme
* Setup routing
* Setup state management
* Configure API client

---

## Packages

```yaml
camera:
http:
flutter_riverpod:
image_picker:
pdfx:
permission_handler:
path_provider:
```

---

## Git Branch

```bash
git checkout -b frontend/setup-ui
```

---

# PHASE 2 — NAVIGATION SYSTEM

## Screens

* Splash Screen
* Login Screen
* Home Screen
* Scanner Screen
* OCR Result Screen
* Export Screen
* History Screen
* Settings Screen

---

## Requirements

* Bottom navigation
* Named routes
* Protected routes

---

## Git Branch

```bash
git checkout -b frontend/navigation-system
```

---

# PHASE 3 — CAMERA MODULE

## Features

* Live camera preview
* Flash toggle
* Zoom support
* Auto focus
* Capture image
* Gallery upload

---

## Requirements

* High quality capture
* Smooth preview
* Camera permissions

---

## Git Branch

```bash
git checkout -b frontend/camera-module
```

---

# PHASE 4 — DOCUMENT OVERLAY DETECTION UI

## Features

* Real-time document border overlay
* Live corner indicators
* Auto-capture animation

---

## Requirements

* Overlay painter
* Smooth rendering
* Responsive camera frame

---

## Git Branch

```bash
git checkout -b frontend/document-overlay
```

---

# PHASE 5 — CROP & EDIT SCREEN

## Features

* Drag crop corners
* Rotate image
* Apply filters
* Adjust brightness
* Preview corrected document

---

## Filters

* Grayscale
* Black & White
* High Contrast
* Original

---

## Git Branch

```bash
git checkout -b frontend/crop-screen
```

---

# PHASE 6 — OCR RESULT SCREEN

## Features

* Display extracted text
* Editable OCR text
* Copy text
* Highlight recognized regions
* Confidence display

---

## Git Branch

```bash
git checkout -b frontend/ocr-preview
```

---

# PHASE 7 — EXPORT SYSTEM UI

## Features

* Export PDF
* Export TXT
* Export DOCX
* Share document
* Download searchable PDF

---

## Git Branch

```bash
git checkout -b frontend/export-system
```

---

# PHASE 8 — HISTORY MANAGEMENT UI

## Features

* Saved scans
* Search history
* Delete scans
* View previous OCR

---

## Git Branch

```bash
git checkout -b frontend/history-screen
```

---

# PHASE 9 — AUTHENTICATION UI

## Features

* Login
* Register
* Forgot password
* JWT storage

---

## Git Branch

```bash
git checkout -b frontend/authentication-ui
```

---

# PHASE 10 — SETTINGS & PREFERENCES

## Features

* OCR language selection
* Theme toggle
* Scan quality selection
* Export settings

---

## Git Branch

```bash
git checkout -b frontend/settings-screen
```

---

# FRONTEND UI REQUIREMENTS

# HOME SCREEN

## Must Include

* Quick scan button
* Upload button
* Recent scans
* OCR statistics

---

# SCANNER SCREEN

## Must Include

* Camera preview
* Edge overlay
* Capture button
* Auto scan indicator

---

# OCR RESULT SCREEN

## Must Include

* Extracted text
* Editable content
* Confidence score
* Highlighted OCR regions

---

# SETTINGS SCREEN

## Must Include

* OCR language selection
* Scan quality
* Export format
* Theme switch

---

# API INTEGRATION REQUIREMENTS

## Flutter Service Layer

### APIs

```http
POST /auth/login
POST /documents/upload
POST /scanner/detect-edges
POST /scanner/correct-perspective
POST /ocr/extract
POST /export/pdf
GET /history
```

---

# PERFORMANCE REQUIREMENTS

## Backend

* OCR < 5 seconds
* Upload < 2 seconds
* Perspective correction < 1 second

---

## Frontend

* Smooth camera preview
* No UI lag
* Fast screen transitions

---

# SECURITY REQUIREMENTS

## Backend

* JWT authentication
* HTTPS
* Rate limiting
* File validation
* Temporary file cleanup

---

## Frontend

* Secure token storage
* Permission handling
* Input validation

---

# CI/CD REQUIREMENTS

## GitHub Actions

### Backend

* Run tests
* Lint code
* Build Docker image

---

### Frontend

* Flutter analyze
* Flutter test
* APK build

---

# FINAL DELIVERABLES

## Backend Deliverables

* FastAPI source code
* OpenCV processing pipeline
* OCR engine
* Docker setup
* Swagger API docs
* Unit tests

---

## Frontend Deliverables

* Flutter source code
* Responsive UI
* Camera integration
* OCR workflow
* APK build

---

# FINAL PROJECT TITLE

## SmartScan AI — Intelligent Document Scanner & OCR Platform

---

# FINAL DEVELOPMENT RULE

After completing EVERY feature:

1. Create branch
2. Commit code
3. Push to GitHub
4. Test functionality
5. Merge only after verification

This workflow is mandatory throughout the project.
