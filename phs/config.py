"""Default configuration. All values are placeholders; real values come from
environment variables or AWS Secrets Manager (see configure_app)."""

AWS_REGION = "us-east-1"
AWS_SECRET_ID = None  # e.g. shn/prod/app, passed to the container as an env var

SECRET_KEY = "placeholder"
DB_PASSWORD = "placeholder"
API_TOKEN = "placeholder"
