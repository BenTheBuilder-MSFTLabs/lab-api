FROM node:18

# Set the working directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY ./src/package.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application files
COPY ./src ./src

# Expose the port the app runs on
EXPOSE 80

# Command to run the application
CMD ["node", "src/server.js"]