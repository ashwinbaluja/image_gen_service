import json
import boto3
import base64
import uuid
import os
from datetime import datetime

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

BUCKET_NAME = os.environ['BUCKET_NAME']
IMAGES_TABLE = os.environ['IMAGES_TABLE']

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])

        image_data_base64 = body.get('image_data')
        if not image_data_base64:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing image data'
                })
            }

        try:
            if image_data_base64.startswith('data:image'):
                image_data_base64 = image_data_base64.split(',')[1]
            image_data = base64.b64decode(image_data_base64)

        except Exception as e:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': f'Invalid image data: {str(e)}'
                })
            }

        image_id = str(uuid.uuid4())

        s3_key = f"uploads/{image_id}.png"
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
                'prompt': 'uploaded',
                'modified_prompt': 'uploaded',
                's3_key': s3_key,
                'created_at': datetime.now().isoformat(),
                'embedding_id': image_id
            }
        )

        return {
            'statusCode': 200,
            'body': json.dumps({
                'image_id': image_id,
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
