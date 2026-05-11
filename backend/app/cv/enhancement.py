import cv2
import numpy as np
from skimage.filters import threshold_sauvola


MAX_PROCESSING_SIDE = 2000
MAX_BW_SIDE = 2000


def enhance_image(image_path: str, mode: str, document_type: str = "typed"):
    """
    Main entry point for image enhancement. Dispatches to specific filters
    based on the 'mode' parameter.
    """
    image = cv2.imread(image_path)

    if image is None:
        raise ValueError("Could not read image")

    try:
        if len(image.shape) == 2:
            image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)

        elif len(image.shape) == 3 and image.shape[2] == 4:
            image = cv2.cvtColor(image, cv2.COLOR_BGRA2BGR)

    except Exception:
        pass

    params = _get_enhancement_params(document_type)

    image = _resize_for_processing(image, MAX_PROCESSING_SIDE)

    if mode == "grayscale":
        return _enhance_grayscale(image, params)

    elif mode == "bw":
        return _enhance_bw(image, params)

    elif mode == "magic":
        return _enhance_magic(image, params)

    elif mode == "receipt":
        return _enhance_receipt(image, params)

    return image


# -------------------------------------------------------------------
# PARAMETERS
# -------------------------------------------------------------------
def _get_enhancement_params(document_type: str):
    """Returns a dictionary of tuned parameters for each document type."""
    params = {
        "typed": {
            "clahe_clip": 1.0,
            "clahe_grid": (8, 8),
            "blur_kernel": (61, 61),
            "adaptive_block_size": 31,
            "gamma": 1.02,
            "bw_min_component_area": 18,
        },
        "handwritten": {
            "clahe_clip": 1.3,
            "clahe_grid": (8, 8),
            "blur_kernel": (51, 51),
            "adaptive_block_size": 37,
            "gamma": 0.96,
            "bw_min_component_area": 10,
        },
        "other": {
            "clahe_clip": 1.1,
            "clahe_grid": (8, 8),
            "blur_kernel": (55, 55),
            "adaptive_block_size": 33,
            "gamma": 1.0,
            "bw_min_component_area": 14,
        }
    }
    return params.get(document_type, params["typed"])


# -------------------------------------------------------------------
# UTILITIES
# -------------------------------------------------------------------
def _resize_for_processing(image, max_side: int):
    """Resizes the image if its longest side exceeds max_side while maintaining aspect ratio."""
    h, w = image.shape[:2]
    longest = max(h, w)
    if longest <= max_side:
        return image

    scale = max_side / float(longest)
    new_w = max(1, int(w * scale))
    new_h = max(1, int(h * scale))
    return cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_AREA)


def _correct_gamma(gray: np.ndarray, gamma: float):
    """Applies gamma correction to a grayscale image to adjust mid-tones."""
    inv_gamma = 1.0 / gamma
    table = np.array([((i / 255.0) ** inv_gamma) * 255 for i in range(256)], dtype=np.uint8)
    return cv2.LUT(gray, table)


def _apply_clahe(gray: np.ndarray, clip: float, grid):
    """Applies Contrast Limited Adaptive Histogram Equalization."""
    clahe = cv2.createCLAHE(clipLimit=clip, tileGridSize=grid)
    return clahe.apply(gray)


def _remove_shadow(gray: np.ndarray, blur_kernel):
    """
    Advanced Illumination Normalization:
    Uses morphological dilation followed by a large median blur to estimate 
    the background 'paper' surface. This is much more robust against sharp 
    curls and deep shadows than simple Gaussian blurring.
    """
    # Use a large-scale structuring element to capture the background surface
    # We scale the kernel relative to the blur_kernel parameter
    k_size = max(blur_kernel) // 2
    if k_size % 2 == 0: k_size += 1
    
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (k_size, k_size))
    
    # 1. Estimate background using dilation (spreads the white paper color)
    background = cv2.dilate(gray, kernel)
    
    # 2. Smooth the background estimate to avoid capturing text artifacts
    # Median blur is excellent at preserving the overall illumination while ignoring ink
    background = cv2.medianBlur(background, k_size)
    
    # 3. Normalize the image: push background toward 255 (white)
    # Target 230 to keep some texture but suppress shadows
    normalized = cv2.divide(gray, background, scale=230)
    
    return normalized.astype(np.uint8)


def _color_aware_to_gray(image: np.ndarray) -> np.ndarray:
    """
    Converts BGR to Grayscale while darkening colored pixels (high saturation).
    This helps preserve colored ink/stamps when converting to B&W.
    """
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    _, s, v = cv2.split(hsv)
    color_mask = cv2.bitwise_and(
        cv2.threshold(s, 40, 255, cv2.THRESH_BINARY)[1],
        cv2.threshold(v, 40, 255, cv2.THRESH_BINARY)[1]
    )
    
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l, a, b_ch = cv2.split(lab)
    darkened_l = np.where(
        color_mask > 0,
        np.clip(l.astype(np.float32) * 0.45, 0, 255).astype(np.uint8),
        l
    )
    # Convert modified LAB back to BGR then to Grayscale
    modified_bgr = cv2.cvtColor(cv2.merge((darkened_l, a, b_ch)), cv2.COLOR_LAB2BGR)
    return cv2.cvtColor(modified_bgr, cv2.COLOR_BGR2GRAY)


