import cv2
import numpy as np
from skimage.filters import threshold_sauvola


MAX_PROCESSING_SIDE = 1700
MAX_BW_SIDE = 1400


def enhance_image(image_path: str, mode: str, document_type: str = "typed"):

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

    h, w = image.shape[:2]

    longest = max(h, w)

    if longest <= max_side:
        return image

    scale = max_side / float(longest)

    new_w = max(1, int(w * scale))
    new_h = max(1, int(h * scale))

    return cv2.resize(
        image,
        (new_w, new_h),
        interpolation=cv2.INTER_AREA
    )


def _correct_gamma(gray: np.ndarray, gamma: float):

    inv_gamma = 1.0 / gamma

    table = np.array([
        ((i / 255.0) ** inv_gamma) * 255
        for i in range(256)
    ], dtype=np.uint8)

    return cv2.LUT(gray, table)


def _apply_clahe(gray: np.ndarray, clip: float, grid):

    clahe = cv2.createCLAHE(
        clipLimit=clip,
        tileGridSize=grid
    )

    return clahe.apply(gray)


def _remove_shadow(gray: np.ndarray, blur_kernel):
    """
    Estimate background via Gaussian blur and normalize illumination.
    Avoids morphological closing artifacts.
    """
    # Use direct Gaussian blur for cleaner background estimation
    # Blur kernel is typically (35, 35) or (33, 33) which is good
    blur_size = blur_kernel[0] if blur_kernel[0] % 2 == 1 else blur_kernel[0] + 1
    
    background = cv2.GaussianBlur(
        gray.astype(np.float32),
        (blur_size, blur_size),
        0
    )
    background = np.clip(background, 1, None)  # Avoid division by zero
    
    normalized = (gray.astype(np.float32) / background) * 127.0
    normalized = np.clip(normalized, 0, 255).astype(np.uint8)
    
    return normalized


def _color_aware_to_gray(image: np.ndarray) -> np.ndarray:

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

    lab_modified = cv2.merge((darkened_l, a, b_ch))

    bgr_modified = cv2.cvtColor(
        lab_modified,
        cv2.COLOR_LAB2BGR
    )

    return cv2.cvtColor(
        bgr_modified,
        cv2.COLOR_BGR2GRAY
    )


def _remove_small_black_components(binary: np.ndarray, min_area: int):

    if min_area <= 1:
        return binary

    inverted = cv2.bitwise_not(binary)

    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(
        inverted,
        connectivity=8
    )

    cleaned = np.zeros_like(inverted)

    for i in range(1, num_labels):

        area = stats[i, cv2.CC_STAT_AREA]
        w = stats[i, cv2.CC_STAT_WIDTH]
        h = stats[i, cv2.CC_STAT_HEIGHT]

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

    window_size = params["adaptive_block_size"]

    if window_size % 2 == 0:
        window_size += 1

    # Typed docs need higher k to avoid bold text
    if window_size <= 33:
        k = 0.30
    else:
        k = 0.22

    thresh_sauvola = threshold_sauvola(
        enhanced,
        window_size=window_size,
        k=k
    )

    binary = (
        enhanced > thresh_sauvola
    ).astype(np.uint8) * 255

    return binary


# -------------------------------------------------------------------
# GRAYSCALE
# -------------------------------------------------------------------

