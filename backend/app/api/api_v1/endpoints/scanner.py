import os
import cv2
from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.database.session import get_db
from app.models.document import Document
from app.cv.enhancement import enhance_image
from app.core.config import settings

router = APIRouter()

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
    Applies image enhancement filters based on document type.
    Modes: magic, grayscale, bw, receipt.
    Types: typed, handwritten, other.
    """
    document = db.query(Document).filter(Document.id == document_id, Document.user_id == current_user.id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Update document type
    if document_type in ["typed", "handwritten", "other"]:
        document.document_type = document_type
    
    # Priority: parent's base_processed_path > own base_processed_path > original_path
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

        # Save enhanced image using original filename stem as base.
        # For bw/grayscale use PNG to avoid JPEG chroma artifacts around text.
        original_stem = os.path.splitext(os.path.basename(document.original_path))[0]
        if mode in ["bw", "grayscale"]:
            enhanced_filename = f"enhanced_{mode}_{document_type}_{original_stem}.png"
            enhanced_path = os.path.join(settings.PROCESSED_DIR, enhanced_filename)
            cv2.imwrite(enhanced_path, enhanced, [int(cv2.IMWRITE_PNG_COMPRESSION), 3])
        else:
            enhanced_filename = f"enhanced_{mode}_{document_type}_{original_stem}.jpg"
            enhanced_path = os.path.join(settings.PROCESSED_DIR, enhanced_filename)
            cv2.imwrite(enhanced_path, enhanced, [int(cv2.IMWRITE_JPEG_QUALITY), 92])
        
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
