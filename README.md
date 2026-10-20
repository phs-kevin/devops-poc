# devops-poc

Sandbox for testing a CI/CD flow: merge to `staging` builds and deploys an image to staging, then a `vX.Y.Z` tag (or GitHub Release) promotes the same image to production one server at a time, with rollback by tag.

This repo holds a small stand-in Flask app. All config values are placeholders; real values come from AWS Secrets Manager.

## Layout

- `phs/` – Flask app. `configure_app()` loads defaults, then env vars, then the Secrets Manager secret named by `AWS_SECRET_ID`.
- `wsgi.py` – gunicorn entry point.
- `Dockerfile` – non-root gunicorn image on port 8000.

## Endpoints

- `GET /health` – liveness check.
- `GET /whoami` – image tag, secret source, and a masked hint of `API_TOKEN`.

## Run locally

```
docker build --build-arg GIT_SHA=$(git rev-parse HEAD) -t shn-site:dev .
docker run --rm -p 8000:8000 shn-site:dev
curl localhost:8000/health
```

Configuration env vars: `AWS_REGION`, `AWS_SECRET_ID`, `IMAGE_TAG`.

## Releasing

1. Merge a PR into `staging`. The `staging` workflow builds `sha-<commit>` and deploys it to staging.
2. When staging looks good, create a `vX.Y.Z` tag on that commit, either:
   - **GitHub Releases:** Releases → Draft a new release → choose a new tag `vX.Y.Z`, target `staging` → Publish.
   - **CLI:** `git checkout master && git merge --ff-only origin/staging && git push`, then `git tag -a vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z`.
3. The `production` workflow checks the tag, waits for approval, tags the staged image `X.Y.Z` (no rebuild), deploys it, then fast-forwards `master` if needed.

**Rollback:** Actions → production → Run workflow → "Use workflow from" → Tags → pick the older `vX.Y.Z`.
