import cv2
import numpy as np

def enhance_image(image_path: str, mode: str):
    """
    Enhances the document image based on the selected mode.
    Modes: original, grayscale, bw, magic, receipt
    """
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError("Could not read image")

    if mode == "grayscale":
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        # Add a little contrast boost for grayscale scans
        return cv2.convertScaleAbs(gray, alpha=1.1, beta=0)
    
    elif mode == "bw":
        # For colored text (like red), standard grayscale can be too light.
        # We'll take the minimum of all channels to ensure colored text stays dark.
        gray = np.min(image, axis=2)
        
        # Adaptive thresholding with a larger block size and higher constant
        return cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
            cv2.THRESH_BINARY, 31, 15
        )
    
    elif mode == "magic":
        # Magic Color: Denoise + Sharpness + Contrast
        # 1. Denoise (optional, can be slow)
        # image = cv2.fastNlMeansDenoisingColored(image, None, 10, 10, 7, 21)
        
        # 2. Sharpen
        kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
        sharpened = cv2.filter2D(image, -1, kernel)
        
        # 3. Brightness/Contrast
        alpha = 1.3 # Contrast
        beta = 5   # Brightness
        return cv2.convertScaleAbs(sharpened, alpha=alpha, beta=beta)

    elif mode == "receipt":
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        # Very high contrast mean thresholding to force faded text to black
        return cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C, 
            cv2.THRESH_BINARY, 31, 20
        )

    return image
