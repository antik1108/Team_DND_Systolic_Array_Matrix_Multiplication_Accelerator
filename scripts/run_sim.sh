#!/usr/bin/env bash
# Run every testbench with Icarus Verilog. Usage: ./scripts/run_sim.sh
set -e
cd "$(dirname "$0")/.."
mkdir -p sim/waves sim/build
RTL="rtl/mac_unit.v rtl/pe.v rtl/input_buffer.v rtl/skew_buffer.v rtl/systolic_array.v rtl/output_buffer.v rtl/systolic_controller.v rtl/systolic_top.v rtl/sequential_matmul.v"
IV="iverilog -g2012 -Wall"

echo "### MAC unit";      $IV -o sim/build/mac  -s tb_mac_unit      $RTL tb/tb_mac_unit.v      && vvp -n sim/build/mac  | tee sim/log_mac_unit.txt
echo "### PE";            $IV -o sim/build/pe   -s tb_pe            $RTL tb/tb_pe.v            && vvp -n sim/build/pe   | tee sim/log_pe.txt
for N in 3 4; do
  echo "### Systolic top N=$N"
  $IV -P tb_systolic_top.N=$N -P tb_systolic_top.DUMP=$([ $N = 4 ] && echo 1 || echo 0) \
      -o sim/build/top$N -s tb_systolic_top $RTL tb/tb_systolic_top.v
  vvp -n sim/build/top$N | tee sim/log_systolic_top_N$N.txt
done
echo "### Systolic top N=4, pipelined MAC (PIPE=1)"
$IV -P tb_systolic_top.N=4 -P tb_systolic_top.PIPE=1 -P tb_systolic_top.DUMP=0 -o sim/build/top4p -s tb_systolic_top $RTL tb/tb_systolic_top.v
vvp -n sim/build/top4p | tee sim/log_systolic_top_N4_pipe.txt
echo "### Systolic vs sequential sweep"
: > sim/perf_sweep.txt
for N in 2 3 4 5 6 8; do
  $IV -P tb_compare.N=$N -o sim/build/cmp$N -s tb_compare $RTL tb/tb_compare.v
  vvp -n sim/build/cmp$N | tee -a sim/perf_sweep.txt
  $IV -P tb_compare.N=$N -P tb_compare.PIPE=1 -o sim/build/cmp${N}p -s tb_compare $RTL tb/tb_compare.v
  vvp -n sim/build/cmp${N}p | sed 's/^PERF /PERFPIPE /' | tee -a sim/perf_sweep.txt
done
echo; echo "### SUMMARY"; grep -h "RESULT:" sim/log_*.txt sim/perf_sweep.txt
echo "### Basys-3 demo wrapper"
$IV -o sim/build/fpga -s tb_fpga_demo $RTL fpga/basys3_demo_top.v tb/tb_fpga_demo.v && vvp -n sim/build/fpga | tee sim/log_fpga_demo.txt
