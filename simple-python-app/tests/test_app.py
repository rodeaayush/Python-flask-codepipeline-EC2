import pytest
import requests
import time

# Base URL for the locally running Flask app
# This assumes the app is running on localhost:5000
BASE_URL = "http://localhost:5000"

def wait_for_app():
    """Waits for the Flask app to become available."""
    max_retries = 10
    for i in range(max_retries):
        try:
            response = requests.get(BASE_URL)
            if response.status_code == 200:
                print(f"App is ready after {i+1} retries.")
                return True
        except requests.exceptions.ConnectionError:
            print(f"App not ready yet, retrying in 2 seconds... ({i+1}/{max_retries})")
            time.sleep(2)
    return False

def test_homepage_loads():
    """Test that the homepage returns a 200 OK status and correct content."""
    assert wait_for_app(), "Flask app did not start up correctly for testing."
    response = requests.get(BASE_URL)
    assert response.status_code == 200
    assert "Welcome to My Flask Application!" in response.text

def test_about_page_loads():
    """Test that the about page returns a 200 OK status and correct content."""
    assert wait_for_app(), "Flask app did not start up correctly for testing."
    response = requests.get(f"{BASE_URL}/about")
    assert response.status_code == 200
    assert "My Journey in Cloud & DevOps" in response.text

def test_contact_page_loads():
    """Test that the contact page returns a 200 OK status and correct content."""
    assert wait_for_app(), "Flask app did not start up correctly for testing."
    response = requests.get(f"{BASE_URL}/contact")
    assert response.status_code == 200
    assert "Get in Touch" in response.text

# You would then modify the buildspec.yml to run these tests
# - python -m pytest simple-python-app/tests/