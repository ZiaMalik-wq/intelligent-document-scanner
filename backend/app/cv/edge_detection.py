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
    
    # Preprocessing: convert to grayscale and reduce noise
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # Use Canny edge detector and then dilate to close gaps in edges
    edged = cv2.Canny(blurred, 50, 150)
    kernel = np.ones((5, 5), np.uint8)
    edged = cv2.dilate(edged, kernel, iterations=1)

    # Find external contours (prefer outermost shapes) and consider more candidates
    cnts, _ = cv2.findContours(edged.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cnts = sorted(cnts, key=cv2.contourArea, reverse=True)[:10]

    screen_cnt = None

    # Loop over contours to find the document. Try a few approximation epsilons
    for c in cnts:
        peri = cv2.arcLength(c, True)
        for eps in (0.02, 0.04, 0.06):
            approx = cv2.approxPolyDP(c, eps * peri, True)
            if len(approx) == 4:
                screen_cnt = approx
                break
        if screen_cnt is not None:
            break

    # If no 4-point contour found, try a fallback using contour bounding rect with large area
    if screen_cnt is None and len(cnts) > 0:
        # Pick the largest contour and approximate its bounding quad
        c = cnts[0]
        x, y, w, h = cv2.boundingRect(c)
        screen_cnt = np.array([
            [[x, y]],
            [[x + w, y]],
            [[x + w, y + h]],
            [[x, y + h]]
        ])

    # Final fallback: full image corners
    if screen_cnt is None:
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
