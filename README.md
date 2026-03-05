# causality_model

## Launch everything with one Python script

From the project root, run (shortest command):

```bash
python run.py
```

Equivalent command:

```bash
python launcher.py
```

What it does:
- Creates and uses `./venv` automatically (Linux/Windows)
- Installs Python dependencies from `requirements.txt`
- Builds the frontend (`npm install` + `npm run build`) if `dist/` is missing
- Starts `server.py`

Useful options:
- `python launcher.py --skip-frontend`
- `python launcher.py --rebuild-frontend`
- `python launcher.py --skip-python-deps`
- `python launcher.py --no-venv`

On Windows, you can still double-click `launcher.bat`, which now delegates to `launcher.py`.