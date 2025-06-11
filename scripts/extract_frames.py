import os
import subprocess
from pathlib import Path

def extract_frames(video_path, output_dir, fps):
    os.makedirs(output_dir, exist_ok=True)
    video_name = Path(video_path).stem
    output_template = os.path.join(output_dir, f"{video_name}_frame_%05d.png")
    cmd = [
        "ffmpeg",
        "-i", video_path,
        "-vf", f"fps={fps}",
        output_template
    ]
    print(f"Running: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)

def extract_frames_from_folder(video_dir, output_dir, fps):
    video_dir = Path(video_dir)
    for video_file in video_dir.glob("*.MP4"):
        print(f"Extracting frames from {video_file}")
        extract_frames(str(video_file), output_dir, fps)
