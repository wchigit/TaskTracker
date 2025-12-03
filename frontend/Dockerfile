FROM node:18-bullseye

WORKDIR /app

# Update package lists and upgrade all packages to latest versions
# This ensures we get the latest security updates including ImageMagick
RUN apt-get update && apt-get upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY package.json /app/package.json
RUN npm install

COPY . /app

# Set the port environment variable
ENV PORT=80

EXPOSE 80

CMD ["npm", "start"]