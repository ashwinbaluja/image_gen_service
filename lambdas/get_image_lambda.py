import json
import boto3
import os

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

BUCKET_NAME = os.environ['BUCKET_NAME']
IMAGES_TABLE = os.environ['IMAGES_TABLE']

def lambda_handler(event, context):
    try:
        image_id = event['pathParameters']['image_id']

        images_table = dynamodb.Table(IMAGES_TABLE)
        response = images_table.get_item(
            Key={'image_id': image_id}
        )

        if 'Item' not in response:
            return {
                'statusCode': 404,
                'body': json.dumps({
                    'error': 'Image not found'
                })
            }

        item = response['Item']
        s3_key = item['s3_key']

        image_url = s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': BUCKET_NAME, 'Key': s3_key},
            ExpiresIn=3600
        )

        item['url'] = image_url

        return {
            'statusCode': 200,
            'body': json.dumps(item)
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
