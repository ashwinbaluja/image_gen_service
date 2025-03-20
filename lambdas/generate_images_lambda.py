from calendar import c
import json
import boto3
from botocore.config import Config
import uuid
import base64
import random
import os
from datetime import datetime

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
bedrock = boto3.client('bedrock-runtime', config=Config(region_name="us-west-2"))

BUCKET_NAME = os.environ['BUCKET_NAME']
IMAGES_TABLE = os.environ['IMAGES_TABLE']

CAMERA_ANGLES = [
    "from above", "from below", "from the side",
    "from a distance", "close-up", "wide angle",
    "telephoto", "fisheye lens", "drone shot"
]

STYLE_MODIFIERS = [
    "oil painting", "watercolor", "sketch", "digital art",
    "photorealistic", "abstract", "minimalist", "surrealist",
    "black and white photograph", "vintage", "cyberpunk",
    "anime style", "cartoon style", "3D render"
]

def lambda_handler(event, context):
    try:
        query_params = event.get('queryStringParameters', {}) or {}
        base_prompt = query_params.get('prompt', 'a beautiful landscape')

        image_ids = []


        camera_angle = random.choice(CAMERA_ANGLES)
        style = random.choice(STYLE_MODIFIERS)

        modified_prompt = f"{base_prompt}, {camera_angle}, {style}"
        image_id = str(uuid.uuid4())

        res = bedrock.invoke_model(
            modelId='amazon.titan-image-generator-v2:0',
            body=json.dumps({
                "taskType": "TEXT_IMAGE",
                "textToImageParams": {
                    "text": modified_prompt,
                },
                "imageGenerationConfig": {
                    "quality": "standard",
                    "numberOfImages": 1,
                    "height": 320,
                    "width": 704,
                    "cfgScale": 8.0,
                }
            })
        )

        response_body = json.loads(res['body'].read())
        image_base64 = response_body['images'][0]

        image_data = base64.b64decode(image_base64)

        s3_key = f"images/{image_id}.png"
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key,
            Body=image_data,
            ContentType='image/png'
        )

        images_table = dynamodb.Table(IMAGES_TABLE)
        images_table.put_item(
            Item={
                'image_id': image_id,
                'prompt': base_prompt,
                'modified_prompt': modified_prompt,
                's3_key': s3_key,
                'created_at': datetime.now().isoformat(),
                'embedding_id': image_id
            }
        )

        return {
            'statusCode': 200,
            'body': json.dumps({
                'base_prompt': base_prompt,
                'modified_prompt': modified_prompt,
                'image_id': image_id
            })
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
