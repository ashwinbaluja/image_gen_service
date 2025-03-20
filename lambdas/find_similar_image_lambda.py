import json
import boto3
from boto3.dynamodb.conditions import Key
import os
import numpy as np

sagemaker = boto3.client('sagemaker-runtime')
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

BUCKET_NAME = os.environ['BUCKET_NAME']
IMAGES_TABLE = os.environ['IMAGES_TABLE']
EMBEDDINGS_TABLE = os.environ['EMBEDDINGS_TABLE']
GSI_NAME = os.environ['IMAGES_PROMPT_GSI']

def cosine_similarity(embedding1, embedding2):
    embedding1 = np.array(embedding1)
    embedding2 = np.array(embedding2)

    dp = np.dot(embedding1, embedding2)
    norm1 = np.linalg.norm(embedding1)
    norm2 = np.linalg.norm(embedding2)

    return dp / (norm1 * norm2)

def lambda_handler(event, context):
    try:
        query_params = event.get('queryStringParameters', {}) or {}
        image_id = query_params.get('image_id')
        prompt = query_params.get('prompt')

        if not image_id or not prompt:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Image ID and Prompt are required'
                })
            }

        query_embedding = None

        embeddings_table = dynamodb.Table(EMBEDDINGS_TABLE)
        response = embeddings_table.get_item(
            Key={'embedding_id': image_id}
        )

        if 'Item' not in response:
            return {
                'statusCode': 404,
                'body': json.dumps({
                    'error': 'No embedding found for image. Get embedding first'
                })
            }
        else:
            query_embedding = response['Item']['embedding']

        images_table = dynamodb.Table(IMAGES_TABLE)

        response = images_table.query(
            KeyConditionExpression=Key('prompt').eq(prompt),
            IndexName=GSI_NAME
        )

        items = [item for item in response['Items'] if item['image_id'] != image_id]

        if not items:
            return {
                'statusCode': 404,
                'body': json.dumps({
                    'error': 'No images found to compare against'
                })
            }

        embeddings = []

        embeddings = dynamodb.batch_get_item(
            RequestItems={
                embeddings_table.name: {
                    'Keys': [{'embedding_id': item['embedding_id']} for item in items][:100]
                }
            }
        )
        embeddings_response = embeddings['Responses'][embeddings_table.name]

        sims = {}

        for item in embeddings_response:
            if 'embedding' in item:
                sims[item['image_id']] = cosine_similarity(query_embedding, item['embedding'])

        sims = sorted([(k, v) for (k, v) in sims.items()], key=lambda x: x[1], reverse=True)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'results': [{"image_id": k, "similarity": v} for k, v in sims[:10]]
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
