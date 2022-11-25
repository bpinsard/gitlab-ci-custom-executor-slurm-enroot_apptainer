#!/usr/bin/env python3
import json
import sys

dump = json.load(sys.stdin)

jobenv = dump["job_env"]

for name,value in jobenv.items():
    print(f"export {name}={value}")