def _remove_small_black_components(binary: np.ndarray, min_area: int):
    """Filters out small black speckle noise based on area and aspect ratio."""
    if min_area <= 1:
        return binary
    inverted = cv2.bitwise_not(binary)
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(inverted, connectivity=8)
    cleaned = np.zeros_like(inverted)

    for i in range(1, num_labels):
        area = stats[i, cv2.CC_STAT_AREA]
        w, h = stats[i, cv2.CC_STAT_WIDTH], stats[i, cv2.CC_STAT_HEIGHT]
        if area >= min_area:
            cleaned[labels == i] = 255
            continue
        aspect = max(w, h) / max(1, min(w, h))
        fill_ratio = area / float((w * h) + 1)
        if aspect >= 2.5 or fill_ratio < 0.35:
            cleaned[labels == i] = 255
    return cv2.bitwise_not(cleaned)


# -------------------------------------------------------------------
# THRESHOLD
# -------------------------------------------------------------------
def _threshold(enhanced: np.ndarray, params: dict):
    """Applies Sauvola local adaptive thresholding with production-tuned parameters."""
    window_size = params["adaptive_block_size"]
    if window_size % 2 == 0: window_size += 1
    # Smart Tuning: 
    # Small text (typed/small windows) needs a higher k (0.14) to prevent character bleeding.
    # Large text (handwritten/large windows) can handle a lower k (0.10) for bold intensity.
    k = 0.14 if window_size <= 33 else 0.10
    thresh_sauvola = threshold_sauvola(enhanced, window_size=window_size, k=k)
    return (enhanced > thresh_sauvola).astype(np.uint8) * 255


# -------------------------------------------------------------------
# FILTERS
# -------------------------------------------------------------------
def _enhance_grayscale(image, params):
    """Standard Clean Grayscale: Luminance conversion with optimized contrast range."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    enhanced = _apply_clahe(gray, clip=1.5, grid=(8, 8))
    enhanced = _correct_gamma(enhanced, 1.05)
    return cv2.normalize(enhanced, None, 0, 255, cv2.NORM_MINMAX)



# -------------------------------------------------------------------
# BLACK & WHITE
# -------------------------------------------------------------------

def _enhance_bw(image, params):
    """Production-grade B&W: Optimized for both bold intensity and small text legibility."""
    image = _resize_for_processing(image, MAX_BW_SIDE)
    gray = _color_aware_to_gray(image)
    std_dev = float(np.std(gray))
    normalized = _remove_shadow(gray, params["blur_kernel"]) if std_dev > 25 else gray.copy()
    
    # 1. EDGE-PRESERVING SMOOTHING
    denoised = cv2.bilateralFilter(normalized, 9, 75, 75)
    
    # 2. CONTRAST BOOST
    clip = params["clahe_clip"] * 1.5 if std_dev < 35 else params["clahe_clip"]
    enhanced = _apply_clahe(denoised, clip, params["clahe_grid"])
    enhanced = cv2.normalize(enhanced, None, 0, 255, cv2.NORM_MINMAX)
    
    # 3. UNSHARP MASKING (Sharpen edges to prevent "spread" in small text)
    # This is better than 'erode' as it increases local contrast without bloating characters.
    blurred = cv2.GaussianBlur(enhanced, (0, 0), 3)
    enhanced = cv2.addWeighted(enhanced, 1.5, blurred, -0.5, 0)
    
    # 4. DARK MID-TONES
    enhanced = _correct_gamma(enhanced, 0.92)
    
    # 5. BINARIZATION
    thresh = _threshold(enhanced, params)
    
    # 6. MORPHOLOGICAL HEALING
    # Adaptive kernel: 2x2 for small/typed text to prevent bleeding; 3x3 for larger text.
    k_size = 2 if params["adaptive_block_size"] <= 33 else 3
    repair_kernel = np.ones((k_size, k_size), np.uint8)
    cleaned = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, repair_kernel)
    
    # 7. NOISE REMOVAL
    # Remove small specks
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
    cleaned = _remove_small_black_components(cleaned, params["bw_min_component_area"])
    
    _, final = cv2.threshold(cleaned, 127, 255, cv2.THRESH_BINARY)
    return final


# -------------------------------------------------------------------
# MAGIC COLOR
# -------------------------------------------------------------------

def _enhance_magic(image, params):
    """Magic Color: Boosts saturation and clarity while preserving photographic colors."""
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    bg = cv2.GaussianBlur(l, params["blur_kernel"], 0)
    l_norm = np.clip((l.astype(np.float32) / np.clip(bg, 1, None)) * 127, 0, 255).astype(np.uint8)
    l_clahe = _apply_clahe(l_norm, params["clahe_clip"], params["clahe_grid"])
    
    result = cv2.cvtColor(cv2.merge((l_clahe, a, b)), cv2.COLOR_LAB2BGR)
    blurred = cv2.GaussianBlur(result, (0, 0), sigmaX=1.0)
    return cv2.addWeighted(result, 1.2, blurred, -0.2, 0)


def _enhance_receipt(image, params):
    """Receipt filter: Specialized for high-contrast thermal paper with aggressive sharpening."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    normalized = _remove_shadow(gray, params["blur_kernel"])
    denoised = cv2.fastNlMeansDenoising(normalized, None, h=8)
    enhanced = cv2.normalize(_apply_clahe(denoised, 1.0, params["clahe_grid"]), None, 0, 255, cv2.NORM_MINMAX)
    
    thresh = _threshold(cv2.medianBlur(enhanced, 3), params)
    kernel = np.ones((2, 2), np.uint8)
    cleaned = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
    cleaned = cv2.erode(cleaned, kernel, iterations=1)
    return _remove_small_black_components(cleaned, 6)