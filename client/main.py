import requests
import json
import base64
from typing import Optional

class ImageServiceClient:
    def __init__(self, api_base_url: str):
        self.api_base_url = api_base_url.rstrip('/')

    def generate_images(self, prompt: str) -> dict:
        url = f"{self.api_base_url}/images"
        params = {'prompt': prompt}
        response = requests.get(url, params=params)
        return response.json()

    def upload_image(self, image_path: str) -> dict:
        url = f"{self.api_base_url}/images"
        try:
            with open(image_path, 'rb') as image_file:
                image_data = base64.b64encode(image_file.read()).decode('utf-8')
        except FileNotFoundError:
            return {"error": "Image file not found"}

        payload = {
            'image_data': image_data,
        }

        response = requests.post(url, json=payload)
        return response.json()

    def get_image(self, image_id: str) -> dict:
        url = f"{self.api_base_url}/images/{image_id}"
        response = requests.get(url)
        return response.json()

    def get_embedding(self, embedding_id: str) -> dict:
        url = f"{self.api_base_url}/embeddings/{embedding_id}"
        response = requests.get(url)
        return response.json()

    def find_similar_images(self, prompt: str, image_id: str) -> dict:
        url = f"{self.api_base_url}/similarity"
        params = {}

        params['prompt'] = prompt
        params['image_id'] = image_id

        response = requests.get(url, params=params)
        return response.json()

def print_menu():
    print("1. Generate images from prompt")
    print("2. Upload image")
    print("3. Get image by ID")
    print("4. Get embedding by ID")
    print("5. Find similar images by image ID")
    print("6. Exit")

def handle_response(response):
    print("\nResponse:")
    print(json.dumps(response, indent=2))

def main():
    # Default API URL - can be changed during runtime
    api_url = "https://9cz5jvn09c.execute-api.us-east-2.amazonaws.com/prod"
    client = ImageServiceClient(api_url)

    while True:
        print_menu()
        choice = input("Enter your choice (1-8): ")

        try:
            if choice == '1':
                prompt = input("Enter prompt for image generation: ")
                response = client.generate_images(prompt)
                handle_response(response)

            elif choice == '2':
                image_path = input("Enter path to image file: ")
                response = client.upload_image(image_path)
                handle_response(response)

            elif choice == '3':
                image_id = input("Enter image ID: ")
                response = client.get_image(image_id)
                handle_response(response)

            elif choice == '4':
                embedding_id = input("Enter embedding ID: ")
                response = client.get_embedding(embedding_id)
                handle_response(response)

            elif choice == '5':
                image_id = input("Enter image ID to find similar images: ")
                prompt = input("Enter prompt to filter search: ")
                response = client.find_similar_images(prompt, image_id)
                handle_response(response)

            elif choice == '6':
                break

            else:
                print("Invalid. Try again.")

        except requests.exceptions.RequestException as e:
            print(f"\nError making request: {str(e)}")
        except Exception as e:
            print(f"\nAn error occurred: {str(e)}")

if __name__ == "__main__":
    main()
