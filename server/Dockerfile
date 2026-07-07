# RideNow API (Express + socket.io + Prisma/SQLite + driver simulation)
FROM node:20-slim
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY prisma ./prisma
RUN npx prisma generate
COPY tsconfig.json ./
COPY src ./src
EXPOSE 3000
# Push schema on boot; seed only when the db is empty (fresh volume)
CMD ["sh", "-c", "npx prisma db push --skip-generate && ([ -f /data/.seeded ] || (npx tsx prisma/seed.ts && touch /data/.seeded)) && npx tsx src/index.ts"]
