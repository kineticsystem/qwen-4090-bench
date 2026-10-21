#!/usr/bin/env python3
"""Append the GPU's temperature, power, load and fan to a file every 5 seconds (NVML)."""
import sys, time, pynvml as n
n.nvmlInit(); h = n.nvmlDeviceGetHandleByIndex(0)
while True:
    with open(sys.argv[1], "w") as f:
        f.write(f"{n.nvmlDeviceGetTemperature(h, 0)} {n.nvmlDeviceGetPowerUsage(h) // 1000} "
                f"{n.nvmlDeviceGetUtilizationRates(h).gpu} {n.nvmlDeviceGetFanSpeed(h)}\n")
    time.sleep(5)
