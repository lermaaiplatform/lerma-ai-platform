import json
import boto3
import os
import logging
import urllib.request
import urllib.error
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
secretsmanager = boto3.client('secretsmanager')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE')
TENANT_ID = os.environ.get('TENANT_ID')
SECRET_NAME = os.environ.get('PROXYCURL_SECRET_NAME')


def get_proxycurl_api_key():
    response = secretsmanager.get_secret_value(SecretId=SECRET_NAME)
    return response['SecretString']


def fetch_linkedin_posts(linkedin_url, api_key):
    endpoint = f"https://nubela.co/proxycurl/api/v2/linkedin/person/recent-activity/posts/?linkedin_profile_url={urllib.parse.quote(linkedin_url)}&pagination_token=&reposts=include"
    req = urllib.request.Request(
        endpoint,
        headers={'Authorization': f'Bearer {api_key}'}
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        logger.error(f"Proxycurl API error: {e.code} for {linkedin_url}")
        return None
    except Exception as e:
        logger.error(f"Error fetching posts for {linkedin_url}: {str(e)}")
        return None


def handler(event, context):
    """
    Watchlist Fetcher Lambda
    Reads target executives from DynamoDB watchlist
    Fetches their recent LinkedIn posts via Proxycurl
    Stores posts in DynamoDB PostQueue for Bedrock to process
    """
    logger.info(f"Watchlist fetcher triggered for tenant: {TENANT_ID}")

    try:
        api_key = get_proxycurl_api_key()
        table = dynamodb.Table(TABLE_NAME)

        # Read watchlist from DynamoDB
        response = table.query(
            KeyConditionExpression=boto3.dynamodb.conditions.Key('PK').eq(
                f"TENANT#{TENANT_ID}"
            ) & boto3.dynamodb.conditions.Key('SK').begins_with('WATCHLIST#')
        )

        watchlist = response.get('Items', [])
        logger.info(f"Found {len(watchlist)} targets in watchlist")

        posts_fetched = 0

        for target in watchlist:
            linkedin_url = target.get('linkedinUrl')
            if not linkedin_url:
                continue

            posts_data = fetch_linkedin_posts(linkedin_url, api_key)
            if not posts_data:
                continue

            posts = posts_data.get('posts', [])[:3]

            for post in posts:
                post_id = post.get('urn', str(datetime.now(timezone.utc).timestamp()))
                post_text = post.get('text', '')

                if not post_text:
                    continue

                table.put_item(Item={
                    'PK': f"TENANT#{TENANT_ID}",
                    'SK': f"POSTQUEUE#{post_id}",
                    'tenantId': TENANT_ID,
                    'targetName': target.get('name', ''),
                    'targetTitle': target.get('title', ''),
                    'targetCompany': target.get('company', ''),
                    'linkedinUrl': linkedin_url,
                    'postText': post_text,
                    'postId': post_id,
                    'status': 'PENDING',
                    'fetchedAt': datetime.now(timezone.utc).isoformat()
                })
                posts_fetched += 1

        logger.info(f"Stored {posts_fetched} posts in PostQueue")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Watchlist fetch completed',
                'tenantId': TENANT_ID,
                'targetsProcessed': len(watchlist),
                'postsFetched': posts_fetched
            })
        }

    except Exception as e:
        logger.error(f"Error in watchlist fetcher: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error fetching watchlist posts',
                'error': str(e)
            })
        }