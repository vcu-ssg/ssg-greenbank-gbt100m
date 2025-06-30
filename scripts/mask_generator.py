"""
    
"""

import cv2
import numpy as np
from pathlib import Path

def generate_combined_mask(input_image_path, output_mask_path):
    img_bgr = cv2.imread(str(input_image_path))
    img = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)

    # Edge detection
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    edges = cv2.Canny(gray, 50, 150)
    edges_dilated = cv2.dilate(edges, np.ones((3,3), np.uint8), iterations=1)

    # Upward vertical scan to mask ground/horizon
    h, w = edges.shape
    vertical_mask = np.zeros_like(edges_dilated, dtype=np.uint8)
    min_edge_run = 5

    for x in range(w):
        count = 0
        for y in range(h-1, -1, -1):
            if edges_dilated[y, x] > 0:
                count += 1
                if count >= min_edge_run:
                    vertical_mask[:y+1, x] = 255
                    break
            else:
                count = 0

    # Combine masks
    final_mask = cv2.bitwise_and(edges_dilated, vertical_mask)

    # Write output mask
    output_mask_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(output_mask_path), final_mask)
