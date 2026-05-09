from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.database.session import get_db
from app.models.document import Document
from app.cv.edge_detection import detect_document_corners
from app.cv.perspective import four_point_transform
from app.cv.enhancement import enhance_image
from app.schemas.scanner import PerspectiveRequest
from app.core.config import settings
import cv2
import os

router = APIRouter()

@router.post("/detect-edges/{document_id}")
async def detect_edges(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    document_id: int,
) -> Any:
    """
    Detect document edges and return 4 corner coordinates.
    """
    document = db.query(Document).filter(Document.id == document_id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # If it's a PDF, we skip edge detection and return full-page corners
    if document.mime_type == "application/pdf":
        return {
            "document_id": document_id,
            "message": "PDF detected. Edge detection skipped.",
            "corners": [
                {"x": 0.0, "y": 0.0},
                {"x": 1.0, "y": 0.0},
                {"x": 1.0, "y": 1.0},
                {"x": 0.0, "y": 1.0}
            ]
        }
    
    try:
        corners = detect_document_corners(document.original_path)
        return {
            "document_id": document_id,
            "corners": [
                {"x": float(c[0]), "y": float(c[1])} for c in corners
            ]
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Edge detection failed: {e}"
        )

@router.post("/correct-perspective/{document_id}")
async def correct_perspective(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    document_id: int,
    request: PerspectiveRequest,
) -> Any:
    """
    Apply perspective correction and save the flattened image.
    """
    document = db.query(Document).filter(Document.id == document_id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    try:
        # Convert Pydantic points to list
        pts = [[p.x, p.y] for p in request.corners]
        
        # Transform image
        warped = four_point_transform(document.original_path, pts)
        
        # Save processed image
        processed_filename = f"processed_{os.path.basename(document.original_path)}"
        processed_path = os.path.join(settings.PROCESSED_DIR, processed_filename)
        cv2.imwrite(processed_path, warped, [int(cv2.IMWRITE_JPEG_QUALITY), 100])
        
        # Update database
        document.processed_path = processed_path
        document.status = "processed"
        db.commit()
        db.refresh(document)
        
        return {
            "document_id": document_id,
            "processed_path": processed_path,
            "status": "processed"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Perspective correction failed: {e}"
        )

@router.post("/enhance/{document_id}")
async def enhance(
    *,
    db: Session = Depends(get_db),
    current_user = Depends(deps.get_current_user),
    document_id: int,
    mode: str = "magic",
) -> Any:
    """
    Apply image enhancement filters (magic, grayscale, bw, receipt).
    """
    document = db.query(Document).filter(Document.id == document_id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Logic: Always try to use the 'processed' (flattened) image as the base for enhancement.
    # If the document is currently 'enhanced', we need to find the base 'processed' image.
    if document.status == "enhanced":
        # Look for the 'processed_' prefix version which is our baseline from Phase 5
        # or simply use the original if no processed version exists.
        input_path = document.original_path
        # But wait, we want the FLATTENED one. 
        # Let's check if a processed version exists in the filename
        base_dir = settings.PROCESSED_DIR
        for f in os.listdir(base_dir):
            if f.startswith("processed_") and os.path.basename(document.original_path) in f:
                input_path = os.path.join(base_dir, f)
                break
    else:
        input_path = document.processed_path if document.processed_path else document.original_path
    
    try:
        enhanced = enhance_image(input_path, mode)
        
        # Save enhanced image
        enhanced_filename = f"enhanced_{mode}_{os.path.basename(input_path)}"
        enhanced_path = os.path.join(settings.PROCESSED_DIR, enhanced_filename)
        cv2.imwrite(enhanced_path, enhanced, [int(cv2.IMWRITE_JPEG_QUALITY), 100])
        
        # Update database
        document.processed_path = enhanced_path
        document.status = "enhanced"
        db.commit()
        db.refresh(document)
        
        return {
            "document_id": document_id,
            "enhanced_path": enhanced_path,
            "mode": mode,
            "status": "enhanced"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Enhancement failed: {e}"
        )
