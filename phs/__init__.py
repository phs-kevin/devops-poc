import json
import os

import boto3
from flask import Flask, jsonify, render_template_string

from . import config

# Env vars that override the defaults in config.py
ENV_KEYS = ("AWS_REGION", "AWS_SECRET_ID", "IMAGE_TAG")

INDEX_HTML = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>shn-site</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 3rem auto; padding: 0 1rem; color: #222; }
    code { background: #f2f2f2; padding: 0.1rem 0.3rem; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>shn-site</h1>
  <p>Running image <code>{{ image_tag }}</code>.</p>
  <p><a href="/health">/health</a> &middot; <a href="/whoami">/whoami</a></p>
</body>
</html>
"""


def configure_app(app):
    app.config.from_object(config)
    for key in ENV_KEYS:
        if key in os.environ:
            app.config[key] = os.environ[key]

    # Secrets Manager is loaded last so it wins over every other source.
    secret_id = app.config.get("AWS_SECRET_ID")
    if secret_id:
        sm = boto3.client("secretsmanager", region_name=app.config["AWS_REGION"])
        app.config.update(json.loads(sm.get_secret_value(SecretId=secret_id)["SecretString"]))


def create_app():
    app = Flask(__name__)
    configure_app(app)

    @app.get("/")
    def index():
        return render_template_string(INDEX_HTML, image_tag=app.config.get("IMAGE_TAG", "dev"))

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/whoami")
    def whoami():
        # Never return the secret itself; a fingerprint is enough to prove
        # which value was loaded (and that it changed after rotation).
        token = str(app.config["API_TOKEN"])
        return jsonify(
            image_tag=app.config.get("IMAGE_TAG", "dev"),
            secret_source="secretsmanager" if app.config.get("AWS_SECRET_ID") else "defaults",
            api_token_hint=token[:2] + "***" + token[-2:] if len(token) > 4 else "***",
        )

    return app
