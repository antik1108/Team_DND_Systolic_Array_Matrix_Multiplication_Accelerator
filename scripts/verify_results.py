#!/usr/bin/env python3
"""Independent golden-model check (NumPy) of every matrix product logged by
tb_systolic_top.v.  Usage: python scripts/verify_results.py sim/matmul_log_N4.txt"""
import sys, numpy as np

def parse(path):
    tests, cur = [], None
    for line in open(path):
        tok = line.split()
        if not tok: continue
        if tok[0] == "TEST":
            cur = {"name": " ".join(tok[1:]), "A": [], "B": [], "C": []}; tests.append(cur)
        elif tok[0] in "ABC": cur[tok[0]].append([int(x) for x in tok[1:]])
        elif tok[0] == "CYCLES": cur["cycles"] = int(tok[1])
    return tests

ok_all = True
for path in sys.argv[1:]:
    tests = parse(path); bad = 0
    for t in tests:
        A, B, C = (np.array(t[k], dtype=np.int64) for k in "ABC")
        if not np.array_equal(A @ B, C):
            bad += 1; print(f"  MISMATCH in '{t['name']}'\n{A@B}\n{C}")
    fx = next((t for t in tests if t["name"].startswith("fixed")), None)
    print(f"{path}: {len(tests)} products, {sum(np.array(t['C']).size for t in tests)} elements, "
          f"{bad} mismatches vs NumPy -> {'PASS' if bad == 0 else 'FAIL'}")
    if fx:
        A = np.array(fx["A"]) / 16.0; B = np.array(fx["B"]) / 16.0; C = np.array(fx["C"]) / 256.0
        print(f"  fixed-point Q3.4 check: max |C_hw - A*B (float)| = {np.max(np.abs(C - A @ B)):.3e}")
    ok_all &= bad == 0
sys.exit(0 if ok_all else 1)
