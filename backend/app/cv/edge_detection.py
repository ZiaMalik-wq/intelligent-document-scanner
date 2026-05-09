import cv2
import numpy as np
from app.cv.utils import order_points

def detect_document_corners(image_path: str):
    """
    Detects the 4 corners of a document in an image.
    """
    # Load image
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError("Could not read image")
        
    orig = image.copy()
    ratio = image.shape[0] / 500.0
    
    # Resize for faster processing
    height, width = image.shape[:2]
    new_height = 500
    new_width = int(width * (new_height / height))
    image = cv2.resize(image, (new_width, new_height))
    
    # Preprocessing
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edged = cv2.Canny(blurred, 75, 200)
    
    # Find contours
    cnts, _ = cv2.findContours(edged.copy(), cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    cnts = sorted(cnts, key=cv2.contourArea, reverse=True)[:5]
    
    screen_cnt = None
    
    # Loop over contours to find the document
    for c in cnts:
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        
        # If our approximated contour has four points, we can assume it's the document
        if len(approx) == 4:
            screen_cnt = approx
            break
            
    # If no 4-point contour found, use the image boundaries as fallback
    if screen_cnt is None:
        # Fallback: full image corners
        screen_cnt = np.array([
            [[0, 0]],
            [[new_width, 0]],
            [[new_width, new_height]],
            [[0, new_height]]
        ])

    # Convert back to original scale
    corners = screen_cnt.reshape(4, 2) * ratio
    ordered_corners = order_points(corners)
    
    return ordered_corners.tolist()
