from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database.session import Base

class Document(Base):
    """
    Database model for scanned documents.
    Tracks file paths, OCR results, lineage (crops), and processing status.
    """
    __tablename__ = "documents"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    filename = Column(String, index=True)
    mime_type = Column(String)
    
    # File Paths
    original_path = Column(String)
    base_processed_path = Column(String, nullable=True)  # Clean, un-filtered base image
    processed_path = Column(String, nullable=True)       # Final image with filters applied
    
    # Metadata & Lineage
    parent_document_id = Column(Integer, ForeignKey("documents.id"), nullable=True)
    ocr_text = Column(Text, nullable=True)
    document_type = Column(String, default="typed")     # typed, handwritten, other
    
    # Status: uploaded, processing, completed, failed
    status = Column(String, default="uploaded")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner = relationship("User", back_populates="documents")

# Update User model to include relationship
