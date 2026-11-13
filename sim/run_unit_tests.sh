#!/usr/bin/env bash
set -euo pipefail

# Execute este script na raiz do repositorio cpu8vhdl.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GHDL="${GHDL:-ghdl}"
BUILD_DIR="build/ghdl-unit-tests"
mkdir -p "$BUILD_DIR"

if ! command -v "$GHDL" >/dev/null 2>&1; then
    echo "Erro: GHDL nao foi encontrado. Instale-o ou defina a variavel GHDL."
    exit 1
fi

# Limpa arquivos de compilacao antigos para evitar usar unidades desatualizadas.
rm -f "$BUILD_DIR"/*

analyze() {
    "$GHDL" -a --std=08 --workdir="$BUILD_DIR" "$1"
}

elaborate_and_run() {
    local tb="$1"
    echo
    echo "========== $tb =========="
    "$GHDL" -e --std=08 --workdir="$BUILD_DIR" "$tb"
    "$GHDL" -r --std=08 --workdir="$BUILD_DIR" "$tb" \
        --vcd="$BUILD_DIR/$tb.vcd"
}

echo "Analisando o pacote, os modulos e os testbenches..."
analyze src/cpu_pkg.vhd
analyze src/cpu/reg_file.vhd
analyze src/cpu/alu.vhd
analyze src/cpu/cpu_datapath.vhd
analyze sim/tb_reg_file_unit.vhd
analyze sim/tb_alu_unit.vhd
analyze sim/tb_cpu_datapath_unit.vhd

elaborate_and_run tb_reg_file_unit
elaborate_and_run tb_alu_unit
elaborate_and_run tb_cpu_datapath_unit

echo
echo "SUCESSO: todos os testbenches terminaram sem falhas."
echo "Arquivos VCD gerados em: $BUILD_DIR/"
echo "Abra, por exemplo: gtkwave $BUILD_DIR/tb_cpu_datapath_unit.vcd"
