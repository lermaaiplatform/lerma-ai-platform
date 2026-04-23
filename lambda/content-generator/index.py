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
s3 = boto3.client('s3')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE')
TENANT_ID = os.environ.get('TENANT_ID')
PLATFORM_BUCKET = os.environ.get('PLATFORM_BUCKET')
FROM_EMAIL = os.environ.get('FROM_EMAIL')
NOTIFY_EMAIL = os.environ.get('NOTIFY_EMAIL')
KB_ID = os.environ.get('KNOWLEDGE_BASE_ID', '')

bedrock_agent = boto3.client('bedrock-agent-runtime')


def get_digest_template():
    try:
        response = s3.get_object(
            Bucket=PLATFORM_BUCKET,
            Key=f'coaches/{TENANT_ID}/prompt-templates/digest_template.html'
        )
        return response['Body'].read().decode('utf-8')
    except Exception:
        return get_default_template()


def get_default_template():
    return """
    <html><body>
    <h2>Your LinkedIn Content for {{DATE}}</h2>
    <h3>Today's Post</h3>
    <p>{{POST_DRAFT}}</p>
    <h3>Comments ({{COMMENT_COUNT}} drafts)</h3>
    {{COMMENTS_BLOCK}}
    </body></html>
    """


def generate_with_bedrock(prompt):
    try:
        response = bedrock.invoke_model(
            modelId='anthropic.claude-3-5-sonnet-20241022-v2:0',
            body=json.dumps({
                'anthropic_version': 'bedrock-2023-05-31',
                'max_tokens': 1000,
                'messages': [
                    {'role': 'user', 'content': prompt}
                ]
            }),
            contentType='application/json',
            accept='application/json'
        )
        result = json.loads(response['body'].read())
        return result['content'][0]['text']
    except Exception as e:
        logger.error(f"Bedrock error: {str(e)}")
        return None


def generate_post_draft(tenant_record):
    methodology = tenant_record.get('methodology', 'executive coaching')
    prompt = f"""You are a LinkedIn ghostwriter for an executive coach.
    
Their coaching methodology: {methodology}

Write one LinkedIn post for today. The post should:
- Be 150-200 words
- Share a genuine insight about leadership or executive presence
- End with a subtle call to reflection not a sales pitch
- Sound like a thoughtful practitioner not a marketer
- Use no hashtags
- Use no emojis

Write only the post text, nothing else."""

    return generate_with_bedrock(prompt)


def generate_comment_draft(post_text, target_name, target_title, methodology):
    prompt = f"""You are a LinkedIn ghostwriter for an executive coach.

Their coaching methodology: {methodology}

A target executive just posted this on LinkedIn:
---
{post_text[:500]}
---

Write a genuine, thoughtful comment that:
- Is 2-3 sentences maximum
- Adds real value or a specific insight
- Sounds like a peer practitioner not a vendor
- Does not mention coaching services
- Does not use phrases like "great post" or "love this"
- Feels like it came from a real person who read the post carefully

Write only the comment text, nothing else."""

    return generate_with_bedrock(prompt)


def build_comments_block(comments):
    if not comments:
        return "<p>No comments generated today.</p>"

    blocks = []
    for i, comment in enumerate(comments, 1):
        block = f"""
    <div class="comment-card">
      <div class="comment-target">
        <span class="number-badge">{i}</span>
        <div class="target-info">
          <p class="target-name">{comment['targetName']}</p>
          <p class="target-title">{comment['targetTitle']}</p>
        </div>
      </div>
      <div class="post-preview">{comment['postPreview']}</div>
      <p class="comment-draft">{comment['commentDraft']}</p>
    </div>"""
        blocks.append(block)

    return '\n'.join(blocks)


def send_digest_email(post_draft, comments, template):
    today = datetime.now(timezone.utc).strftime('%A, %B %-d, %Y')
    comments_block = build_comments_block(comments)

    html_body = template \
        .replace('{{DATE}}', today) \
        .replace('{{POST_DRAFT}}', post_draft or 'No post generated today.') \
        .replace('{{COMMENT_COUNT}}', str(len(comments))) \
        .replace('{{COMMENTS_BLOCK}}', comments_block)

    try:
        ses.send_email(
            Source=FROM_EMAIL,
            Destination={'ToAddresses': [NOTIFY_EMAIL]},
            Message={
                'Subject': {
                    'Data': f'Your LinkedIn content for today - {today}'
                },
                'Body': {
                    'Html': {'Data': html_body},
                    'Text': {
                        'Data': f"Today's post:\n\n{post_draft}\n\nComments: {len(comments)} drafts ready."
                    }
                }
            }
        )
        logger.info("Morning digest sent successfully")
        return True
    except Exception as e:
        logger.error(f"SES error: {str(e)}")
        return False


def handler(event, context):
    logger.info(f"Content generator triggered: {json.dumps(event)}")

    table = dynamodb.Table(TABLE_NAME)
    action = event.get('action', 'FULL_DIGEST')

    try:
        tenant_response = table.get_item(
            Key={
                'PK': f'TENANT#{TENANT_ID}',
                'SK': f'PROFILE#{TENANT_ID}'
            }
        )
        tenant_record = tenant_response.get('Item', {})
        methodology = tenant_record.get('methodology', 'executive leadership coaching')

        post_draft = generate_post_draft(tenant_record)
        logger.info("Post draft generated")

        pending_posts = table.query(
            KeyConditionExpression=boto3.dynamodb.conditions.Key('PK').eq(
                f'TENANT#{TENANT_ID}'
            ) & boto3.dynamodb.conditions.Key('SK').begins_with('POSTQUEUE#'),
            FilterExpression=boto3.dynamodb.conditions.Attr('status').eq('PENDING')
        )

        comments = []
        for post_item in pending_posts.get('Items', [])[:3]:
            post_text = post_item.get('postText', '')
            target_name = post_item.get('targetName', '')
            target_title = post_item.get('targetTitle', '')

            comment_draft = generate_comment_draft(
                post_text, target_name, target_title, methodology
            )

            if comment_draft:
                comments.append({
                    'targetName': target_name,
                    'targetTitle': target_title,
                    'postPreview': post_text[:200] + '...' if len(post_text) > 200 else post_text,
                    'commentDraft': comment_draft
                })

                table.update_item(
                    Key={
                        'PK': post_item['PK'],
                        'SK': post_item['SK']
                    },
                    UpdateExpression='SET #s = :s, commentDraft = :c',
                    ExpressionAttributeNames={'#s': 'status'},
                    ExpressionAttributeValues={
                        ':s': 'DRAFTED',
                        ':c': comment_draft
                    }
                )

        logger.info(f"Generated {len(comments)} comment drafts")

        template = get_digest_template()
        sent = send_digest_email(post_draft, comments, template)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Morning digest complete',
                'tenantId': TENANT_ID,
                'postGenerated': post_draft is not None,
                'commentsGenerated': len(comments),
                'emailSent': sent
            })
        }

    except Exception as e:
        logger.error(f"Content generator error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error generating content',
                'error': str(e)
            })
        }