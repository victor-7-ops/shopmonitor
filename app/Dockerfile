FROM node:18-slim

WORKDIR /app

COPY package*.json ./
COPY node_modules/ ./node_modules/
COPY src/ ./src/

EXPOSE 3000

CMD ["node", "src/index.js"]
