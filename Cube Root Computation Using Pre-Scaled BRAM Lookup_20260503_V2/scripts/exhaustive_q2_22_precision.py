#!/usr/bin/env python3
"""Exhaustive Q2.22 precision verification for cube_root_bram_ultra_3cyc.

The valid input domain is y in [0.5, 4), represented by integer values
0x200000 through 0xFFFFFF in Q2.22. This script parses the RTL BRAM contents
and sweeps every valid fixed-point input.
"""

import math
import re
import time
from pathlib import Path


WIDTH_IN_FRAC = 22
WIDTH_OUT_FRAC = 23
START_VAL = 0x200000
END_VAL_EXCL = 0x1000000


def load_table(rtl_path):
    text = Path(rtl_path).read_text()
    table = [None] * 384
    for idx, value in re.findall(r"bram\[\s*(\d+)\]\s*=\s*24'h([0-9A-Fa-f]+)", text):
        table[int(idx)] = int(value, 16) / float(1 << WIDTH_OUT_FRAC)
    missing = [i for i, v in enumerate(table) if v is None]
    if missing:
        raise RuntimeError(f"Missing BRAM entries: {missing[:8]}")
    return table


def rtl_addr(val):
    if val & 0x800000:
        r = 2
        idx = (val >> 16) & 0x7F
    elif val & 0x400000:
        r = 1
        idx = (val >> 15) & 0x7F
    else:
        r = 0
        idx = (val >> 14) & 0x7F
    return r, r * 128 + idx


def main():
    repo_dir = Path(__file__).resolve().parents[1]
    table = load_table(repo_dir / "rtl" / "cube_root_bram_ultra_3cyc.v")

    max_rel = -1.0
    max_val = 0
    sum_rel = 0.0
    count = 0
    per_range = {r: {"max_rel": -1.0, "max_val": 0, "sum_rel": 0.0, "count": 0} for r in range(3)}

    t0 = time.time()
    for val in range(START_VAL, END_VAL_EXCL):
        y = val / float(1 << WIDTH_IN_FRAC)
        r, addr = rtl_addr(val)
        actual = table[addr]
        ideal = y ** (1.0 / 3.0)
        rel = abs(actual - ideal) / ideal

        count += 1
        sum_rel += rel
        if rel > max_rel:
            max_rel = rel
            max_val = val

        bucket = per_range[r]
        bucket["count"] += 1
        bucket["sum_rel"] += rel
        if rel > bucket["max_rel"]:
            bucket["max_rel"] = rel
            bucket["max_val"] = val

    print("EXHAUSTIVE_Q2_22_RESULTS")
    print(f"entries={len(table)}")
    print(f"points={count}")
    print(f"max_rel_percent={max_rel * 100:.8f}")
    print(f"avg_rel_percent={sum_rel / count * 100:.8f}")
    print(f"effective_bits={-math.log2(max_rel):.8f}")
    print(f"max_input_hex=0x{max_val:06X}")
    print(f"max_input_y={max_val / float(1 << WIDTH_IN_FRAC):.10f}")

    for r in range(3):
        bucket = per_range[r]
        n = bucket["count"]
        mv = bucket["max_val"]
        print(
            f"r={r} points={n} "
            f"max_rel_percent={bucket['max_rel'] * 100:.8f} "
            f"avg_rel_percent={bucket['sum_rel'] / n * 100:.8f} "
            f"max_input_hex=0x{mv:06X} "
            f"max_input_y={mv / float(1 << WIDTH_IN_FRAC):.10f}"
        )

    print(f"elapsed_sec={time.time() - t0:.2f}")


if __name__ == "__main__":
    main()
