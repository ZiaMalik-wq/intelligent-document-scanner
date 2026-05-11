import os
import pytesseract
from PIL import Image
from app.core.config import settings

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------
if settings.TESSERACT_PATH:
    pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_PATH

def generate_searchable_pdf(image_path: str, output_path: str, lang: str = "eng"):
    """Generates a searchable PDF from an image with an invisible OCR layer."""
    try:
        pdf_data = pytesseract.image_to_pdf_or_hocr(image_path, extension='pdf', lang=lang)
        with open(output_path, 'wb') as f:
            f.write(pdf_data)
        return output_path
    except Exception as e:
        raise Exception(f"PDF generation failed: {e}")

def create_simple_pdf(image_path: str, output_path: str):
    """
    Creates a simple image-only PDF (no OCR layer).
    """
    try:
        image = Image.open(image_path)
        if image.mode == 'RGBA':
            image = image.convert('RGB')
        image.save(output_path, "PDF", resolution=300.0)
        return output_path
    except Exception as e:
        raise Exception(f"Simple PDF generation failed: {e}")

def generate_batch_pdf(image_paths: list[str], output_path: str):
    """Creates a multi-page PDF document from a list of image file paths."""
    if not image_paths:
        raise Exception("No images provided for batch PDF generation.")
        
    try:
        images = []
        for path in image_paths:
            img = Image.open(path)
            if img.mode == 'RGBA':
                img = img.convert('RGB')
            images.append(img)
            
        images[0].save(
            output_path, 
            "PDF", 
            resolution=300.0, 
            save_all=True, 
            append_images=images[1:]
        )
        return output_path
    except Exception as e:
        raise Exception(f"Batch PDF generation failed: {e}")
