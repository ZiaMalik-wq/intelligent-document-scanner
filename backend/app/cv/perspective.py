import cv2
import numpy as np
from app.cv.utils import order_points

def four_point_transform(image_path: str, pts: list):
    """
    Performs a perspective transform to 'flatten' the document.
    pts: list of 4 corners [[x,y], [x,y], [x,y], [x,y]]
    """
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError("Could not read image")

    rect = order_points(np.array(pts, dtype="float32"))
    (tl, tr, br, bl) = rect

    # Compute the width of the new image
    width_a = np.sqrt(((br[0] - bl[0]) ** 2) + ((br[1] - bl[1]) ** 2))
    width_b = np.sqrt(((tr[0] - tl[0]) ** 2) + ((tr[1] - tl[1]) ** 2))
    max_width = max(int(width_a), int(width_b))

    # Compute the height of the new image
    height_a = np.sqrt(((tr[0] - br[0]) ** 2) + ((tr[1] - br[1]) ** 2))
    height_b = np.sqrt(((tl[0] - bl[0]) ** 2) + ((tl[1] - bl[1]) ** 2))
    max_height = max(int(height_a), int(height_b))

    # Construct the set of destination points to get a "birds eye view"
    dst = np.array([
        [0, 0],
        [max_width - 1, 0],
        [max_width - 1, max_height - 1],
        [0, max_height - 1]], dtype="float32")

    # Compute the perspective transform matrix and then apply it
    M = cv2.getPerspectiveTransform(rect, dst)
    warped = cv2.warpPerspective(image, M, (max_width, max_height))

    return warped
