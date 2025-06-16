FROM node:alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS build

RUN mkdir /app

COPY ./app/pnpm-lock.yaml /app
COPY ./app/package.json /app

WORKDIR /app

# Install ALL dependencies (including devDependencies) for building
RUN pnpm fetch
RUN pnpm install --frozen-lockfile

# Copy source code
COPY ./app/src ./src
COPY ./app/tsconfig.json ./tsconfig.json

# Build the application
RUN pnpm run build

FROM base AS prod

RUN mkdir /app

COPY ./app/pnpm-lock.yaml /app
COPY ./app/package.json /app

WORKDIR /app

# Install only production dependencies
RUN pnpm fetch --prod
RUN pnpm install --frozen-lockfile --prod

FROM base

WORKDIR /app

# Copy built application and production dependencies
COPY --from=prod /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY ./app/package.json ./package.json

EXPOSE 3000

CMD [ "pnpm", "start" ]