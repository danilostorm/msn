#!/bin/sh
set -eu
: "${MSN_ADMIN_PASSWORD:?Define MSN_ADMIN_PASSWORD em .env}"
python - <<'PY'
import os
from pathlib import Path
keys = {
 "DB": "sqlite:////data/escargot.sqlite",
 "STATS_DB": "sqlite:////data/stats.sqlite",
 "TARGET_HOST": os.environ.get("MSN_TARGET_HOST", "127.0.0.1"),
 "LOGIN_HOST": os.environ.get("MSN_LOGIN_HOST") or os.environ.get("MSN_TARGET_HOST", "127.0.0.1"),
 "STORAGE_HOST": os.environ.get("MSN_STORAGE_HOST") or os.environ.get("MSN_LOGIN_HOST") or os.environ.get("MSN_TARGET_HOST", "127.0.0.1"),
 "SYSBOARD_PASS": os.environ["MSN_ADMIN_PASSWORD"],
 "SITE_LINK_PASSWORD": os.environ.get("MSN_SITE_PASSWORD") or os.environ["MSN_ADMIN_PASSWORD"],
 "DEBUG": False, "DEBUG_SYSBOARD": False,
 "ENABLE_FRONT_YMSG": False, "ENABLE_FRONT_IRC": False
}
path = Path("/app/settings_local.py")
path.write_text("".join(f"{k} = {v!r}\n" for k,v in keys.items()))
path.chmod(0o600)
PY
if [ ! -f /data/escargot.sqlite ] || [ ! -f /data/stats.sqlite ]; then
  python script/dbcreate.py
fi
exec python run_all.py
