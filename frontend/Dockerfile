# Dev-oriented image: runs the Vite dev server with hot reload. The source is
# bind-mounted by docker-compose; node_modules stays in an anonymous volume so
# the host folder doesn't shadow the installed deps.
FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install

COPY . .

EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
