#!/usr/bin/env python3
import json
import sys

dump = json.load(sys.stdin)

builds_dir = dump["builds_dir"]
jobenv = dump["job_env"]


print(f"export CUSTOM_ENV_CI_BUILDS_DIR={builds_dir}")
for name, value in jobenv.items():
    print(f"export {name}={value}")
