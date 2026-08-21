.PHONY: help run import opencode

GODOT := godot
GAME_DIR := game

help:
	@echo "DinoMath Run — Godot 4"
	@echo ""
	@echo "Uso: make <comando>"
	@echo ""
	@echo "  run       Executa o jogo no Godot"
	@echo "  import    Pré-importa os recursos do projeto (gera cache)"
	@echo "  opencode  Abre o opencode carregando as variáveis de ambiente"

run:
	$(GODOT) --path $(GAME_DIR)

import:
	$(GODOT) --headless --path $(GAME_DIR) --import

opencode:
	bash -c 'source scripts/load_env.sh && load_env && opencode .'