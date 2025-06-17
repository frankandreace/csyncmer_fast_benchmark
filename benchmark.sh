#!/bin/bash
# run_benchmark.sh

# Setup environment
sudo ./setup_benchmark_env.sh

# Run Nextflow pipeline
nextflow run benchmark.nf -profile conda

# Restore normal settings (optional)
sudo cpupower frequency-set -g ondemand
echo on | sudo tee /sys/devices/system/cpu/smt/control
