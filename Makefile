
-include ~/.makefilehelp

.PHONY: init_folders extract_frames colmap_pipeline openmvg_openmvs_pipeline clean build_and_test

init_folders:
	mkdir -p data/videos data/frames data/colmap data/openmvg data/openmvs data/outputs
	touch data/videos/.gitkeep
	touch data/frames/.gitkeep
	touch data/colmap/.gitkeep
	touch data/openmvg/.gitkeep
	touch data/openmvs/.gitkeep
	touch data/outputs/.gitkeep

extract_frames:
	poetry run python scripts/cli.py extract data/videos/DJI_0136.MP4 --fps 1

colmap_pipeline:
	poetry run python scripts/cli.py run-colmap

openmvg_openmvs_pipeline:
	poetry run python scripts/cli.py run-openmvg-openmvs

clean:
	rm -rf data/frames/*
	rm -rf data/colmap/*
	rm -rf data/openmvg/*
	rm -rf data/openmvs/*
	rm -rf data/outputs/*


build_and_test:
	cd docker && docker compose build
	cd docker && docker compose run --rm colmap nvidia-smi
	cd docker && docker compose run --rm openmvg nvidia-smi
	cd docker && docker compose run --rm openmvs nvidia-smi
