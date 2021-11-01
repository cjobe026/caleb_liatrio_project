from types import ClassMethodDescriptorType
import requests


try:
    response =  requests.get('http://a66b25a6b195643549dff7b2eac412fb-1891475554.us-east-2.elb.amazonaws.com')
    if response.status_code == 200:
        print('Success!')
    elif response.status_code == 404:
        print('Not Found.')
except requests.exceptions.RequestException as e:
    print('Unable to make connection')