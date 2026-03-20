import sys
from pathlib import Path


# Allow `import main` from `app/main.py` during unit tests.
REPO_ROOT = Path(__file__).resolve().parents[1]
APP_DIR = REPO_ROOT / "app"
sys.path.insert(0, str(APP_DIR))

