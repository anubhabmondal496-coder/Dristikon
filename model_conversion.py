
import tensorflow as tf
from pathlib import Path

# Change this to the actual location of your trained .h5 model
MODEL_PATH = Path("Models/Currency_checking_model.h5")
OUTPUT_PATH = Path("Models/currency_model.tflite")

print("TensorFlow version:", tf.__version__)

# Load without compiling: training configuration is not needed for inference
model = tf.keras.models.load_model(
    MODEL_PATH,
    compile=False
)

print("Model input shape:", model.input_shape)
print("Model output shape:", model.output_shape)

# Convert the Keras model to TensorFlow Lite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

OUTPUT_PATH.write_bytes(tflite_model)

print(f"Conversion successful: {OUTPUT_PATH.resolve()}")
print(f"Model size: {OUTPUT_PATH.stat().st_size / (1024 * 1024):.2f} MB")

# Verify that the generated model can be loaded
interpreter = tf.lite.Interpreter(model_path=str(OUTPUT_PATH))
interpreter.allocate_tensors()

print("TFLite input:", interpreter.get_input_details())
print("TFLite output:", interpreter.get_output_details())
print("TFLite model verification successful.")
