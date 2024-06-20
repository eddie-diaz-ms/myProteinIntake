#import dependencies
import tornado.ioloop
import tornado.web
import tensorflow as tf
from pymongo import MongoClient
import numpy as np
import json

# MongoDB setup
client = MongoClient('localhost', 27017)
db = client['protein_intake_db']  
profiles = db['user_profiles']   # Collection for user profiles (from app)
activities = db['user_activities'] # Collection for user activities (predictions)

# load tf model from file
def load_model():
    model_path = '/Users/eddiediaz/Desktop/SMU/Mobile/Final_Project/server/model/activity_model.keras'
    model = tf.keras.models.load_model(model_path)
    return model

model = load_model()

# this handler just states the server works
class MainHandler(tornado.web.RequestHandler):
    def get(self):
        self.write("ML Model Server Running")

# handler to generate predictions when requested from app
class PredictHandler(tornado.web.RequestHandler):
    async def post(self):
        data = tornado.escape.json_decode(self.request.body)
        features_dict = data['features']  # This should be a dictionary now
        
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
            'user_id': data.get('user_id'),
            'features': features,
            'prediction': predicted_class.tolist()
        }
        activities.insert_one(activity_data)

        # Return the predicted class as the response
        self.write({'predicted_class': predicted_class.tolist()})



# handler to store user data from app
class UserHandler(tornado.web.RequestHandler):
    async def post(self):
        user_data = tornado.escape.json_decode(self.request.body)

        # Store user profile data
        profiles.update_one({'user_id': user_data['user_id']}, {"$set": user_data}, upsert=True)

        self.write({"message": "User data stored"})

# small amount of handlers, should do the trick
def make_app():
    return tornado.web.Application([
        (r"/", MainHandler),
        (r"/predict", PredictHandler),
        (r"/user", UserHandler)
    ])

# listen on port 8888
if __name__ == "__main__":
    app = make_app()
    app.listen(8888)
    tornado.ioloop.IOLoop.current().start()


