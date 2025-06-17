#!/usr/bin/env python3

# find line with minimizer_sum_computation
import re
import sys

SIMD_MINIMIZER_SPEED_TAG: str = "simd_minimizers_100000000/minimizer_canonical_sum/100000000"
HARDCODED_COUNT_FOR_ANALYSIS: int = 0



def get_speed(fasta_file: str):
    search_througput: bool = False
    
    with open(fasta_file, 'r') as f:
        for line in f:
            if SIMD_MINIMIZER_SPEED_TAG in line:
                search_througput = True
                continue
                # try:
                #     next(f)  # Skip 
                #     throughput_line = next(f)
                # except StopIteration:
                #     break  # End of file reached
            if search_througput:
                match = re.search(r'thrpt:\s*\[\d+\.\d+\s+\S+\s+(\d+\.\d+)\s+\S+\s+\d+\.\d+\s+\S+\]', line)
                if match:
                    middle_value = float(match.group(1))
                    print(f"{middle_value}\t{HARDCODED_COUNT_FOR_ANALYSIS}")
                    break
if __name__ == "__main__":
    get_speed(sys.argv[1])