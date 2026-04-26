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
            modelId='us.anthropic.claude-sonnet-4-6',
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
    brand_voice = tenant_record.get('brandVoice', '')
    coach_name = tenant_record.get('coachName', 'the coach')

    prompt = f"""You are a LinkedIn ghostwriter for {coach_name}, an executive coach in 2026.

Their coaching methodology: {methodology}

Their brand voice and writing style: {brand_voice}

Write one LinkedIn post in {coach_name}'s voice, optimized for the 2026 LinkedIn algorithm and mobile reading.

STRICT FORMATTING RULES:
- Open with a hook that is 3 to 5 words on its own line
- Each sentence gets its own line
- One blank line between each thought or idea
- Never write more than 2 sentences together without a blank line
- Total post length 150 to 180 words
- End with one short reflective question on its own line
- No hashtags
- No emojis
- No bullet points
- No em dashes ever, use plain words instead

CONTENT RULES:
- Open with a short punchy hook that stops the scroll
- Draw from Alan's concepts like Performance Theology, identity vs behavior, worth vs value
- Make it feel like a practitioner sharing real lived experience
- Never mention coaching services or a call to action
- Sound like a thoughtful peer not a marketer
- Use short punchy sentences like Alan does in his real posts

FORMAT EXAMPLE:
I watched a CEO do something rare.

He said "I was wrong" in front of his board.

The room shifted immediately.

Defenses dropped.

Real conversation started.

Most leaders spend years learning to appear certain.

They defend decisions instead of examining them.

The executives I see grow fastest treat being wrong as data, not failure.

Authority is not diminished by admitting error.

It is reinforced by it.

What would change if you said "I was wrong" more often than you defended being right?

Write only the post text formatted exactly like the example above. Nothing else."""

    return generate_with_bedrock(prompt)


def generate_first_comment(post_draft, tenant_record):
    methodology = tenant_record.get('methodology', 'executive coaching')
    brand_voice = tenant_record.get('brandVoice', '')
    coach_name = tenant_record.get('coachName', 'the coach')

    prompt = f"""You are a LinkedIn ghostwriter for {coach_name}, an executive coach in 2026.

Their coaching methodology: {methodology}

Their brand voice: {brand_voice}

{coach_name} just published this LinkedIn post:
---
{post_draft}
---

Write a first comment that {coach_name} will post on their own post within 60 minutes of publishing.

This comment should:
- Add a personal story or vulnerable truth that did not fit in the post
- Be 2 to 4 sentences maximum
- Deepen the post rather than repeat it
- Feel like an afterthought that is actually the most important thing
- Draw from Alan's personal history with Performance Theology and growing up in a high-control environment
- End with nothing salesy
- No em dashes ever
- Sound completely human and unscripted

Write only the comment text, nothing else."""

    return generate_with_bedrock(prompt)


def generate_comment_draft(post_text, target_name, target_title, methodology, tenant_record={}):
    brand_voice = tenant_record.get('brandVoice', '')
    coach_name = tenant_record.get('coachName', 'the coach')

    prompt = f"""You are a LinkedIn ghostwriter for {coach_name}, an executive coach in 2026.

Their coaching methodology: {methodology}

Their brand voice: {brand_voice}

A target executive named {target_name}, {target_title}, just posted this on LinkedIn:
---
{post_text[:500]}
---

Write a genuine comment in {coach_name}'s voice that:
- Is 2 to 3 sentences maximum
- Adds a specific insight that connects to Alan's work around Performance Theology, identity, or self-worth
- Sounds like a peer practitioner who has lived this work, not a vendor
- Does not mention coaching services or a call to action
- Does not use phrases like "great post" or "love this"
- No em dashes ever
- Feels like it came from someone who has genuinely lived and worked through these issues

Write only the comment text, nothing else."""

    return generate_with_bedrock(prompt)


def build_comments_block(comments):
    if not comments:
        return "<p>No comments generated today.</p>"

    blocks = []
    for i, comment in enumerate(comments, 1):
        post_url = comment.get('postLinkedinUrl', '#')
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
      <a href="{post_url}" target="_blank"
         style="display:inline-block;margin-bottom:12px;padding:8px 16px;background:#0a66c2;color:white;text-decoration:none;border-radius:4px;font-size:11px;font-weight:600;letter-spacing:0.05em;">
        Open Post on LinkedIn
      </a>
      <p class="comment-draft">{comment['commentDraft']}</p>
    </div>"""
        blocks.append(block)

    return '\n'.join(blocks)


def send_digest_email(post_draft, first_comment, comments, template):
    today = datetime.now(timezone.utc).strftime('%A, %B %-d, %Y')
    comments_block = build_comments_block(comments)

    post_html = (post_draft or 'No post generated today.') \
        .replace('&', '&amp;') \
        .replace('<', '&lt;') \
        .replace('>', '&gt;') \
        .replace('\n\n', '</p><p>') \
        .replace('\n', '<br>')
    post_html = f'<p>{post_html}</p>'

    first_comment_html = (first_comment or '') \
        .replace('&', '&amp;') \
        .replace('<', '&lt;') \
        .replace('>', '&gt;') \
        .replace('\n\n', '</p><p>') \
        .replace('\n', '<br>')
    first_comment_html = f'<p>{first_comment_html}</p>'

    html_body = template \
        .replace('{{DATE}}', today) \
        .replace('{{POST_DRAFT}}', post_html) \
        .replace('{{FIRST_COMMENT}}', first_comment_html) \
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

        first_comment = generate_first_comment(post_draft, tenant_record) if post_draft else None
        logger.info("First comment generated")

        pending_posts = table.query(
            KeyConditionExpression=boto3.dynamodb.conditions.Key('PK').eq(
                f'TENANT#{TENANT_ID}'
            ) & boto3.dynamodb.conditions.Key('SK').begins_with('POSTQUEUE#'),
            FilterExpression=boto3.dynamodb.conditions.Attr('status').eq('PENDING')
        )

        comments = []
        for post_item in pending_posts.get('Items', [])[:5]:
            post_text = post_item.get('postText', '')
            target_name = post_item.get('targetName', '')
            target_title = post_item.get('targetTitle', '')

            comment_draft = generate_comment_draft(
                post_text, target_name, target_title, methodology, tenant_record
            )

            if comment_draft:
                comments.append({
                    'targetName': target_name,
                    'targetTitle': target_title,
                    'postPreview': post_text[:200] + '...' if len(post_text) > 200 else post_text,
                    'commentDraft': comment_draft,
                    'postLinkedinUrl': post_item.get('postLinkedinUrl', '#')
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
        sent = send_digest_email(post_draft, first_comment, comments, template)

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