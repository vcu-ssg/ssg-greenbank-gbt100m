# ---------------------------
# Densify options
# ---------------------------

define openmvs-densify-default
	--resolution-level 1 \
	--max-resolution 2400 \
	--min-resolution 800 \
	--iters 4 \
	--geometric-iters 6 \
	--estimate-colors 2 \
	--estimate-normals 2 \
	--number-views 10 \
	--number-views-fuse 2 \
	--fusion-mode 0 \
	--postprocess-dmaps 1 \
	--estimate-roi 2 \
	--crop-to-roi 1 \
	--roi-border 8
endef

define openmvs-densify-fast
	--resolution-level 2 \
	--iters 2 \
	--number-views 6 \
	--number-views-fuse 1
endef

define openmvs-densify-highquality
	--resolution-level 0 \
	--iters 6 \
	--number-views 14 \
	--number-views-fuse 4
endef

# ---------------------------
# ReconstructMesh options
# ---------------------------

define openmvs-mesh-default
	--min-point-distance 0.2 \
	--remove-spurious 20 \
	--remove-spikes 1 \
	--close-holes 8 \
	--smooth 2 \
	--decimate 1 \
	--edge-length 0 \
	--free-space-support 0 \
	--quality-factor 1 \
	--thickness-factor 1 \
	--crop-to-roi 1
endef

define openmvs-mesh-sharp
	--min-point-distance 0.1 \
	--close-holes 4 \
	--smooth 1 \
	--quality-factor 1.5 \
	--thickness-factor 0.8
endef

define openmvs-mesh-fast
	--min-point-distance 0.3 \
	--remove-spurious 10 \
	--close-holes 4 \
	--smooth 1 \
	--decimate 1.5 \
	--edge-length 0 \
	--quality-factor 0.8 \
	--thickness-factor 1 \
	--crop-to-roi 1
endef


# ---------------------------
# RefineMesh options
# ---------------------------

define openmvs-refine-fast
	--resolution-level 2 \
	--close-holes 4 \
	--decimate 1.2 \
	--ensure-edge-size 1 \
	--max-views 6 \
	--regularity-weight 0.3 \
	--scales 1 \
	--scale-step 0.6
endef

define openmvs-refine-default
	--resolution-level 1 \
	--close-holes 8 \
	--decimate 1.0 \
	--ensure-edge-size 1 \
	--max-views 8 \
	--regularity-weight 0.2 \
	--scales 2 \
	--scale-step 0.5
endef

define openmvs-refine-high
	--resolution-level 0 \
	--close-holes 12 \
	--decimate 0.8 \
	--ensure-edge-size 2 \
	--max-views 12 \
	--regularity-weight 0.1 \
	--scales 3 \
	--scale-step 0.4
endef

# ---------------------------
# TextureMesh options
# ---------------------------

define openmvs-texture-default
	--verbosity 3 \
	--export-type glb \
	--decimate 1 \
	--close-holes 8 \
	--resolution-level 0 \
	--min-resolution 640 \
	--outlier-threshold 0.05 \
	--cost-smoothness-ratio 0.1 \
	--virtual-face-images 1 \
	--global-seam-leveling 0 \
	--local-seam-leveling 1 \
	--texture-size-multiple 0 \
	--patch-packing-heuristic 3 \
	--empty-color 16777215 \
	--sharpness-weight 0.5 \
	--max-texture-size 4096
endef

define openmvs-texture-crisp
	--verbosity 3 \
	--export-type glb \
	--resolution-level 0 \
	--min-resolution 1024 \
	--outlier-threshold 0.02 \
	--sharpness-weight 0.8
endef

define openmvs-texture-fast
	--verbosity 3 \
	--export-type glb \
	--resolution-level 1 \
	--min-resolution 512 \
	--outlier-threshold 0.1 \
	--sharpness-weight 0.3 \
	--max-texture-size 2048 \
	--texture-size-multiple 0 \
	--patch-packing-heuristic 2 \
	--global-seam-leveling 0 \
	--local-seam-leveling 0 \
	--empty-color 16777215
endef

# ---------------------------
# Pipeline recipe: openmvs
# ---------------------------

