"""Visitor counter behind CloudFront.

GET /api/visit     adds one and returns the new count (the page calls this
                   once per browser per day)
GET /api/visitors  returns the count without changing it

The table is provisioned at 1 RCU / 1 WCU, so a flood is throttled by
DynamoDB instead of being billed; throttled calls return 503.
"""

import json
import os

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

TABLE = boto3.client(
    "dynamodb",
    config=Config(
        retries={"max_attempts": 2, "mode": "standard"},
        connect_timeout=1,
        read_timeout=2,
    ),
)
TABLE_NAME = os.environ["TABLE_NAME"]
KEY = {"id": {"S": "site"}}


def respond(status, body):
    return {
        "statusCode": status,
        "headers": {
            "content-type": "application/json",
            "cache-control": "no-store",
        },
        "body": json.dumps(body),
    }


def handler(event, context):
    http = event.get("requestContext", {}).get("http", {})
    if http.get("method") not in ("GET", "HEAD"):
        return respond(405, {"error": "method not allowed"})

    path = event.get("rawPath", "")
    try:
        if path == "/api/visit":
            result = TABLE.update_item(
                TableName=TABLE_NAME,
                Key=KEY,
                UpdateExpression="ADD visits :one",
                ExpressionAttributeValues={":one": {"N": "1"}},
                ReturnValues="UPDATED_NEW",
            )
            return respond(200, {"visits": int(result["Attributes"]["visits"]["N"])})

        if path == "/api/visitors":
            result = TABLE.get_item(TableName=TABLE_NAME, Key=KEY)
            visits = result.get("Item", {}).get("visits", {}).get("N", "0")
            return respond(200, {"visits": int(visits)})
    except ClientError as error:
        code = error.response["Error"]["Code"]
        if code in ("ProvisionedThroughputExceededException", "ThrottlingException"):
            return respond(503, {"error": "busy"})
        raise

    return respond(404, {"error": "not found"})
