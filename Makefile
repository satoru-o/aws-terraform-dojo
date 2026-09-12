SHELL := /bin/bash

.DEFAULT_GOAL := help

# katas/配下のお題番号(N)からterraformディレクトリの絶対パスを出力する。
# 例: make kata-dir N=001 -> /home/.../katas/001-provider-init/terraform
.PHONY: kata-dir
kata-dir:
	@if [ -z "$(N)" ]; then \
		echo "Usage: make kata-dir N=001" >&2; \
		exit 1; \
	fi; \
	dir=$$(find "$(CURDIR)/katas" -maxdepth 1 -type d -name "$(N)*" | sort | head -n1); \
	if [ -z "$$dir" ]; then \
		echo "kata '$(N)' に一致するディレクトリが katas/ 配下に見つかりません" >&2; \
		exit 1; \
	fi; \
	if [ ! -d "$$dir/terraform" ]; then \
		echo "$$dir に terraform ディレクトリがありません" >&2; \
		exit 1; \
	fi; \
	echo "$$dir/terraform"

.PHONY: help
help:
	@echo "使い方: d <番号>"
	@echo "例: d 001  # katas/001-provider-init/terraform へ移動"
	@echo ""
	@echo "利用可能なkata:"
	@for dir in $(CURDIR)/katas/*/; do \
		name=$$(basename "$$dir"); \
		num=$${name%%-*}; \
		title=$${name#*-}; \
		printf "  %s  %s\n" "$$num" "$$title"; \
	done
