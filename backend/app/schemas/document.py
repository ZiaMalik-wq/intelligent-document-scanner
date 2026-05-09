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
    processed_path: Optional[str] = None
    ocr_text: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}

class Document(DocumentInDBBase):
    pass
