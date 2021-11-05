import requests
import pytest


def test_get(url):
     response = requests.get("http://%s" % url)
     assert response.status_code == 200
     
def test_get_json(url):
     response = requests.get("http://%s" % url)
     assert response.headers["Content-Type"] == "application/json"