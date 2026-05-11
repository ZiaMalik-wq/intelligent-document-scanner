from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.database.session import get_db
from app.models.document import Document
from app.ocr.engine import ocr_engine
import os

router = APIRouter()

@router.post("/extract/{document_id}")
async def extract_text(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    document_id: int,
    lang: str = "eng",
    engine: str = "auto",
) -> Any:
    """
    Extract text from a document using OCR.
    Supports both images and PDFs (converts PDF pages to images first).
    """
    document = db.query(Document).filter(Document.id == document_id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Auto-select engine based on document type
    selected_engine = engine
    if engine == "auto":
        if document.document_type == "handwritten":
            selected_engine = "easyocr"
        else:
            selected_engine = "tesseract"
            
    # Use the best available version of the image
    input_path = document.processed_path if document.processed_path else document.original_path
    
    is_pdf = (document.mime_type or "").lower() == "application/pdf" or input_path.lower().endswith(".pdf")
    
    try:
        if is_pdf:
            # Extract text from all PDF pages
            ocr_result = _extract_text_from_pdf(input_path, lang=lang, engine=selected_engine)
        else:
            ocr_result = ocr_engine.extract_text(input_path, lang=lang, engine=selected_engine)
        
        # Save full text to database
        document.ocr_text = ocr_result["text"]
        document.status = "completed"
        db.commit()
        db.refresh(document)
        
        return {
            "document_id": document_id,
            "text": ocr_result["text"],
            "blocks": ocr_result.get("blocks", []),
            "engine": selected_engine,
            "lang": lang
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"OCR extraction failed: {e}"
        )


def _extract_text_from_pdf(pdf_path: str, lang: str = "eng", engine: str = "tesseract") -> dict:
    """
    Convert each page of a PDF to an image and run OCR on it.
    Uses PyMuPDF (fitz) for PDF-to-image conversion.
    """
    import fitz  # PyMuPDF
    import tempfile
    
    doc = fitz.open(pdf_path)
    all_text_parts = []
    all_blocks = []
    
    for page_num in range(len(doc)):
        page = doc.load_page(page_num)
        
        # Render page to image at 300 DPI for good OCR quality
        mat = fitz.Matrix(300 / 72, 300 / 72)  # 300 DPI
        pix = page.get_pixmap(matrix=mat)
        
        # Save to temporary file
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            pix.save(tmp.name)
            tmp_path = tmp.name
        
        try:
            # Run OCR on the page image
            page_result = ocr_engine.extract_text(tmp_path, lang=lang, engine=engine)
            
            page_text = page_result.get("text", "").strip()
            if page_text:
                all_text_parts.append(f"--- Page {page_num + 1} ---\n{page_text}")
            
            # Offset block positions aren't meaningful across pages, but include them
            for block in page_result.get("blocks", []):
                block["page"] = page_num + 1
                all_blocks.append(block)
        finally:
            # Clean up temp file
            try:
                os.remove(tmp_path)
            except Exception:
                pass
    
    doc.close()
    
    return {
        "text": "\n\n".join(all_text_parts) if all_text_parts else "No text found in PDF.",
        "blocks": all_blocks
    }

