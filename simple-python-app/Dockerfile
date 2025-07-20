#################-----------------    Single-Stage Dockerfile   ------------------##################
# # Base image
# FROM python:3.8

# # Set the working directory inside the container
# WORKDIR /app

# # Copy the requirements file
# COPY requirements.txt .

# # Install the project dependencies
# RUN pip install -r requirements.txt

# # Copy the application code into the container
# COPY . .

# # Expose the port the Flask application will be listening on
# EXPOSE 5000

# # Set environment variables, if necessary
# # ENV MY_ENV_VAR=value

# # Run the Flask application
# CMD ["python", "app.py"]

#################-----------------    Multi-Stage Dockerfile without RDS  ------------------##################

# # Stage 1: Builder
# # This stage is responsible for installing all application dependencies.
# # We use a full Python base image here because some Python packages might
# # require compilation tools or libraries that are present in the larger image.
# FROM python:3.8 as builder

# # Set the working directory inside the builder container.
# WORKDIR /app

# # Copy only the requirements file first. This is a best practice to
# # leverage Docker's build cache. If requirements.txt doesn't change,
# # this and subsequent steps are cached.
# COPY requirements.txt .

# # Install the project dependencies.
# # The --no-cache-dir option reduces the size of this builder stage's layers
# # by preventing pip from storing its package cache.
# RUN pip install --no-cache-dir -r requirements.txt

# # Stage 2: Runner
# # This stage creates the final, lean image for your application.
# # It only includes the necessary application code and its runtime dependencies,
# # significantly reducing the image size and attack surface compared to the builder image.
# # We use a "slim-buster" Python image which is much smaller than the full Python image,
# # as it doesn't contain development tools or unnecessary OS components.
# FROM python:3.8-slim-buster as runner

# # Set the working directory inside the runner container.
# WORKDIR /app

# # Copy the installed Python packages from the 'builder' stage.
# # This selectively copies only the /site-packages directory where pip installed the libraries.
# # This avoids copying build tools, source code for dependencies, or pip's cache.
# COPY --from=builder /usr/local/lib/python3.8/site-packages /usr/local/lib/python3.8/site-packages

# # Copy the application code into the container.
# # Ensure you have a .dockerignore file at your project's root to exclude
# # unnecessary files (like .git/, .dockerignore itself, or local development files)
# # from being copied into the image.
# COPY . .

# # Expose the port on which the Flask application will be listening.
# # This acts as documentation for users of the image and can be used by
# # orchestrators (like Kubernetes) for port mapping.
# EXPOSE 5000

# # Define the command to run the Flask application when the container starts.
# # This is the entry point for your application.
# CMD ["python", "app.py"]


#################-----------------    Multi-Stage Dockerfile with RDS  ------------------##################

# Stage 1: Builder
# Uses a more recent Python image for installing dependencies.
# python:3.10-bullseye is recommended as it's more current and uses a newer Debian base.
# You could also consider python:3.11-bookworm if you want a very recent version.
FROM python:3.10-bullseye as builder

WORKDIR /app

# Copy only requirements.txt first to leverage Docker cache
COPY requirements.txt .

# Install dependencies, including Flask, Gunicorn, Flask-SQLAlchemy, and PyMySQL
# --no-cache-dir: Reduces image size by not storing build cache
# --upgrade pip: Ensures pip is up to date
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Stage 2: Runner
# Uses a minimal, more recent Python image for the final production container.
# Matching the base OS (bullseye) with the builder helps ensure GLIBC compatibility.
FROM python:3.10-slim-bullseye as runner

WORKDIR /app

# Copy installed Python packages from the builder stage
# This includes Flask, Flask-SQLAlchemy, PyMySQL library files
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages

# Copy the Python executable binaries (like 'gunicorn', 'pip', 'python') from the builder stage
# Ensure these executables are present in the runner image.
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy your application code into the runner stage
COPY . .

# Expose the port your Flask application will listen on
EXPOSE 5000

# Define the command to run the Flask application using Gunicorn
# This is the entry point for the container.
# -w 4: Starts Gunicorn with 4 worker processes (adjust based on CPU cores)
# -b 0.0.0.0:5000: Binds Gunicorn to all network interfaces on port 5000
# app:app: Tells Gunicorn to find the 'app' callable (your Flask app instance)
#          within the 'app.py' module.
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
