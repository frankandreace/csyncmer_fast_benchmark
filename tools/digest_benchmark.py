#!/usr/bin/env python3

# import 
import time
import argparse
from digest import syncmer

# sequence loader working also when the sequence is split into multiple lines
def load_sequence(fasta_file: str):
    sequence: list = []
    with open(fasta_file, 'r') as f:
        for line in f:
            if not line.startswith('>'):
                sequence.append(line.strip())

        return ''.join(sequence)

def benchmark(fasta_path: str, output_path: str, k: int = 31, w: int = 15):
    sequence = load_sequence(fasta_path)
    sequence_size_in_MB = len(sequence) / (1024 ** 2)

    start_time = time.time()
    syncmer_positions: list = syncmer(sequence, k=k, w=w)

    elapsed_time = time.time() - start_time

    speed_MB_sec = sequence_size_in_MB / elapsed_time

    num_syncmer_computed: int = len(syncmer_positions)

    with open(output_path, 'w') as outf:
        print(f'{speed_MB_sec:.3f}\t{num_syncmer_computed}', file=outf)



if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input_fasta", type=str, help="input fasta file", required=True)
    parser.add_argument("-o", "--output", type=str, help="output benchmark tsv", required=True)
    parser.add_argument("-k", "--kmer_size", type=int, help="k-mer length", default=31)
    parser.add_argument("-w", "--window_size", type=int, help="window size", default=15)
    args = parser.parse_args()

    benchmark(args.input_fasta, args.output, args.kmer_size, args.window_size)

