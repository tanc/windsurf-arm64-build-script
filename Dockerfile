# Use the official Playwright image which comes with browsers pre-installed
FROM mcr.microsoft.com/playwright:v1.53.1-noble

# Set the working directory
WORKDIR /usr/src/app

# Copy the package.json and install dependencies
COPY package.json ./
RUN npm install

# Copy the scraper script
COPY get-download-url.js ./

# Set the entrypoint to run the script
ENTRYPOINT ["node", "get-download-url.js"]
