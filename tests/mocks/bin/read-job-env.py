#!/usr/bin/env python3
import json
import sys

dump = json.load(sys.stdin)

builds_dir = dump["builds_dir"]
print(f"export CUSTOM_ENV_CI_BUILDS_DIR={builds_dir}")

if "job_env" in dump:
    jobenv = dump["job_env"]
    for name, value in jobenv.items():
        print(f"export {name}={value}")
