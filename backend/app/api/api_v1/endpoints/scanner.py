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
        # Set base_processed_path as the foundation image for all filters
        document.base_processed_path = processed_path
        document.processed_path = processed_path
        document.status = "processed"
        db.commit()
        db.refresh(document)
        
        return {
            "document_id": document_id,
            "processed_path": processed_path,
            "url": f"/media/processed/{processed_filename}",
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
    document_type: str = "typed",
) -> Any:
    """
    Apply image enhancement filters (magic, grayscale, bw, receipt) based on document type.
    
    Document Types:
    - typed: For printed/typed documents
    - handwritten: For handwritten documents  
    - other: For mixed content
    
    Filters are always applied to the base processed image to avoid filter-on-filter artifacts.
    """
    document = db.query(Document).filter(Document.id == document_id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Update document type
    if document_type in ["typed", "handwritten", "other"]:
        document.document_type = document_type
    
    # Always apply filters to the base processed image (perspective-corrected)
    # Priority: parent's base_processed_path > own base_processed_path > original_path
    # This prevents filter-on-filter artifacts even when user crops filtered images
    input_path = None
    
    # Check parent document's base_processed_path (for cropped images)
    if document.parent_document_id:
        parent_doc = db.query(Document).filter(
            Document.id == document.parent_document_id,
            Document.user_id == current_user.id
        ).first()
        if parent_doc and parent_doc.base_processed_path and os.path.exists(parent_doc.base_processed_path):
            input_path = parent_doc.base_processed_path
    
    # Fall back to own base_processed_path
    if not input_path and document.base_processed_path and os.path.exists(document.base_processed_path):
        input_path = document.base_processed_path
    
    # Always fall back to original_path, never to processed_path
    if not input_path:
        input_path = document.original_path
    
    try:
        enhanced = enhance_image(input_path, mode, document_type)

        # Ensure enhanced image is uint8 and 3-channel (BGR) so clients render colors correctly.
        try:
            # Normalize and convert dtype if needed
            if enhanced.dtype != 'uint8':
                enhanced = cv2.normalize(enhanced, None, 0, 255, cv2.NORM_MINMAX).astype('uint8')

            # If single-channel (grayscale), convert to BGR to preserve display on clients
            if len(enhanced.shape) == 2 or (len(enhanced.shape) == 3 and enhanced.shape[2] == 1):
                enhanced = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
        except Exception:
            # If conversion fails, fall back to saving as-is
            pass

        # Save enhanced image using original filename as base (strip any filter prefixes)
        # Use the original filename to avoid stacking filter names
        original_basename = os.path.basename(document.original_path)
        enhanced_filename = f"enhanced_{mode}_{document_type}_{original_basename}"
        enhanced_path = os.path.join(settings.PROCESSED_DIR, enhanced_filename)
        cv2.imwrite(enhanced_path, enhanced, [int(cv2.IMWRITE_JPEG_QUALITY), 100])
        
        # Update database
        # processed_path holds the current view, but base_processed_path stays constant
        document.processed_path = enhanced_path
        document.status = "enhanced"
        db.commit()
        db.refresh(document)
        
        return {
            "document_id": document_id,
            "enhanced_path": enhanced_path,
            "url": f"/media/processed/{enhanced_filename}",
            "mode": mode,
            "status": "enhanced"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Enhancement failed: {e}"
        )
