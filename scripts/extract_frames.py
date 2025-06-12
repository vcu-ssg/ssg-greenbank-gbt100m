
import os
import subprocess
from pathlib import Path
import glob

DJI_FOCAL_LENGTHS = {
    "DJI FC3682": {
        "FocalLength": 4.5,  # in mm
        "FocalLengthIn35mmFormat": 24
    },
    # You can add more models here in future.
}

def get_camera_model_from_mp4(video_path):
    """Extract 'Model' from MP4 using exiftool"""
    try:
        result = subprocess.run(
            ["exiftool", "-Model", "-s3", video_path],
            capture_output=True,
            text=True,
            check=True
        )
        model = result.stdout.strip()
        if not model:
            print(f"Warning: No Model tag found in {video_path}")
            return "Unknown"
        print(f"Camera Model: {model}")
        return model
    except subprocess.CalledProcessError as e:
        print(f"Error extracting Model from {video_path}: {e}")
        return "Unknown"

def add_camera_model_to_images(file_list, camera_model):
    """Write EXIF tags (Model, CameraModelName, FocalLength) to specific files only."""
    if not file_list:
        print("No images to tag.")
        return

    # Normalize camera_model to "DJI FCxxxx" format if needed
    if not camera_model.startswith("DJI "):
        camera_model = "DJI " + camera_model

    # Lookup focal length data
    focal_data = DJI_FOCAL_LENGTHS.get(camera_model)
    if not focal_data:
        print(f"Warning: No known focal length for model {camera_model}. Will skip FocalLength tags.")
        focal_tags = []
    else:
        focal_tags = [
            f"-FocalLength={focal_data['FocalLength']}",
            f"-FocalLengthIn35mmFormat={focal_data['FocalLengthIn35mmFormat']}"
        ]

    if ' ' in camera_model:
        make, model = camera_model.split(' ', 1)
    else:
        # Fallback if no space (just in case)
        make = "Unknown"
        model = camera_model
    
    # Build exiftool command
    cmd = [
        "exiftool",
        f"-Model={model}",
        f"-Make={make}",
        *focal_tags,
        "-overwrite_original",
        *file_list
    ]
    print(f"Tagging {len(file_list)} images with Model={camera_model}")
    subprocess.run(cmd, check=True)



def extract_frames_from_file(video_path, output_dir, fps=1, skip_seconds = 5, threads=8, quality=2, capture_seconds=None):
    os.makedirs(output_dir, exist_ok=True)
    """ extract frames from file """
    
    video_name = Path(video_path).stem
    output_template = os.path.join(output_dir, f"{video_name}_frame_%05d.jpg")

    # Step 1: Record existing files before extraction
    existing_files = set(Path(output_dir).glob(f"{video_name}_frame_*.jpg"))
    existing_files = ()

    # Step 2: Run ffmpeg to extract frames
    cmd = [
        "ffmpeg",
        "-threads", str(threads)
        ]
    if capture_seconds:
        cmd.append("-t")
        cmd.append(str(capture_seconds))
    
    cmd.extend( [
        "-ss", str(skip_seconds),
        "-i", video_path,
        "-vf", f"fps={fps},format=yuv420p",
        "-q:v", str(quality),
        output_template ] )
    
    print(f"Running: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)

    # Step 3: Identify newly created files
    all_files = set(Path(output_dir).glob(f"{video_name}_frame_*.jpg"))
    #new_files = sorted(list(all_files - existing_files))
    new_files = all_files

    # Step 4: Get camera model and tag only the new files
    camera_model = get_camera_model_from_mp4(video_path)
    add_camera_model_to_images([str(p) for p in new_files], camera_model)

def extract_frames_from_folder(video_dir, output_dir, fps):
    video_dir = Path(video_dir)
    for video_file in video_dir.glob("*.MP4"):
        print(f"\n=== Extracting frames from {video_file} ===")
        extract_frames_from_file(str(video_file), output_dir, fps)