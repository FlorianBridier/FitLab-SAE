FROM node:22-alpine

# User non root (sécurité)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY package.json package-lock.json* ./

RUN npm install --production

COPY . .

USER appuser

EXPOSE 3000

CMD ["npm", "start"]
