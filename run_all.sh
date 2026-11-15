#!/usr/bin/env bash
# One-shot reproduction of every result in the report.
# Needs: icarus-verilog, yosys, tectonic (brew install icarus-verilog yosys tectonic)
#        python venv:  python3 -m venv .venv && .venv/bin/pip install numpy matplotlib yowasp-nextpnr-ecp5
set -e
cd "$(dirname "$0")"
./scripts/run_sim.sh                                   # all testbenches + VCDs
.venv/bin/python scripts/verify_results.py sim/matmul_log_N3.txt sim/matmul_log_N4.txt
./scripts/run_synth.sh                                 # Yosys + nextpnr reports
.venv/bin/python scripts/analyze.py                    # tables + plots
.venv/bin/python scripts/plot_waveform.py              # waveform figure
(cd report && tectonic -X compile main.tex)            # IEEE report PDF
cp report/main.pdf DnD_Systolic_Array_Report.pdf
echo "All done -> DnD_Systolic_Array_Report.pdf"
