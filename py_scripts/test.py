from PIL import Image
from transformers import TrOCRProcessor, VisionEncoderDecoderModel

processor = TrOCRProcessor.from_pretrained("microsoft/trocr-base-handwritten")

model = VisionEncoderDecoderModel.from_pretrained("microsoft/trocr-base-handwritten")

image = Image.open(
    "C:/Users/krucek/Documents/DATA/slp_inventory_mandeye/figs/cam0_1764106268621537149.jpg"
).convert("RGB")

pixel_values = processor(image, return_tensors="pt").pixel_values

generated_ids = model.generate(pixel_values)

text = processor.batch_decode(generated_ids, skip_special_tokens=True)[0]

print(text)
