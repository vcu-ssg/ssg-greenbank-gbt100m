
-include ~/.makefilehelp

.PHONY: init-folders extract-frames colmap-pipeline openmvg-openmvs-pipeline clean build-and-test



init-folders:
	mkdir -p data/videos data/frames data/colmap data/openmvg data/openmvs data/outputs
	touch data/videos/.gitkeep
	touch data/frames/.gitkeep
	touch data/colmap/.gitkeep
	touch data/openmvg/.gitkeep
	touch data/openmvs/.gitkeep
	touch data/outputs/.gitkeep

FPS = 0.50
RATIO = 0.70
ENGINE = INCREMENTAL

video_folder = data/videos
frame_folder = data/frames
extract_options = --fps=$(FPS) --threads=16 --quality=2 --skip=5 --output-dir=$(frame_folder)

extract-frames.title = Extract frames from one or more videos.
extract-frames:
	poetry run python scripts/cli.py extract-frames $(video_folder)/DJI_0142.MP4 $(extract_options)

colmap-pipeline:
	poetry run python scripts/cli.py run-colmap

openmvg-openmvs-pipeline:
	poetry run python scripts/cli.py run-openmvg-openmvs \
		--sfm-engine=$(ENGINE) \
		--matches-ratio=$(RATIO) \
		--enable-texturing

clean-frames:
	rm -rf data/frames/*

clean:
	rm -rf data/colmap/*
	rm -rf data/openmvg/*
	rm -rf data/openmvs/*
	rm -rf data/outputs/*
	rm -rf data/visuals/*


build-and-test:
	cd docker && docker compose build
	cd docker && docker compose run --rm colmap nvidia-smi
	cd docker && docker compose run --rm openmvg nvidia-smi
	cd docker && docker compose run --rm openmvs nvidia-smi

init-nvidia-configuration:
	sudo mkdir -p /etc/nvidia-container-runtime
	sudo touch /etc/nvidia-container-runtime/config.toml

# Generate pair graph and plot as graph.png
# Generate pair graph and plot as graph.png using openmvg service
graph-check:
	@echo "👉 Running [openMVG_main_PairGenerator] ..."
	docker compose -f ./docker/docker-compose.yml run --rm --user 1000:1000 openmvg \
		openMVG_main_PairGenerator \
		-i /workspace/sfm_data.json \
		-m /workspace/matches \
		-o /workspace/matches/matches.f.txt

	@echo "👉 Converting matches.g.txt → matches.dot ..."
	python scripts/cli.py convert-matches-g \
		--input ./data/openmvg/matches/matches.f.txt \
		--output ./data/openmvg/matches/matches.dot

	@echo "👉 Creating graph PNG with neato ..."
	neato -Tpng ./data/openmvg/matches/matches.dot \
		-o ./data/openmvg/matches/matches.png


	python scripts/cli.py analyze-graph ./data/openmvg/matches/matches.f.txt --show-disconnected

	python scripts/cli.py analyze-graph ./data/openmvg/matches/matches.e.txt --show-disconnected


	@echo "✅ Graph visualization complete: ./data/openmvg/matches/matches.png"