define recipe-openmvs-model
	@echo "==================================================================="; \
	echo "OPENMVS MODEL: $(call ELEM5,$(@),4)"; \
	echo "Target: $(@)"; \
	echo "Depend: $(firstword $(^))"; \
	echo "==================================================================="; \
	mkdir -p $(call MVS_PATH,$(@))/work; \
	chmod -R u+w $(call MVS_PATH,$(@))/work; \
	{ \
	QUALITY_STR="$(openmvs-model-$(call ELEM5,$(@),4))"; \
	if echo "$$QUALITY_STR" | grep -q "densify=highquality"; then DENSIFY_OPTS="$(openmvs-densify-highquality)"; \
	elif echo "$$QUALITY_STR" | grep -q "densify=fast"; then DENSIFY_OPTS="$(openmvs-densify-fast)"; \
	else DENSIFY_OPTS="$(openmvs-densify-default)"; fi; \
	if echo "$$QUALITY_STR" | grep -q "mesh=sharp"; then MESH_OPTS="$(openmvs-mesh-sharp)"; \
	elif echo "$$QUALITY_STR" | grep -q "mesh=fast"; then MESH_OPTS="$(openmvs-mesh-fast)"; \
	else MESH_OPTS="$(openmvs-mesh-default)"; fi; \
	if echo "$$QUALITY_STR" | grep -q "refine=high"; then REFINE_OPTS="$(openmvs-refine-high)"; \
	elif echo "$$QUALITY_STR" | grep -q "refine=fast"; then REFINE_OPTS="$(openmvs-refine-fast)"; \
	else REFINE_OPTS="$(openmvs-refine-default)"; fi; \
	if echo "$$QUALITY_STR" | grep -q "texture=crisp"; then TEXTURE_OPTS="$(openmvs-texture-crisp)"; \
	elif echo "$$QUALITY_STR" | grep -q "texture=fast"; then TEXTURE_OPTS="$(openmvs-texture-fast)"; \
	else TEXTURE_OPTS="$(openmvs-texture-default)"; fi; \
	\
	echo "----------------------------------------------------------------------"; \
	echo "Running InterfaceCOLMAP"; \
	docker compose -f ./docker/docker-compose.yml run --rm --user 1000:1000 openmvs \
	InterfaceCOLMAP \
	-i /$(call MVS_PATH,$(@))/../../colmap/$(call ELEM5,$(@),4) \
	-o /$(call MVS_PATH,$(@))/scene.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--image-folder /$(call MVS_PATH,$(@))/../../../images \
	--max-threads 20 --normalize 0 --force-points 1; \
	\
	echo "----------------------------------------------------------------------"; \
	echo "Running DensifyPointCloud with options: $$DENSIFY_OPTS"; \
	docker compose -f ./docker/docker-compose.yml run --rm --user 1000:1000 openmvs \
	DensifyPointCloud \
	-i /$(call MVS_PATH,$(@))/scene.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 --max-threads 20 $$DENSIFY_OPTS; \
	\
	echo "----------------------------------------------------------------------"; \
	echo "Running ReconstructMesh with options: $$MESH_OPTS"; \
	docker compose -f ./docker/docker-compose.yml run --rm --user 1000:1000 openmvs \
	ReconstructMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 --max-threads 20 $$MESH_OPTS; \
	\
	echo "----------------------------------------------------------------------"; \
	echo "Running RefineMesh with options: $$REFINE_OPTS"; \
	docker compose -f ./docker/docker-compose.yml run --rm --user 1000:1000 openmvs \
	RefineMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 --max-threads 20 $$REFINE_OPTS; \
	\
	echo "----------------------------------------------------------------------"; \
	echo "Running TextureMesh with options: $$TEXTURE_OPTS"; \
	docker compose -f ./docker/docker-compose.yml run --rm --user 1000:1000 openmvs \
	TextureMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_texture.glb \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 --max-threads 20 $$TEXTURE_OPTS; \
	\
	echo "----------------------------------------------------------------------"; \
	echo "Embedding PNG textures into GLB"; \
	docker compose -f ./docker/docker-compose.yml run --rm --user 1000:1000 openmvs \
	sh -c "gltf-transform copy \
		/$(call MVS_PATH,$(@))/scene_dense_mesh_texture.glb \
		/$(call MVS_PATH,$(@))/scene_dense_mesh_texture_embedded.glb"; \
	}; \
	echo "==================================================================="; \
	echo "FINISHED OPENMVS MODEL: $(call ELEM5,$(@),4)"
endef
