#!/bin/bash

echo "Setting up consistent CPU environment for benchmarking..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi

# Disable hyperthreading
echo off > /sys/devices/system/cpu/smt/control
echo "✓ Hyperthreading disabled"

# Set performance governor
sudo cpupower frequency-set --governor powersave -d 2.6GHz -u 2.6GHz
echo "✓ CPU governor set to powersave and 2.6 GHz"

# Disable turbo boost
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
    echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
    echo "✓ Intel Turbo Boost disabled"
elif [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
    echo 0 > /sys/devices/system/cpu/cpufreq/boost
    echo "✓ AMD Turbo Boost disabled"
fi

# Show current settings
echo ""
echo "Current CPU configuration:"
lscpu | grep -E "Thread|CPU MHz|CPU max MHz"
