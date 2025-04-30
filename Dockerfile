FROM node:8
COPY . .

RUN npm install
EXPOSE 8080
CMD ["npm", "run", "serve"]
