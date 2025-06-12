# 🛰️ Drone 3D Pipeline — OpenMVG + OpenMVS

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/your/repo/actions)
[![Docker Compose](https://img.shields.io/badge/docker-compose-blue.svg)](https://docs.docker.com/compose/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.13+-brightgreen.svg)](https://www.python.org/)
[![OpenMVG](https://img.shields.io/badge/OpenMVG-tested-green.svg)](https://github.com/openMVG/openMVG)
[![OpenMVS](https://img.shields.io/badge/OpenMVS-tested-green.svg)](https://github.com/cdcseacave/openMVS)


Reconstruct **3D models from drone video** using an optimized Structure-from-Motion (SfM) and Multi-View Stereo (MVS) pipeline.

---

## 🚀 Quickstart

### 1️⃣ Prepare folders

```bash
make init_folders
```

### 2️⃣ Place video(s)

Copy your `.MP4` files into:

```
data/videos/
```

### 3️⃣ Extract frames

```bash
make extract_frames
```

(Default is **1 frame/sec**; configurable in `extract_frames.py`)

### 4️⃣ Run full 3D pipeline

```bash
make openmvg-openmvs-pipeline
```

---

## 📸 Pipeline Steps

### 1️⃣ Extract Frames

```bash
make extract_frames
```

* Runs `extract_frames.py` with `ffmpeg`
* Automatically tags frames with:

  * **Camera model** (from MP4 metadata)
  * **Focal length** (based on DJI model database)

### 2️⃣ Structure from Motion (SfM)

```bash
make openmvg-openmvs-pipeline
```

* **SfMInit\_ImageListing**: prepares scene and EXIF data
* **ComputeFeatures**: detects keypoints
* **ComputeMatches**: feature matching
* **SfM**: reconstruct camera poses & sparse point cloud

### 3️⃣ Multi-View Stereo (MVS)

* **openMVG2openMVS**: converts scene to OpenMVS format
* **DensifyPointCloud**: dense point cloud generation
* **ReconstructMesh**: mesh generation
* **TextureMesh** *(optional)*: textured mesh

---

## 🛠️ Advanced Options

You can override pipeline options:

```bash
make openmvg-openmvs-pipeline sfm_engine=<engine> matches_ratio=<ratio> enable_texturing=<true|false>
```

| Option             | Default  | Allowed values          | Description              |
| ------------------ | -------- | ----------------------- | ------------------------ |
| `sfm_engine`       | `GLOBAL` | `GLOBAL`, `INCREMENTAL` | SfM mode                 |
| `matches_ratio`    | `0.6`    | `0.1` - `1.0`           | Feature match ratio      |
| `enable_texturing` | `true`   | `true`, `false`         | Run final mesh texturing |

### Examples:

Global SfM without texturing:

```bash
make openmvg-openmvs-pipeline enable_texturing=false
```

Incremental SfM with tighter match ratio:

```bash
make openmvg-openmvs-pipeline sfm_engine=INCREMENTAL matches_ratio=0.5
```

---

## 📂 Folder Structure

```text
data/
├── videos/       → input videos (.MP4)
├── frames/       → extracted video frames (.jpg)
├── colmap/       → (unused currently)
├── openmvg/      → OpenMVG outputs
├── openmvs/      → OpenMVS outputs
└── outputs/      → final products
```

---

## 🐳 Docker Notes

* Builds use `./docker/Dockerfile.openmvg` and `Dockerfile.openmvs`
* Compose file: `./docker/docker-compose.yml`
* **Volumes map**:

  * `/images` → `data/frames`
  * `/workspace` → `data/openmvg` and `data/openmvs`

---

## ⚠️ Build Notes

### 🚧 Zscaler warning

If you are behind Zscaler or a corporate MITM proxy:

* **TURN OFF Zscaler** before running:

```bash
docker compose build openmvg
```

Or your build may fail due to certificate errors when cloning submodules (e.g. `osi_clp`).

---

## ❤️ Acknowledgments

* [OpenMVG](https://github.com/openMVG/openMVG)
* [OpenMVS](https://github.com/cdcseacave/openMVS)
* [DJI camera database](https://github.com/openMVG/openMVG/blob/master/src/openMVG/exif/sensor_width_database/sensor_width_camera_database.txt)

---

## ✨ Example Output

👉 Example screenshots / visualizations can go here (optional).

---

## 🚀 Next steps

✅ Integrate **COLMAP** pipeline as alternative
✅ Add **camera pose export**
✅ Add **HTML viewer for 3D results**
✅ Automate frame extraction **FPS tuning**

---

## 📝 Author

John Leonard (with my coding buddy ChatGPT!)
Project: `ssg-greenbank-gbt100m`

