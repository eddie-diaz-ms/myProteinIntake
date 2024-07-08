# Import dependencies
from fastapi import FastAPI, Request
from pydantic import BaseModel
import tensorflow as tf
from pymongo import MongoClient
import numpy as np

# MongoDB setup
client = MongoClient('localhost', 27017)
db = client['protein_intake_db']
profiles = db['user_profiles']  # Collection for user profiles (from app)
activities = db['user_activities'] # Collection for user activities (predictions)

# Load TensorFlow model from file
def load_model():
    model_path = './server/model/activity_model.keras'
    model = tf.keras.models.load_model(model_path)
    return model

model = load_model()

# Define FastAPI app
app = FastAPI()

# Request models
class Features(BaseModel):
    avg_steps: float
    frequency_run: float
    frequency_bike: float
    active_job: bool
    gym_amount: float

class PredictRequest(BaseModel):
    user_id: str
    features: Features

class UserRequest(BaseModel):
    user_id: str
    user_data: dict

# Root endpoint
@app.get("/")
async def read_root():
    return {"message": "ML Model Server Running"}

# Prediction endpoint
@app.post("/predict")
async def predict(request: PredictRequest):
    features_dict = request.features.dict()

    # Convert the features dictionary to a list in the order expected by the model
    features = [
        features_dict['avg_steps'],
        features_dict['frequency_run'],
        features_dict['frequency_bike'],
        features_dict['active_job'],
        features_dict['gym_amount'],
    ]

    # Convert features to the format expected by the model
    features_array = np.array([features]) 

    # Predict using the model and take argmax to find the most probable class
    prediction_probabilities = model.predict(features_array)
    predicted_class = np.argmax(prediction_probabilities, axis=-1)
    
    # Save the prediction and user activity data to MongoDB (if needed)
    activity_data = {
        'user_id': request.user_id,
        'features': features,
        'prediction': predicted_class.tolist()
    }
    activities.insert_one(activity_data)

    # Return the predicted class as the response
    return {'predicted_class': predicted_class.tolist()}

# User data endpoint
@app.post("/user")
async def store_user_data(request: UserRequest):
    user_data = request.user_data

    # Store user profile data
    profiles.update_one({'user_id': request.user_id}, {"$set": user_data}, upsert=True)

    return {"message": "User data stored"}

# Run the server
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8888)

