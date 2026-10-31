#!/bin/sh
# подсчет кодового покрытия в Verilator: sh run_coverage.sh
SRC="$(pwd)"
WORK="$HOME/lab2_cov"
rm -rf "$WORK" "$SRC/annotated" "$SRC/coverage.dat"
mkdir -p "$WORK"
cp apb_master.sv apb_and_acc.sv tb_top.sv sim_main.cpp cov_summary.py "$WORK"
cd "$WORK"
# 1) сборка модели с покрытием
verilator --cc --exe --build --timing --coverage -Wno-fatal -Wno-lint -Wno-style -Wno-INITIALDLY \
    --top-module tb_top apb_master.sv apb_and_acc.sv tb_top.sv sim_main.cpp -o sim > build.log 2>&1 \
    || { cat build.log; exit 1; }
# 2) запуск теста (покрытие сохраняется в coverage.dat)
./obj_dir/sim
# 3) исходники с количеством выполнений каждой строки (непокрытые строки помечены %000000)
verilator_coverage --annotate annotated --annotate-min 1 coverage.dat
# 4) итог в процентах по каждому файлу
python3 cov_summary.py coverage.dat
# результаты - обратно в папку проекта
cp -r annotated coverage.dat "$SRC"