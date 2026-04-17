import json
import boto3
import os
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
bedrock = boto3.client('bedrock-runtime')
ses = boto3.client('ses')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE')
FROM_EMAIL = os.environ.get('FROM_EMAIL')
NOTIFY_EMAIL = os.environ.get('NOTIFY_EMAIL')
TENANT_ID = os.environ.get('TENANT_ID')


def handler(event, context):
    """
    Intake Handler Lambda
    Receives prospect form submissions via API Gateway
    Writes prospect to DynamoDB
    Scores prospect via Bedrock
    Sends draft follow-up email via SES
    """
    logger.info(f"Intake event received: {json.dumps(event)}")

    try:
        # Parse incoming prospect data
        body = json.loads(event.get('body', '{}'))
        prospect_id = f"prospect-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"

        # Write prospect to DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        table.put_item(Item={
            'PK': f"TENANT#{TENANT_ID}",
            'SK': f"PROSPECT#{prospect_id}",
            'prospectId': prospect_id,
            'tenantId': TENANT_ID,
            'name': body.get('name', ''),
            'title': body.get('title', ''),
            'company': body.get('company', ''),
            'email': body.get('email', ''),
            'message': body.get('message', ''),
            'source': body.get('source', 'web'),
            'status': 'NEW',
            'createdAt': datetime.now(timezone.utc).isoformat()
        })

        logger.info(f"Prospect {prospect_id} written to DynamoDB")

        # TODO: Add Bedrock scoring after discovery session
        # Score will evaluate prospect fit based on
        # title, company, and message content

        # TODO: Add SES follow-up email after discovery session
        # Email will be drafted by Bedrock using tenant
        # voice and knowledge base context

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Prospect received successfully',
                'prospectId': prospect_id
            })
        }

    except Exception as e:
        logger.error(f"Error processing intake: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Error processing request'
            })
        }