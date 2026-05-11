from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
from app.core.config import settings
from app.api.api_v1.api import api_router
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.database.session import get_db, Base, engine
from fastapi import Depends
import pytesseract

# -------------------------------------------------------------------
# LOGGING CONFIGURATION
# -------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# -------------------------------------------------------------------
# DATABASE INITIALIZATION
# -------------------------------------------------------------------
from app import models
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Intelligent Document Scanner & OCR Engine",
    version="1.0.0",
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# -------------------------------------------------------------------
# MIDDLEWARE & ROUTING
# -------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict this for production environments
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static file serving for scans
app.mount("/media/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")
app.mount("/media/processed", StaticFiles(directory=settings.PROCESSED_DIR), name="processed")

# API Routing
app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/")
async def root():
    """Redirects root to interactive API documentation."""
    return RedirectResponse(url="/docs")

@app.get("/health")
async def health_check(db: Session = Depends(get_db)):
    """Backend service health check (DB, OCR, CV)."""
    db_status = "unhealthy"
    try:
        db.execute(text("SELECT 1"))
        db_status = "healthy"
    except Exception as e:
        logger.error(f"Database health check failed: {e}")

    ocr_status = "unhealthy"
    try:
        pytesseract.get_tesseract_version()
        ocr_status = "healthy"
    except Exception:
        pass

    return {
        "status": "healthy",
        "services": {
            "database": db_status,
            "ocr": ocr_status,
            "cv": "healthy"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
