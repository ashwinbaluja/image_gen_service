import json
import boto3
import os
import base64

sagemaker = boto3.client('sagemaker-runtime')
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

EMBEDDINGS_TABLE = os.environ['EMBEDDINGS_TABLE']
SAGEMAKER_ENDPOINT = os.environ['SAGEMAKER_ENDPOINT']
BUCKET_NAME = os.environ['BUCKET_NAME']

def lambda_handler(event, context):
    try:

        embedding_id = event['pathParameters']['embedding_id']

        embeddings_table = dynamodb.Table(EMBEDDINGS_TABLE)
        response = embeddings_table.get_item(
            Key={'embedding_id': embedding_id}
        )

        if 'Item' in response:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'embedding_id': embedding_id,
                    'embedding': response['Item']['embedding'],
                    'source': 'cache'
                })
            }

        images_table = dynamodb.Table('Images')
        image_response = images_table.get_item(
            Key={'image_id': embedding_id}
        )

        if 'Item' not in image_response:
            return {
                'statusCode': 404,
                'body': json.dumps({
                    'error': 'Image not found'
                })
            }

        s3_key = image_response['Item']['s3_key']

        s3_response = s3.get_object(
            Bucket=BUCKET_NAME,
            Key=s3_key
        )
        image_data = s3_response['Body'].read()

        image_base64 = base64.b64encode(image_data).decode('utf-8')

        sagemaker_response = sagemaker.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT,
            ContentType='application/json',
            Body=json.dumps({
                'type': 'image',
                'data': image_base64
            })
        )

        response_body = json.loads(sagemaker_response['Body'].read().decode())
        embedding = response_body['embedding']

        embeddings_table.put_item(
            Item={
                'embedding_id': embedding_id,
                'embedding': embedding,
                'created_at': image_response['Item'].get('created_at', '')
            }
        )

        return {
            'statusCode': 200,
            'body': json.dumps({
                'embedding_id': embedding_id,
                'embedding': embedding,
                'source': 'generated'
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
