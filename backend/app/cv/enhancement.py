import cv2
import numpy as np


def enhance_image(image_path: str, mode: str, document_type: str = "typed"):
    """
    Enhances the document image based on the selected mode and document type.

    Modes:
    - grayscale
    - bw
    - magic
    - receipt

    Document Types:
    - typed: For printed/typed documents (uses aggressive enhancement)
    - handwritten: For handwritten documents (preserves ink details)
    - other: For mixed content (balanced enhancement)

    Returns:
        np.ndarray
    """

    image = cv2.imread(image_path)

    if image is None:
        raise ValueError("Could not read image")

    # Normalize image channels: ensure 3-channel BGR input
    # Some gallery images (PNG) may include an alpha channel (4 channels)
    # or be single-channel grayscale. Convert those to BGR so downstream
    # processing (cvtColor, CLAHE, etc.) behaves consistently.
    try:
        if len(image.shape) == 2:
            # Grayscale -> BGR
            image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)
        elif len(image.shape) == 3 and image.shape[2] == 4:
            # BGRA -> BGR (drop alpha)
            image = cv2.cvtColor(image, cv2.COLOR_BGRA2BGR)
    except Exception:
        # If conversion fails, continue and let later ops raise informative errors
        pass

    # Get document-specific parameters
    params = _get_enhancement_params(document_type)

    # =========================================================
    # GRAYSCALE
    # =========================================================
    if mode == "grayscale":
        return _enhance_grayscale(image, params)

    # =========================================================
    # BLACK & WHITE (Scanner Style)
    # =========================================================
    elif mode == "bw":
        return _enhance_bw(image, params)

    # =========================================================
    # MAGIC COLOR
    # =========================================================
    elif mode == "magic":
        return _enhance_magic(image, params)

    # =========================================================
    # RECEIPT MODE
    # =========================================================
    elif mode == "receipt":
        return _enhance_receipt(image, params)

    # =========================================================
    # DEFAULT
    # =========================================================
    return image


def _get_enhancement_params(document_type: str):
    """
    Returns enhancement parameters based on document type.
    """
    params = {
        "typed": {
            "denoise_h": 10,
            "denoise_template": 7,
            "denoise_search": 21,
            "clahe_clip": 3.0,
            "clahe_grid": (8, 8),
            "blur_kernel": (35, 35),
            "morph_kernel_size": 2,
            "adaptive_block_size": 11,
            "adaptive_constant": 2,
            "saturation_boost": 1.15,
        },
        "handwritten": {
            "denoise_h": 7,
            "denoise_template": 5,
            "denoise_search": 21,
            "clahe_clip": 2.0,
            "clahe_grid": (8, 8),
            "blur_kernel": (25, 25),
            "morph_kernel_size": 1,
            "adaptive_block_size": 15,
            "adaptive_constant": 5,
            "saturation_boost": 1.05,
        },
        "other": {
            "denoise_h": 8,
            "denoise_template": 6,
            "denoise_search": 21,
            "clahe_clip": 2.5,
            "clahe_grid": (8, 8),
            "blur_kernel": (30, 30),
            "morph_kernel_size": 1,
            "adaptive_block_size": 13,
            "adaptive_constant": 3,
            "saturation_boost": 1.10,
        },
    }
    
    return params.get(document_type, params["typed"])


def _enhance_grayscale(image, params):
    """Grayscale enhancement with document-type specific parameters."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Shadow normalization
    bg = cv2.GaussianBlur(gray, params["blur_kernel"], 0)
    normalized = cv2.divide(gray, bg, scale=255)

    # Contrast enhancement
    clahe = cv2.createCLAHE(
        clipLimit=params["clahe_clip"],
        tileGridSize=params["clahe_grid"]
    )
    enhanced = clahe.apply(normalized)

    return enhanced


def _enhance_bw(image, params):
    """Black & White enhancement with document-type specific parameters."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # 1. Remove shadows / uneven lighting
    bg = cv2.GaussianBlur(gray, params["blur_kernel"], 0)
    normalized = cv2.divide(gray, bg, scale=255)

    # 2. Denoise while preserving edges
    denoised = cv2.fastNlMeansDenoising(
        normalized,
        None,
        params["denoise_h"],
        params["denoise_template"],
        params["denoise_search"]
    )

    # 3. Contrast enhancement
    clahe = cv2.createCLAHE(
        clipLimit=params["clahe_clip"],
        tileGridSize=params["clahe_grid"]
    )
    enhanced = clahe.apply(denoised)

    # 4. Normalize intensities
    enhanced = cv2.normalize(
        enhanced,
        None,
        0,
        255,
        cv2.NORM_MINMAX
    )

    # 5. OTSU threshold
    _, thresh = cv2.threshold(
        enhanced,
        0,
        255,
        cv2.THRESH_BINARY + cv2.THRESH_OTSU
    )

    # 6. Morphology cleanup
    kernel = np.ones((params["morph_kernel_size"], params["morph_kernel_size"]), np.uint8)
    cleaned = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)

    return cleaned


def _enhance_magic(image, params):
    """Magic color enhancement with document-type specific parameters."""
    # Sharpen image
    kernel = np.array([
        [0, -1, 0],
        [-1, 5, -1],
        [0, -1, 0]
    ])
    sharpened = cv2.filter2D(image, -1, kernel)

    # LAB color enhancement
    lab = cv2.cvtColor(sharpened, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)

    clahe = cv2.createCLAHE(
        clipLimit=params["clahe_clip"],
        tileGridSize=params["clahe_grid"]
    )
    cl = clahe.apply(l)

    merged = cv2.merge((cl, a, b))
    enhanced = cv2.cvtColor(merged, cv2.COLOR_LAB2BGR)

    # Saturation boost (document-type specific)
    hsv = cv2.cvtColor(enhanced, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv)
    s = cv2.multiply(s, params["saturation_boost"])
    final = cv2.merge((h, s, v))

    return cv2.cvtColor(final, cv2.COLOR_HSV2BGR)


def _enhance_receipt(image, params):
    """Receipt enhancement with document-type specific parameters."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # 1. Background normalization
    bg = cv2.GaussianBlur(gray, params["blur_kernel"], 0)
    normalized = cv2.divide(gray, bg, scale=255)

    # 2. Denoise
    denoised = cv2.fastNlMeansDenoising(
        normalized,
        None,
        params["denoise_h"] - 2,
        params["denoise_template"],
        params["denoise_search"]
    )

    # 3. Contrast enhancement
    clahe = cv2.createCLAHE(
        clipLimit=params["clahe_clip"],
        tileGridSize=params["clahe_grid"]
    )
    enhanced = clahe.apply(denoised)

    # 4. Adaptive threshold
    thresh = cv2.adaptiveThreshold(
        enhanced,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        params["adaptive_block_size"],
        params["adaptive_constant"]
    )

    # 5. Remove noise
    kernel = np.ones((params["morph_kernel_size"], params["morph_kernel_size"]), np.uint8)
    cleaned = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)

    return cleaned