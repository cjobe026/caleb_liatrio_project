from flask import Flask
from flask_restful import Resource, Api
import time

app = Flask(__name__)
api = Api(app)

class BasicRequest(Resource):
    def get(self):
        ts = round(time.time())
        return {
            'message': 'Automate all the things!',
            'timestamp': ts
        }

api.add_resource(BasicRequest, '/')

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=80)