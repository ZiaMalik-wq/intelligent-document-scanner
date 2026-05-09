from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.database.session import get_db
from app.models.document import Document
from app.ocr.engine import ocr_engine

router = APIRouter()

@router.post("/extract/{document_id}")
async def extract_text(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    document_id: int,
    lang: str = "eng",
    engine: str = "tesseract",
) -> Any:
    """
    Extract text from a document using OCR.
    """
    document = db.query(Document).filter(Document.id == document_id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Use the best available version of the image
    input_path = document.processed_path if document.processed_path else document.original_path
    
    try:
        ocr_result = ocr_engine.extract_text(input_path, lang=lang, engine=engine)
        
        # Save full text to database
        document.ocr_text = ocr_result["text"]
        document.status = "completed"
        db.commit()
        db.refresh(document)
        
        return {
            "document_id": document_id,
            "text": ocr_result["text"],
            "blocks": ocr_result["blocks"],
            "engine": engine,
            "lang": lang
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"OCR extraction failed: {e}"
        )
