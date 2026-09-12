SHELL := /bin/bash

.DEFAULT_GOAL := help

# %パターンルールがMakefile自身の再構築対象と誤認されるのを防ぐ。
Makefile: ;

# katas/配下のお題番号(N)からterraformディレクトリの絶対パスを出力する。
# 例: make kata-dir N=001 -> /home/.../katas/001-provider-init/terraform
#     make 001         -> 同上(こちらが簡易記法。番号で始まる未知のターゲットとして解決される)
.PHONY: kata-dir
kata-dir:
	@if [ -z "$(N)" ]; then \
		echo "Usage: make kata-dir N=001" >&2; \
		exit 1; \
	fi; \
	$(MAKE) --no-print-directory $(N)

# 数字で始まる未知のターゲット(例: 001)をkata番号とみなし、kata-dirと同じ解決を行う。
# FORCEに依存させることで、同名ディレクトリが存在してもキャッシュされず毎回再評価する。
.PHONY: FORCE
FORCE:

%: FORCE
	@case "$@" in \
		[0-9]*) ;; \
		*) echo "make: *** '$@' に対するルールがありません。'make help' を参照してください。" >&2; exit 2 ;; \
	esac; \
	dir=$$(find "$(CURDIR)/katas" -maxdepth 1 -type d -name "$@*" | sort | head -n1); \
	if [ -z "$$dir" ]; then \
		echo "kata '$@' に一致するディレクトリが katas/ 配下に見つかりません" >&2; \
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
