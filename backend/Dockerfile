FROM python:3.11-bullseye

WORKDIR /app

# Update package lists and upgrade all packages to latest versions
# This ensures we get the latest security updates including ImageMagick
RUN apt-get update && apt-get upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV MONGO_URL=mongodb://mongo:27017

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]
