FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache tini

COPY package*.json ./

RUN npm ci --only=production

COPY tsconfig.json ./
RUN npm run build

COPY .env.example .env

EXPOSE 3001 8080

USER node

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "dist/index.js"]
