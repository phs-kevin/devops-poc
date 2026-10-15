#!/bin/bash
# Deploys one image tag to one host: take it out of the target group, run
# /opt/shn/run.sh over SSM, put it back once healthy.
# Usage: deploy_host.sh <instance-id> <image-tag>
# Env: TARGET_GROUP_ARN; AUTO_ROLLBACK=true|false (default false)
set -euo pipefail
ID=$1
TAG=$2
TG=$TARGET_GROUP_ARN
ROLLBACK=${AUTO_ROLLBACK:-false}

# The tag ends up in a shell command on the host; workflow_dispatch makes it user input.
[[ $TAG =~ ^[A-Za-z0-9._-]+$ ]] || { echo "::error::invalid tag '$TAG'"; exit 1; }
[[ $ROLLBACK =~ ^(true|false)$ ]] || { echo "::error::AUTO_ROLLBACK must be true or false"; exit 1; }

echo "$ID: draining"
aws elbv2 deregister-targets --target-group-arn "$TG" --targets Id="$ID"
aws elbv2 wait target-deregistered --target-group-arn "$TG" --targets Id="$ID"

echo "$ID: deploying $TAG (auto-rollback: $ROLLBACK)"
CMD=$(aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --comment "deploy $TAG" --timeout-seconds 60 \
  --parameters "{\"commands\":[\"/opt/shn/run.sh $TAG $ROLLBACK\"],\"executionTimeout\":[\"600\"]}" \
  --query Command.CommandId --output text)

# Poll rather than `aws ssm wait command-executed`, which gives up after ~100s
# and doesn't tell a rollback (exit 2) apart from a plain failure.
invocation() {
  aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" --query "$1" --output text
}
for _ in $(seq 1 130); do
  STATUS=$(invocation Status 2>/dev/null || echo Pending)
  case $STATUS in Pending|InProgress|Delayed) sleep 5 ;; *) break ;; esac
done
RC=$(invocation ResponseCode)
invocation StandardOutputContent
invocation StandardErrorContent >&2

case $RC in
  0) ;;
  2) echo "::warning::$ID: $TAG failed; auto-rollback restored the previous tag" ;;
  *) echo "::error::$ID: deploy of $TAG failed (status $STATUS, exit $RC); host left out of the target group"
     exit 1 ;;
esac

echo "$ID: back in service"
aws elbv2 register-targets --target-group-arn "$TG" --targets Id="$ID"
aws elbv2 wait target-in-service --target-group-arn "$TG" --targets Id="$ID"
[ "$RC" = 0 ] || exit 1  # rolled back: host serves the old tag, but the deploy failed
