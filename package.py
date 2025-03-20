import os
import tarfile
from transformers import CLIPProcessor, CLIPModel

def create_model_archive(model_dir, output_path):
    # model_id = "openai/clip-vit-base-patch32"
    # model = CLIPModel.from_pretrained(model_id)
    # processor = CLIPProcessor.from_pretrained(model_id)

    # model.save_pretrained(os.path.join(model_dir, "model"), safe_serialization=False)
    # if type(processor) == tuple:
    #     processor[0].save_pretrained(os.path.join(model_dir, "processor"))
    # elif type(processor) == CLIPProcessor:
    #     processor.save_pretrained(os.path.join(model_dir, "processor"))

    with open(os.path.join(model_dir, "inference.py"), "w") as f:
        with open("sagemaker/inference.py", "r") as source:
            f.write(source.read())

    with tarfile.open(output_path, "w:gz") as tar:
        tar.add(model_dir, arcname=".")

if __name__ == "__main__":
    if not os.path.exists("clip-model.tar.gz"):
        create_model_archive("sagemaker/model", "clip-model.tar.gz")
