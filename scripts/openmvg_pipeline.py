import os
import subprocess

def run_pipeline(frame_dir, openmvg_dir, openmvs_dir):
    os.makedirs(openmvg_dir, exist_ok=True)
    os.makedirs(openmvs_dir, exist_ok=True)

    # Example: SfMInit_ImageListing
    subprocess.run([
        "docker", "run", "--rm",
        "-v", f"{os.path.abspath(frame_dir)}:/images",
        "-v", f"{os.path.abspath(openmvg_dir)}:/workspace",
        "docker-openmvg:latest",
        "openMVG_main_SfMInit_ImageListing",
        "-i", "/images",
        "-o", "/workspace",
        "-d", "/usr/local/share/openMVG/sensor_width_camera_database.txt"
    ], check=True)

    # Example: ComputeFeatures
    subprocess.run([
        "docker", "run", "--rm",
        "-v", f"{os.path.abspath(frame_dir)}:/images",
        "-v", f"{os.path.abspath(openmvg_dir)}:/workspace",
        "docker-openmvg:latest",
        "openMVG_main_ComputeFeatures",
        "-i", "/workspace/sfm_data.json",
        "-o", "/workspace"
    ], check=True)

    # Continue with other OpenMVG + OpenMVS stages as needed.

    print("OpenMVG + OpenMVS pipeline complete!")
