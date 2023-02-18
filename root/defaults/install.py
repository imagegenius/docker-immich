from transformers import pipeline

# This script installs the models in the TRANSFORMERS_CACHE folder

classifier = pipeline(task="image-classification", model="microsoft/resnet-50")
detector = pipeline(task="object-detection", model="hustvl/yolos-tiny")
