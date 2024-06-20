import coremltools as ct
import tensorflow as tf

# Load the TensorFlow Keras model
model = tf.keras.models.load_model('activity_model.keras')

# Define the number of features to match model
num_features = model.input_shape[1] 

# Convert the model to Core ML format
coreml_model = ct.convert(model, inputs=[ct.TensorType(shape=(1, num_features))])

# Save the Core ML model
coreml_model.save('ActivityModel.mlpackage')