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
    processed_path = Column(String, nullable=True)
    ocr_text = Column(Text, nullable=True)
    status = Column(String, default="uploaded") # uploaded, processing, completed, failed
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner = relationship("User", back_populates="documents")

# Update User model to include relationship