def _enhance_grayscale(image, params):
    """
    Clean grayscale: simple luminance conversion with light contrast
    enhancement. Visually distinct from magic (which does LAB shadow 
    removal + color preservation).
    """

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Light CLAHE for readability (lower clip than magic's aggressive processing)
    enhanced = _apply_clahe(
        gray,
        clip=1.5,
        grid=(8, 8)
    )

    # Gentle gamma to brighten slightly
    enhanced = _correct_gamma(enhanced, 1.05)

    # Normalize to use full dynamic range
    enhanced = cv2.normalize(
        enhanced,
        enhanced.copy(),
        0,
        255,
        cv2.NORM_MINMAX
    )

    return enhanced



# -------------------------------------------------------------------
# BLACK & WHITE
# -------------------------------------------------------------------

def _enhance_bw(image, params):

    image = _resize_for_processing(image, MAX_BW_SIDE)

    gray = _color_aware_to_gray(image)

    std_dev = float(np.std(gray))

    # ---------------------------------------------------------------
    # SHADOW REMOVAL
    # ---------------------------------------------------------------

    if std_dev > 32:
        normalized = _remove_shadow(
            gray,
            params["blur_kernel"]
        )
    else:
        normalized = gray.copy()

    # ---------------------------------------------------------------
    # DENOISE
    # ---------------------------------------------------------------

    denoised = cv2.fastNlMeansDenoising(
        normalized,
        None,
        h=9,
        templateWindowSize=7,
        searchWindowSize=21
    )

    # ---------------------------------------------------------------
    # CLAHE
    # ---------------------------------------------------------------

    if std_dev < 28:
        clahe_clip = 0.9
    else:
        clahe_clip = params["clahe_clip"]

    enhanced = _apply_clahe(
        denoised,
        clahe_clip,
        params["clahe_grid"]
    )

    # ---------------------------------------------------------------
    # NORMALIZE
    # ---------------------------------------------------------------

    enhanced = cv2.normalize(
        enhanced,
        enhanced.copy(),
        0,
        255,
        cv2.NORM_MINMAX
    )

    # ---------------------------------------------------------------
    # MILD CONTRAST
    # ---------------------------------------------------------------

    if std_dev < 30:
        alpha = 1.05
        beta = -10
    else:
        alpha = 1.08
        beta = -12

    enhanced = cv2.convertScaleAbs(
        enhanced,
        alpha=alpha,
        beta=beta
    )

    # ---------------------------------------------------------------
    # GAMMA
    # ---------------------------------------------------------------

    enhanced = _correct_gamma(
        enhanced,
        params["gamma"]
    )

    # ---------------------------------------------------------------
    # MEDIAN BLUR
    # ---------------------------------------------------------------

    enhanced = cv2.medianBlur(enhanced, 3)

    # ---------------------------------------------------------------
    # THRESHOLD
    # ---------------------------------------------------------------

    thresh = _threshold(
        enhanced,
        params
    )

    # ---------------------------------------------------------------
    # OPEN (REMOVE SMALL NOISE)
    # ---------------------------------------------------------------

    open_kernel = np.ones((2, 2), np.uint8)

    cleaned = cv2.morphologyEx(
        thresh,
        cv2.MORPH_OPEN,
        open_kernel
    )

    # ---------------------------------------------------------------
    # ERODE (THIN TEXT)
    # ---------------------------------------------------------------

    thin_kernel = np.ones((2, 2), np.uint8)

    cleaned = cv2.erode(
        cleaned,
        thin_kernel,
        iterations=1
    )

    # ---------------------------------------------------------------
    # REMOVE SMALL BLACK COMPONENTS
    # ---------------------------------------------------------------

    cleaned = _remove_small_black_components(
        cleaned,
        params["bw_min_component_area"]
    )

    # ---------------------------------------------------------------
    # STRICT BINARY
    # ---------------------------------------------------------------

    _, cleaned = cv2.threshold(
        cleaned,
        127,
        255,
        cv2.THRESH_BINARY
    )

    return cleaned


# -------------------------------------------------------------------
# MAGIC COLOR
# -------------------------------------------------------------------

def _enhance_magic(image, params):

    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)

    l, a, b = cv2.split(lab)

    bg = cv2.GaussianBlur(
        l,
        params["blur_kernel"],
        0
    )

    bg = np.clip(bg, 1, None)

    l_norm = np.clip(
        (l.astype(np.float32) / bg) * 127,
        0,
        255
    ).astype(np.uint8)

    l_clahe = _apply_clahe(
        l_norm,
        params["clahe_clip"],
        params["clahe_grid"]
    )

    merged = cv2.merge((l_clahe, a, b))

    result = cv2.cvtColor(
        merged,
        cv2.COLOR_LAB2BGR
    )

    blurred = cv2.GaussianBlur(
        result,
        (0, 0),
        sigmaX=1.0
    )

    result = cv2.addWeighted(
        result,
        1.2,
        blurred,
        -0.2,
        0
    )

    return result


# -------------------------------------------------------------------
# RECEIPT
# -------------------------------------------------------------------

def _enhance_receipt(image, params):

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    normalized = _remove_shadow(
        gray,
        params["blur_kernel"]
    )

    denoised = cv2.fastNlMeansDenoising(
        normalized,
        None,
        h=8
    )

    enhanced = _apply_clahe(
        denoised,
        1.0,
        params["clahe_grid"]
    )

    enhanced = cv2.normalize(
        enhanced,
        enhanced.copy(),
        0,
        255,
        cv2.NORM_MINMAX
    )

    enhanced = cv2.medianBlur(enhanced, 3)

    thresh = _threshold(
        enhanced,
        params
    )

    kernel = np.ones((2, 2), np.uint8)

    cleaned = cv2.morphologyEx(
        thresh,
        cv2.MORPH_OPEN,
        kernel
    )

    cleaned = cv2.erode(
        cleaned,
        kernel,
        iterations=1
    )

    cleaned = _remove_small_black_components(
        cleaned,
        6
    )

    return cleaned