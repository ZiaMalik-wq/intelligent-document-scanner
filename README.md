# Intelligent Document Scanner

A production-grade document scanning application featuring advanced image enhancement filters, multi-page PDF generation, and OCR capabilities. The system is split into a FastAPI backend and a Flutter frontend.

## Key Features

1. Manual Document Cropping: High-precision manual boundary selection for documents.
2. Advanced Image Enhancement:
    * Magic Color: Vibrant enhancement while maintaining natural colors.
    * B&W (Smart Legibility): Production-grade thresholding optimized for small text and light ink.
    * Grayscale: Professional contrast-balanced grayscale conversion.
3. Shadow and Curl Suppression: Morphological dilation-based illumination normalization to remove page folds and shadows.
4. Multi-page PDF Generation: Create single multi-page PDF documents from multiple scans.
5. OCR Integration: Extract searchable text layer into generated PDFs.
6. Gallery Management: Automatic synchronization and cleanup of discarded or removed scans.

## Technology Stack

### Backend
* Framework: FastAPI (Python 3.10+)
* Computer Vision: OpenCV
* OCR Engine: Tesseract OCR
* Database: SQLAlchemy (SQLite for development, compatible with PostgreSQL)
* PDF Engine: Pytesseract and Pillow

### Frontend
* Framework: Flutter
* State Management: Provider
* Camera: Camera plugin with manual crop integration
* Networking: HTTP with custom service architecture

## Project Structure

* /backend: FastAPI server and computer vision logic.
* /frontend: Flutter mobile application.

## Setup Instructions

### Backend Setup

1. Prerequisites:
    * Install Python 3.10 or higher.
    * Install Tesseract OCR on your system.
    * (Windows) Add Tesseract path to your environment variables or specify it in .env.

2. Installation:
    ```bash
    cd backend
    python -m venv .venv
    source .venv/bin/activate  # On Windows: .venv\Scripts\activate
    pip install -r requirements.txt
    ```

3. Configuration:
    * Create a .env file based on .env.example.
    * Specify TESSERACT_PATH if not in your system path.

4. Running:
    ```bash
    python main.py
    ```
    The API will be available at http://localhost:8000.

### Frontend Setup

1. Prerequisites:
    * Install Flutter SDK (stable channel).
    * Android Studio or Xcode for mobile emulation.

2. Installation:
    ```bash
    cd frontend
    flutter pub get
    ```

3. Configuration:
    * Update lib/core/constants.dart with your backend IP address if running on a physical device.

4. Running:
    ```bash
    flutter run
    ```

## Deployment with Docker

The project includes a production-ready Docker configuration.

1. Build and Start:
    ```bash
    cd backend
    docker-compose up -d --build
    ```
    This will start the API and create persistent volumes for your scans and database.

## License

This project is licensed under the MIT License.
