import tornado.ioloop
import tornado.web
import tensorflow as tf
from pymongo import MongoClient
import numpy as np
import json

client = MongoClient('localhost', 27017)
db = client['protein_intake_db']
profiles = db['user_profiles']
activities = db['user_activities']

def load_model():
    model_path = '/path/to/model'
    model = tf.keras.models.load_model(model_path)
    return model

model = load_model()

class MainHandler(tornado.web.RequestHandler):
    def get(self):
        self.write("ML Model Server Running")

class PredictHandler(tornado.web.RequestHandler):
    async def post(self):
        data = tornado.escape.json_decode(self.request.body)
        features = [
            data['features']['avg_steps'],
            data['features']['frequency_run'],
            data['features']['frequency_bike'],
            data['features']['active_job'],
            data['features']['gym_amount']
        ]
        features_array = np.array([features])
        prediction_probabilities = model.predict(features_array)
        predicted_class = np.argmax(prediction_probabilities, axis=-1)
        activity_data = {
            'user_id': data['user_id'],
            'features': features,
            'prediction': predicted_class.tolist()
        }
        activities.insert_one(activity_data)
        self.write({'predicted_class': predicted_class.tolist()})

class UserHandler(tornado.web.RequestHandler):
    async def post(self):
        user_data = tornado.escape.json_decode(self.request.body)
        profiles.update_one({'user_id': user_data['user_id']}, {"$set": user_data}, upsert=True)
        self.write({"message": "User data stored"})

def make_app():
    return tornado.web.Application([
        (r"/", MainHandler),
        (r"/predict", PredictHandler),
        (r"/user", UserHandler)
    ])

if __name__ == "__main__":
    app = make_app()
    app.listen(8888)
    tornado.ioloop.IOLoop.current().start()