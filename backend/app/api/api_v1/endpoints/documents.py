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
from app.services.pdf_service import generate_searchable_pdf, generate_batch_pdf
from fastapi.responses import FileResponse
from pydantic import BaseModel
import os

class BatchPdfRequest(BaseModel):
    document_ids: List[int]

router = APIRouter()

SUPPORTED_FORMATS = [
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/tiff",
    "image/tif",
    "image/bmp",
    "image/gif",
    "image/heic",
    "image/x-ms-bmp",
    "application/pdf",
]
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
    
    # Add url field to each document
    results = []
    for doc in documents:
        doc_data = DocumentSchema.model_validate(doc).model_dump()
        if doc.processed_path:
            filename = os.path.basename(doc.processed_path)
            doc_data["url"] = f"/media/processed/{filename}"
        else:
            filename = os.path.basename(doc.original_path)
            doc_data["url"] = f"/media/uploads/{filename}"
        results.append(doc_data)
        
    return results

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
    parent_document_id: int = None,
) -> Any:
    """
    Upload a document.
    
    If parent_document_id is provided, this document is treated as a crop of the parent.
    Filters applied to this document will use the parent's base_processed_path if available.
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

    # Validate parent_document_id if provided
    if parent_document_id:
        parent_doc = db.query(Document).filter(
            Document.id == parent_document_id,
            Document.user_id == current_user.id
        ).first()
        if not parent_doc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Parent document not found"
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
        parent_document_id=parent_document_id,
        status="uploaded"
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    
    # Add transient url field for the response
    document_data = DocumentSchema.model_validate(db_obj).model_dump()
    document_data["url"] = f"/media/uploads/{unique_filename}"
    
    return document_data

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
        
    doc_data = DocumentSchema.model_validate(document).model_dump()
    if document.processed_path:
        filename = os.path.basename(document.processed_path)
        doc_data["url"] = f"/media/processed/{filename}"
    else:
        filename = os.path.basename(document.original_path)
        doc_data["url"] = f"/media/uploads/{filename}"
    
    return doc_data

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

@router.post("/batch/pdf")
async def generate_batch_pdf_endpoint(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    request: BatchPdfRequest,
) -> Any:
    """
    Generate and download a single multi-page PDF from a list of document IDs.
    """
    if not request.document_ids:
        raise HTTPException(status_code=400, detail="No document IDs provided")
        
    documents = db.query(Document).filter(
        Document.id.in_(request.document_ids), 
        Document.user_id == current_user.id
    ).all()
    
    if not documents or len(documents) != len(request.document_ids):
        raise HTTPException(status_code=404, detail="One or more documents not found")
        
    # Order documents based on the input list order
    doc_dict = {doc.id: doc for doc in documents}
    ordered_docs = [doc_dict[doc_id] for doc_id in request.document_ids if doc_id in doc_dict]
    
    # Collect paths
    image_paths = []
    for doc in ordered_docs:
        # Use the best available version (processed/enhanced)
        path = doc.processed_path if doc.processed_path else doc.original_path
        if os.path.exists(path):
            image_paths.append(path)
            
    if not image_paths:
        raise HTTPException(status_code=404, detail="No valid images found for the given documents")
        
    pdf_filename = f"batch_{uuid.uuid4().hex[:8]}.pdf"
    pdf_path = os.path.join(settings.PROCESSED_DIR, pdf_filename)

    try:
        generate_batch_pdf(image_paths, pdf_path)
        return {
            "url": f"/media/processed/{pdf_filename}",
            "filename": pdf_filename
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate batch PDF: {e}"
        )
