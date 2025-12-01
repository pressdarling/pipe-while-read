# Makefile for pipe-while-read

# Default ZSH_CUSTOM path. Can be overridden from the command line, e.g.:
# make install ZSH_CUSTOM=/path/to/your/zsh_custom
ZSH_CUSTOM ?= $(HOME)/.oh-my-zsh/custom
PLUGIN_NAME = pipe-while-read
PLUGIN_DIR = $(ZSH_CUSTOM)/plugins/$(PLUGIN_NAME)
PLUGIN_FILE = $(PLUGIN_DIR)/$(PLUGIN_NAME).plugin.zsh
SYMLINK_TARGET = $(CURDIR)/pipe-while-read.zsh

.PHONY: install uninstall test help

install:
	@echo "Installing pipe-while-read plugin..."
	@mkdir -p $(PLUGIN_DIR)
	@ln -sf $(SYMLINK_TARGET) $(PLUGIN_FILE)
	@echo "Plugin installed in $(PLUGIN_DIR)"
	@echo "Please add 'pipe-while-read' to the plugins array in your .zshrc file."

uninstall:
	@echo "Uninstalling pipe-while-read plugin..."
	@rm -f $(PLUGIN_FILE)
	@rmdir $(PLUGIN_DIR) 2>/dev/null || true
	@echo "Plugin uninstalled."

test:
	@echo "Running edge case tests..."
	@./test_edge_cases.zsh

help:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  install    Install the plugin for oh-my-zsh"
	@echo "  uninstall  Uninstall the plugin"
	@echo "  test       Run tests"
	@echo "  help       Show this help message"
