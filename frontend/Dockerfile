FROM node:14

WORKDIR /app

COPY package.json /app/package.json
RUN npm install

COPY . /app

# Set the port environment variable
ENV PORT=80

EXPOSE 80

CMD ["npm", "start"]