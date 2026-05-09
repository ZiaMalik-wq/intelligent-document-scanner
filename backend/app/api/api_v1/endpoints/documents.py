import os
import uuid
import shutil
from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session

from app.api import deps
from app.database.session import get_db
from app.models.document import Document
from app.schemas.document import Document as DocumentSchema
from app.core.config import settings
from app.services.pdf_service import generate_searchable_pdf
from fastapi.responses import FileResponse
import os

router = APIRouter()

SUPPORTED_FORMATS = ["image/jpeg", "image/png", "image/webp", "application/pdf", "image/tiff"]
MAX_FILE_SIZE = 20 * 1024 * 1024  # 20MB

@router.get("/", response_model=List[DocumentSchema])
def list_documents(
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    skip: int = 0,
    limit: int = 100,
) -> Any:
    """
    Retrieve all documents for the current user.
    """
    documents = db.query(Document).filter(Document.user_id == current_user.id).order_by(Document.created_at.desc()).offset(skip).limit(limit).all()
    return documents

@router.get("/search", response_model=List[DocumentSchema])
def search_documents(
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    q: str = "",
    skip: int = 0,
    limit: int = 100,
) -> Any:
    """
    Search documents by filename or OCR text.
    """
    query = db.query(Document).filter(Document.user_id == current_user.id)
    if q:
        query = query.filter(
            (Document.filename.ilike(f"%{q}%")) | 
            (Document.ocr_text.ilike(f"%{q}%"))
        )
    return query.order_by(Document.created_at.desc()).offset(skip).limit(limit).all()

@router.post("/upload", response_model=DocumentSchema)
async def upload_document(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    file: UploadFile = File(...),
) -> Any:
    """
    Upload a document.
    """
    # Validate content type
    if file.content_type not in SUPPORTED_FORMATS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File type {file.content_type} not supported. Supported types: {', '.join(SUPPORTED_FORMATS)}"
        )

    # Validate file size (rough check using file header if possible, or after reading)
    # Note: UploadFile.size is available in newer FastAPI versions
    file.file.seek(0, os.SEEK_END)
    file_size = file.file.tell()
    file.file.seek(0)
    
    if file_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File size exceeds 20MB limit."
        )

    # Generate unique filename
    file_ext = os.path.splitext(file.filename)[1]
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(settings.UPLOAD_DIR, unique_filename)

    # Save file
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Could not save file: {e}"
        )

    # Create DB entry
    db_obj = Document(
        user_id=current_user.id,
        filename=file.filename,
        mime_type=file.content_type,
        original_path=file_path,
        status="uploaded"
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    
    return db_obj

@router.get("/{id}", response_model=DocumentSchema)
def get_document(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    id: int,
) -> Any:
    """
    Get document by ID.
    """
    document = db.query(Document).filter(Document.id == id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    return document

@router.delete("/{id}", response_model=DocumentSchema)
def delete_document(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    id: int,
) -> Any:
    """
    Delete a document.
    """
    document = db.query(Document).filter(Document.id == id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Remove physical file
    if os.path.exists(document.original_path):
        os.remove(document.original_path)
    if document.processed_path and os.path.exists(document.processed_path):
        os.remove(document.processed_path)
        
    db.delete(document)
    db.commit()
    return document

@router.get("/{id}/download-pdf")
async def download_pdf(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    id: int,
    lang: str = "eng",
) -> Any:
    """
    Generate and download a searchable PDF of the document.
    """
    document = db.query(Document).filter(Document.id == id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Use the best available version (processed/enhanced)
    input_path = document.processed_path if document.processed_path else document.original_path
    
    # Check if it's already a PDF
    if document.mime_type == "application/pdf":
        return FileResponse(document.original_path, filename=document.filename, media_type="application/pdf")

    pdf_filename = f"{os.path.splitext(os.path.basename(input_path))[0]}.pdf"
    pdf_path = os.path.join(settings.PROCESSED_DIR, pdf_filename)

    try:
        # Generate the PDF if it doesn't exist or we want to re-generate
        generate_searchable_pdf(input_path, pdf_path, lang=lang)
        
        return FileResponse(
            pdf_path, 
            filename=pdf_filename, 
            media_type="application/pdf"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate PDF: {e}"
        )
