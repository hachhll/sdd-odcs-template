#!/bin/bash

mkdir -p sdd-project-root/.ai-context/rules/00_general
mkdir -p sdd-project-root/.ai-context/rules/01_communication
mkdir -p sdd-project-root/.ai-context/rules/02_configuration
mkdir -p sdd-project-root/.ai-context/rules/03_sources
mkdir -p sdd-project-root/.ai-context/rules/04_transformations
mkdir -p sdd-project-root/.ai-context/rules/05_persistence
mkdir -p sdd-project-root/.ai-context/rules/06_data_contract

mkdir -p sdd-project-root/.ai-context/skills
mkdir -p sdd-project-root/.ai-context/templates

mkdir -p sdd-project-root/rag-repository/schemas
mkdir -p sdd-project-root/rag-repository/history
mkdir -p sdd-project-root/rag-repository/constants

mkdir -p sdd-project-root/requirements
mkdir -p sdd-project-root/contracts

mkdir -p sdd-project-root/infrastructure/mcp-configs
mkdir -p sdd-project-root/infrastructure/deployment

touch sdd-project-root/.gemini.md
touch sdd-project-root/.ai-context/rules/02_configuration/naming_conventions.md

echo "Structure created successfully"
