# I created a simple feedback neural network to process five different activity levels.
# These predictions are used to calculate an individual's recommended protein intake within the logic of the iOS app.
# The training data is based on a set of assumptions, but actual subject data would be needed for real business use.

#imports
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import f1_score
import numpy as np
import tensorflow as tf

# Load data
data = pd.read_csv('training.csv')

# Normalize features
scaler = StandardScaler()
features = scaler.fit_transform(data.drop('target', axis=1))

# Labels set in the target column
labels = data['target'].values

# Split data to compensate for small data size, the split is stratified
train_data, test_data, train_labels, test_labels = train_test_split(
    features, 
    labels, 
    test_size=0.2, 
    random_state=42, 
    stratify=labels
)

# Define the number of features
num_features = train_data.shape[1]

# Model
# Initially I was going to just do simple feedback with only dense layers, as this seemed appropriate for table data
# However, I felt from early results that I was overfitting the data, so I decided to add dropout layers

# Modify the model architecture
model = tf.keras.Sequential([
    tf.keras.layers.Dense(32, activation='relu', input_shape=(num_features,)),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(5, activation='softmax')
])

# Adam optimizer
optimizer = tf.keras.optimizers.Adam(learning_rate=0.0001)

# Compiler
model.compile(optimizer=optimizer, 
              loss='sparse_categorical_crossentropy', 
              metrics=['accuracy'])

# Learning rate scheduler to balance the learning and avoid overfitting
def scheduler(epoch, lr):
    if epoch < 10:
        return lr
    else:
        return lr * tf.math.exp(-0.1)

callback = tf.keras.callbacks.LearningRateScheduler(scheduler)

# Early stopping callback to avoid overfitting
early_stopping = tf.keras.callbacks.EarlyStopping(monitor='val_loss', patience=3, restore_best_weights=True)

# Train the model with the modified configuration
model.fit(train_data, train_labels, epochs=20, batch_size=16, validation_split=0.2, callbacks=[early_stopping, callback])

# Predict
predictions = model.predict(test_data)
predictions = np.argmax(predictions, axis=1)

# F1-Score
f1 = f1_score(test_labels, predictions, average='weighted')
print(f"F1 Score: {f1}")

# Save
model.save('activity_model.keras')