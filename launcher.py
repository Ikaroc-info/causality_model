#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
VENV_DIR = ROOT_DIR / "venv"
IS_WINDOWS = os.name == "nt"


def log(message: str) -> None:
    print(f"[launcher] {message}")


def run(command: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    pretty = " ".join(command)
    log(f"$ {pretty}")
    subprocess.run(command, cwd=str(cwd or ROOT_DIR), env=env, check=True)


def venv_python_path() -> Path:
    if IS_WINDOWS:
        return VENV_DIR / "Scripts" / "python.exe"
    return VENV_DIR / "bin" / "python"


def ensure_venv_and_reexec(disable_venv: bool) -> None:
    if disable_venv:
        return

    target_python = venv_python_path()
    current_python = Path(sys.executable).resolve()

    if not target_python.exists():
        log("Creating virtual environment...")
        run([sys.executable, "-m", "venv", str(VENV_DIR)])

    if current_python != target_python.resolve():
        log("Switching to project virtual environment...")
        env = os.environ.copy()
        env["AC_LAUNCHER_REEXEC"] = "1"
        process = subprocess.run(
            [str(target_python), str(ROOT_DIR / "launcher.py"), *sys.argv[1:]],
            cwd=str(ROOT_DIR),
            env=env,
        )
        raise SystemExit(process.returncode)


def install_python_dependencies(skip_python_deps: bool) -> None:
    if skip_python_deps:
        log("Skipping Python dependency installation.")
        return

    requirements = ROOT_DIR / "requirements.txt"
    if not requirements.exists():
        log("No requirements.txt found, skipping Python dependency installation.")
        return

    log("Installing/updating Python dependencies...")
    run([sys.executable, "-m", "pip", "install", "--upgrade", "pip"])
    run([sys.executable, "-m", "pip", "install", "-r", str(requirements)])


def ensure_frontend(skip_frontend: bool, rebuild_frontend: bool) -> None:
    if skip_frontend:
        log("Skipping frontend build.")
        return

    dist_index = ROOT_DIR / "dist" / "index.html"
    node_modules = ROOT_DIR / "node_modules"

    if dist_index.exists() and not rebuild_frontend:
        log("Frontend already built (dist/index.html found).")
        return

    npm = shutil.which("npm")
    if not npm:
        raise RuntimeError(
            "npm was not found. Install Node.js from https://nodejs.org/ and retry, "
            "or run with --skip-frontend if dist/ is already available."
        )

    if not node_modules.exists():
        log("Installing frontend dependencies...")
        run([npm, "install"])

    log("Building frontend...")
    run([npm, "run", "build"])


def launch_server() -> None:
    server_file = ROOT_DIR / "server.py"
    if not server_file.exists():
        raise FileNotFoundError("server.py not found in project root")

    log("Starting server...")
    run([sys.executable, str(server_file)])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Cross-platform launcher for Antigravity Causal"
    )
    parser.add_argument(
        "--no-venv",
        action="store_true",
        help="Run with current Python interpreter instead of ./venv",
    )
    parser.add_argument(
        "--skip-python-deps",
        action="store_true",
        help="Skip `pip install -r requirements.txt`",
    )
    parser.add_argument(
        "--skip-frontend",
        action="store_true",
        help="Skip frontend build step",
    )
    parser.add_argument(
        "--rebuild-frontend",
        action="store_true",
        help="Force rebuild of frontend even if dist/ already exists",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    ensure_venv_and_reexec(disable_venv=args.no_venv)
    install_python_dependencies(skip_python_deps=args.skip_python_deps)
    ensure_frontend(skip_frontend=args.skip_frontend, rebuild_frontend=args.rebuild_frontend)
    launch_server()


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        log(f"Command failed with exit code {exc.returncode}")
        raise SystemExit(exc.returncode)
    except Exception as exc:
        log(f"Error: {exc}")
        raise SystemExit(1)
