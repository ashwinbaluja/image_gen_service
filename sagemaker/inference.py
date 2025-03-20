import json
import torch
import base64
import io
from PIL import Image
from transformers import CLIPProcessor, CLIPModel

model_id = "openai/clip-vit-base-patch32"
model = CLIPModel.from_pretrained(model_id)
processor = CLIPProcessor.from_pretrained(model_id)

def model_fn(model_dir):
    return model

def input_fn(request_body, request_content_type):
    if request_content_type == 'application/json':
        input_data = json.loads(request_body)
        return input_data
    else:
        raise ValueError(f"Unsupported content type: {request_content_type}")

def predict_fn(input_data, model):
    input_type = input_data.get('type', '')

    if input_type == 'text':
        text = input_data.get('data', '')
        inputs = processor(text=text, return_tensors="pt", padding=True, truncation=True)

        with torch.no_grad():
            text_features = model.get_text_features(**inputs)

        text_embeddings = text_features / text_features.norm(dim=-1, keepdim=True)
        embeddings = text_embeddings.tolist()[0]

    elif input_type == 'image':
        image_data = base64.b64decode(input_data.get('data', ''))
        image = Image.open(io.BytesIO(image_data))

        inputs = processor(images=image, return_tensors="pt")

        with torch.no_grad():
            image_features = model.get_image_features(**inputs)

        image_embeddings = image_features / image_features.norm(dim=-1, keepdim=True)
        embeddings = image_embeddings.tolist()[0]

    else:
        raise ValueError(f"Unsupported input type: {input_type}")

    return embeddings

def output_fn(prediction, response_content_type):
    if response_content_type == 'application/json':
        return json.dumps({'embedding': prediction})
    else:
        raise ValueError(f"Unsupported response content type: {response_content_type}")
