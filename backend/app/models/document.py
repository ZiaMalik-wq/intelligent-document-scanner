from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database.session import Base

class Document(Base):
    __tablename__ = "documents"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    filename = Column(String, index=True)
    mime_type = Column(String)
    original_path = Column(String)
    base_processed_path = Column(String, nullable=True)  # Perspective-corrected base image
    processed_path = Column(String, nullable=True)  # Current image (may have filters applied)
    parent_document_id = Column(Integer, ForeignKey("documents.id"), nullable=True)  # For cropped images
    ocr_text = Column(Text, nullable=True)
    document_type = Column(String, default="typed")  # typed, handwritten, other
    status = Column(String, default="uploaded") # uploaded, processing, completed, failed
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner = relationship("User", back_populates="documents")

# Update User model to include relationship
