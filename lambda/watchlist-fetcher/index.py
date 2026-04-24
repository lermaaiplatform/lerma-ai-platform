import json
import boto3
import os
import logging
import urllib.request
import urllib.parse
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
secretsmanager = boto3.client('secretsmanager')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE')
TENANT_ID = os.environ.get('TENANT_ID')
SECRET_NAME = os.environ.get('PROXYCURL_SECRET_NAME')

APIFY_ACTOR_ID = 'harvestapi/linkedin-post-search'

SEARCH_TOPICS = [
    "leadership burnout executives",
    "performance pressure high performers",
    "success feels empty leaders",
    "identity worth executives",
    "high performers struggling internally"
]



def get_apify_token():
    response = secretsmanager.get_secret_value(SecretId=SECRET_NAME)
    return response['SecretString']


def run_apify_actor(token):
    url = f"https://api.apify.com/v2/acts/harvestapi~linkedin-post-search/runs?token={token}"

    payload = {
        "searchQueries": SEARCH_TOPICS,
        "maxPosts": 5,
        "postedLimit": "week",
        "sortBy": "date",
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST'
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode())
            return result.get('data', {}).get('id')
    except Exception as e:
        logger.error(f"Error starting Apify actor: {str(e)}")
        return None


def get_apify_results(run_id, token):
    url = f"https://api.apify.com/v2/actor-runs/{run_id}/dataset/items?token={token}"

    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        logger.error(f"Error fetching Apify results: {str(e)}")
        return []


def wait_for_run(run_id, token, max_attempts=10):
    import time
    url = f"https://api.apify.com/v2/actor-runs/{run_id}?token={token}"

    for attempt in range(max_attempts):
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                result = json.loads(response.read().decode())
                status = result.get('data', {}).get('status')
                logger.info(f"Run status: {status} (attempt {attempt + 1})")
                if status == 'SUCCEEDED':
                    return True
                elif status in ['FAILED', 'ABORTED', 'TIMED-OUT']:
                    logger.error(f"Run failed with status: {status}")
                    return False
                time.sleep(6)
        except Exception as e:
            logger.error(f"Error checking run status: {str(e)}")
            time.sleep(6)

    return False


def handler(event, context):
    logger.info(f"Watchlist fetcher triggered for tenant: {TENANT_ID}")

    try:
        token = get_apify_token()
        table = dynamodb.Table(TABLE_NAME)

        logger.info(f"Searching LinkedIn posts for {len(SEARCH_TOPICS)} topics")

        run_id = run_apify_actor(token)
        if not run_id:
            logger.error("Failed to start Apify actor")
            return {'statusCode': 500, 'body': json.dumps({'message': 'Failed to start Apify actor'})}

        logger.info(f"Apify run started: {run_id}")

        success = wait_for_run(run_id, token)
        if not success:
            logger.error("Apify run did not complete successfully")
            return {'statusCode': 500, 'body': json.dumps({'message': 'Apify run failed'})}

        posts = get_apify_results(run_id, token)
        logger.info(f"Retrieved {len(posts)} posts from Apify")

        posts_stored = 0
        for post in posts:
            post_text = post.get('content', '')
            if not post_text or len(post_text) < 50:
                continue

            author = post.get('author', {})
            author_name = author.get('name', 'Unknown')
            author_info = author.get('info', '')
            linkedin_url = author.get('linkedinUrl', '')
            post_id = str(post.get('id', ''))
            post_linkedin_url = post.get('linkedinUrl', '')

            table.put_item(Item={
                'PK': f"TENANT#{TENANT_ID}",
                'SK': f"POSTQUEUE#{post_id}",
                'tenantId': TENANT_ID,
                'targetName': author_name,
                'targetTitle': author_info,
                'targetCompany': '',
                'linkedinUrl': linkedin_url,
                'postLinkedinUrl': post_linkedin_url,
                'postText': post_text,
                'postId': post_id,
                'status': 'PENDING',
                'fetchedAt': datetime.now(timezone.utc).isoformat()
            })
            posts_stored += 1

        logger.info(f"Stored {posts_stored} posts in PostQueue")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Watchlist fetch completed',
                'tenantId': TENANT_ID,
                'topicsSearched': len(SEARCH_TOPICS),
                'postsStored': posts_stored
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