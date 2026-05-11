from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class DocumentBase(BaseModel):
    filename: str
    status: str = "uploaded"

class DocumentCreate(DocumentBase):
    pass

class DocumentUpdate(DocumentBase):
    processed_path: Optional[str] = None
    ocr_text: Optional[str] = None
    status: Optional[str] = None

class DocumentInDBBase(DocumentBase):
    id: int
    user_id: int
    original_path: str
    mime_type: Optional[str] = None
    base_processed_path: Optional[str] = None  # Clean, un-filtered base image
    processed_path: Optional[str] = None       # Final image with filters applied
    parent_document_id: Optional[int] = None   # For cropped images
    ocr_text: Optional[str] = None
    document_type: str = "typed"               # typed, handwritten, other
    url: Optional[str] = None                  # Frontend-friendly URL
    created_at: datetime

    model_config = {"from_attributes": True}

class Document(DocumentInDBBase):
    pass
