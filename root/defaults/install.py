from transformers import pipeline
from sentence_transformers import SentenceTransformer

# This script installs the models in the TRANSFORMERS_CACHE folder

classification_model = pipeline(task="image-classification", model="microsoft/resnet-50")
object_model = pipeline(task="object-detection", model="hustvl/yolos-tiny")
clip_model = SentenceTransformer("clip-ViT-B-32")
