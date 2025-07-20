# app.py - Main Flask Application for a 3-Tier Architecture with RDS

from flask import Flask, render_template, request, redirect, url_for, jsonify
from flask_sqlalchemy import SQLAlchemy
import os # To read environment variables for database connection

# Initialize the Flask application
app = Flask(__name__)

# ====================================================================
# DATABASE CONFIGURATION (AWS RDS for 3-Tier)
# ====================================================================

# Database URI format: 'dialect+driver://user:password@host:port/database'
# We will read these values from environment variables, which is a best practice for production.
# These environment variables will be set during deployment (e.g., by CodeDeploy or Docker).
# IMPORTANT: Changed fallback to 'sqlite:///:memory:' for ephemeral test environments like CodeBuild
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///:memory:')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False # Suppress SQLAlchemy track modifications warning

db = SQLAlchemy(app)

# Define a simple database model for messages
class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.Text, nullable=False)

    def __repr__(self):
        return f'<Message {self.id}: {self.text[:20]}...>'

# ====================================================================
# FLASK ROUTES
# ====================================================================

@app.route('/')
def home():
    """Renders the home page, displaying messages.
    Modified to NOT query DB directly on the root '/' for simplicity in build-time tests.
    The DB query for messages will be attempted, but the app won't crash if it fails."""
    messages = []
    # This try-except block is robust for runtime, but for CodeBuild test,
    # the /health endpoint is safer.
    try:
        # Fetch the latest 5 messages from the database
        messages = Message.query.order_by(Message.id.desc()).limit(5).all()
    except Exception as e:
        print(f"Error fetching messages from RDS: {e}. Displaying empty list.")
        # In a real app, you might render an error message on the page
        # or log this more robustly.
        pass # Continue to render the page even if DB connection fails

    return render_template('index.html', messages=messages)

@app.route('/add_message', methods=['POST'])
def add_message():
    """Handles submission of new messages to the RDS database."""
    if request.method == 'POST':
        message_text = request.form['message']
        if message_text:
            try:
                new_message = Message(text=message_text)
                db.session.add(new_message)
                db.session.commit()
                print(f"Message added to RDS: {message_text}")
            except Exception as e:
                db.session.rollback() # Rollback on error
                print(f"Error adding message to RDS: {e}")
        else:
            print("Empty message received.")
    return redirect(url_for('home')) # Redirect back to home page

@app.route('/about')
def about():
    """Renders the about me page."""
    return render_template('about.html')

@app.route('/contact')
def contact():
    """Renders the contact page."""
    return render_template('contact.html')

# NEW: Dedicated Health Check Endpoint for build-time testing
@app.route('/health')
def health():
    """
    Returns a simple JSON response indicating the application is running.
    This endpoint does NOT attempt to connect to the database,
    making it suitable for basic health checks in environments like CodeBuild.
    """
    return jsonify(status="OK", message="Flask app is alive!")

# Custom 404 Error Handler
@app.errorhandler(404)
def page_not_found(e):
    """
    Handles 404 Not Found errors, rendering a custom error page.
    """
    return render_template('404.html'), 404

# ====================================================================
# APPLICATION RUNNER (for local development or Gunicorn entry point)
# ====================================================================

if __name__ == '__main__':
    # For local development with SQLite fallback or initial DB setup:
    # This will create tables if they don't exist.
    # When using 'sqlite:///:memory:', this call is for creating tables in memory.
    # In a production Docker/CodeDeploy setup, database migrations are
    # typically handled by a separate script run *before* starting the app.
    with app.app_context():
        # db.create_all() will create tables in the in-memory SQLite if no DATABASE_URL
        # is set, allowing the app to fully initialize for the CodeBuild test.
        db.create_all()
        print("Database tables ensured for SQLAlchemy (local/in-memory).")

    # Using Gunicorn for production: gunicorn -w 4 -b 0.0.0.0:5000 app:app
    # Flask's built-in server for development:
    app.run(debug=True, host='0.0.0.0', port=5000)