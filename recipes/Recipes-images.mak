
define recipe-images-folder
	@echo -------------------------------------------------------------------
	@echo Extracting images: $(call ELEM5,$(@),2)
	@echo -------------------------------------------------------------------
	@if true; then \
	$(poetry-base) extract-frames $(videos-folder)/$(call ELEM3,$(@),2).MP4 \
		--output-dir=$(@) \
		--skip=$(or $($(call ELEM3,$(@),2).skip),0) \
		--tag=$(call ELEM5,$(@),2) \
		--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
		--fps=$(call ELEM4,$(call ELEM3,$(@),3),2) \
		--max_width=$(call ELEM4,$(call ELEM3,$(@),3),3) \
		$(extract-options) ; \
	fi
	@if [ "$(call ELEM4,$(call ELEM3,$(@),3),4)" != "none" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Applying filters: $(call ELEM4,$(call ELEM3,$(@),3),4)"; \
		echo "-------------------------------------------------------------------"; \
	fi
	@if [ "$(call ELEM4,$(call ELEM3,$(@),3),4)" = "color" ]; then \
		$(poetry-base) convert-images \
		--input-folder=$(@) \
		--output-folder=$(@) \
		--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
		--tag=$(call ELEM5,$(@),2) --workers=8 \
		--sharpen="0x1.0" \
		--contrast="5x50%" \
		--no-greyscale ; \
	elif [ "$(call ELEM4,$(call ELEM3,$(@),3),4)" = "greyscale" ]; then \
		$(poetry-base) convert-images \
		--input-folder=$(@) \
		--output-folder=$(@) \
		--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
		--tag=$(call ELEM5,$(@),2) --workers=8 \
		--sharpen="0x1.0" \
		--contrast="5x50%" \
		--greyscale ; \
	fi
endef
