# Resty Gatekeeper: A High-Performance OpenResty API Gateway



https://github.com/user-attachments/assets/734206c7-99a0-454b-af89-2d29db2b23e9



![OpenResty](https://img.shields.io/badge/OpenResty-0000A0?style=for-the-badge&logo=openresty&logoColor=white) ![Lua](https://img.shields.io/badge/Lua-2C2D72?style=for-the-badge&logo=lua&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white) ![Redis](https://img.shields.io/badge/redis-%23DD0031.svg?&style=for-the-badge&logo=redis&logoColor=white)

This project is a production-grade template for a secure and scalable API Gateway built with **OpenResty** (Nginx + Lua). It serves as a single, intelligent entry point for a microservices architecture, offloading critical tasks like authentication, routing, and schema validation from backend services.

---

## Table of Contents
1.  [The API Gateway Pattern: Why It Matters](#the-api-gateway-pattern-why-it-matters)
2.  [Core Features](#core-features)
3.  [System Architecture and Request Workflow](#system-architecture-and-request-workflow)
4.  [Service Descriptions](#service-descriptions)
5.  [Deep Dive: Schema Validation](#deep-dive-schema-validation)
6.  [Getting Started](#getting-started)
7.  [Testing the Gateway: A Step-by-Step Demo](#testing-the-gateway-a-step-by-step-demo)

---

## The API Gateway Pattern: Why It Matters

In a modern microservices architecture, an API Gateway is not just a simple reverse proxy; it's a strategic control plane. By centralizing **shared responsibilities like authentication, authorization, accounting/logging, and rate limiting**, we create a more secure, efficient, and maintainable system.

Offloading tasks to the gateway allows backend developers to focus purely on business logic, accelerating development and reducing bugs. The backend services operate in a trusted environment, receiving requests that have already been authenticated and validated.

Here is a comparison of the gateway-centric approach versus a traditional, decentralized one:

| Concern               | Traditional Approach (In-Service)                                   | **Gateway Pattern (Offloaded to OpenResty)** |
| --------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Authentication** | Each service implements JWT validation logic, duplicating code and dependencies (`jose`, `jsonwebtoken`, etc.). | **Centralized & Fast:** Validation happens once at the edge in highly efficient compiled Lua code. Upstream services are inherently protected. |
| **Schema Validation** | Each service validates its own inputs, leading to boilerplate code and potential inconsistencies across the system. | **Fail-Fast & Consistent:** Invalid requests are rejected at the edge, saving compute resources and protecting all services from malformed data. |
| **Security Policy** | Each team must remember to set security headers, manage secrets, and implement rate limiting. Inconsistent application is common. | **Uniform Enforcement:** Security headers, rate limiting, and access control policies are applied consistently to all proxied traffic from one location. |
| **Developer Focus** | Developers spend significant time on boilerplate security and validation code instead of core business features. | **Increased Productivity:** Backend developers receive pre-validated, trusted requests. They can assume the user is authenticated and the data format is correct. |
| **Agility & Updates** | Updating a security library or a validation rule requires finding, editing, and redeploying multiple services. | **Decoupled & Agile:** Security policies can be updated and hot-reloaded in the gateway without touching or redeploying any of the backend services. |
| **Trusted Communication** | Services might trust headers (e.g., `X-User-ID`) from each other, which can be spoofed in a flat network. | **Zero-Trust for Services:** The gateway validates the external token, then *injects* trusted headers (`X-User-ID`, `X-User-Roles`). Upstream services can unconditionally trust these headers. |

By using **OpenResty**, we gain these benefits at near-native speed, thanks to its event-driven, non-blocking architecture and the LuaJIT compiler.

---

## Core Features

- **Dynamic Routing**: URI-based routing (`/api/{service-name}`) to any number of upstream services.
- **Asymmetric JWT Authentication**: Secure RS256 JWT validation using a public/private key pair.
- **Stateful Token Revocation**: Instant session invalidation on logout using a Redis-backed blocklist (JTI check).
- **Edge Schema Validation**: Rigorous request body and query parameter validation against per-endpoint JSON schemas.
- **Centralized Auth Policy**: A single Nginx config block defines which services are public and which are protected.
- **Robust Security**: Enforces rate limiting, HttpOnly cookies, and standard security headers (`X-Frame-Options`, etc.).
- **Containerized & Portable**: The entire environment is defined in Docker Compose for one-command setup.
- **Developer-Friendly**: Provides clear, trusted headers (`X-User-ID`, `X-User-Roles`) to upstream services.

---

## System Architecture and Request Workflow

The gateway is the sole public-facing component. All other services are on a private Docker network, accessible only through the gateway.

```text
           +-------------------------------------------------+
           |                   CLIENTS                       |
           +-----------------------+-------------------------+
                                   |
                                   | (HTTP/S Request on Port 8080)
                                   |
      +----------------------------v-----------------------------+
      |                  API GATEWAY (OpenResty)                  |
      |                                                           |
      |  1. Parse URI -> {service_name}, {service_path}           |
      |  2. Check Auth Policy -> Is JWT required?                 |
      |     |                                                     |
      |     +--> [ YES ] --> Verify JWT (Signature, EXP, Revocation)
      |                      |           |                        |
      |                      |           v                        |
      |                      +--------> Redis (Check JTI)         |
      |                                                           |
      |  3. Validate Request (Body/Query) vs. Schema              |
      |  4. On Success: Inject X-User-* headers, Route Internally |
      +----------------------------+-----------------------------+
                  |                |                 |
(Internal Proxy)  |                |                 |
       +----------v------+  +------v--------+  +-----v---------+
       | auth_service    |  | public_service|  | protected_... |
       +-----------------+  +---------------+  +---------------+
```

---

## Service Descriptions

| Service             | Technology              | Role & Responsibility                                                                                    |
| ------------------- | ----------------------- | -------------------------------------------------------------------------------------------------------- |
| `api_gateway`       | **OpenResty (Nginx+Lua)** | **The Gatekeeper.** Handles all inbound traffic, routing, auth, validation, and rate limiting.             |
| `auth_service`      | Node.js (Hono)          | **The Identity Provider.** Issues RS256-signed JWTs after validating user credentials.                      |
| `protected_service` | Node.js (Hono)          | **A Private Microservice.** Requires a valid JWT. Business logic trusts the `X-User-*` headers.            |
| `public_service`    | Node.js (Hono)          | **A Public Microservice.** Does not require authentication.                                                |
| `cache_service`     | Redis                   | **The Revocation List.** Stores the unique IDs (JTI) of revoked tokens until they expire.                 |
| `debug_service`     | Python                  | **The Inspector.** A simple echo server that helps debug the exact request being proxied by the gateway. |

---

## Deep Dive: Schema Validation

A key strength of this pattern is rejecting invalid requests at the earliest possible moment.

- **Technology**: Powered by the `resty.jsonschema` library, which provides fast JSON Schema validation.
- **Structure**: Schemas are defined in Lua tables in the `api_gateway/lua/schemas/` directory. Each service that requires validation has its own file (e.g., `protected.lua`, `public.lua`).
- **Endpoint Registry**: Within each schema file, an `endpoints` table explicitly maps HTTP methods and regex URI patterns to compiled validator functions. This provides granular, per-endpoint control.
    ```lua
    -- Example from schemas/protected.lua
    _M.endpoints = {
        ["POST"] = {
            -- A POST to /items requires a specific body
            ["^/items$"] = compiler.compile(post_items_body_schema)
        },
        ["GET"] = {
            -- A GET to /items allows an optional 'status' query param
            ["^/items$"] = compiler.compile(get_items_query_schema),
            -- A GET to /items/123 is valid but needs no body/query validation
            ["^/items/[^/]+$"] = true
        }
    }
    ```
- **Secure by Default**: A central `schemas/registry.lua` explicitly loads all known schema modules. The gateway's proxy handler **only** uses this registry, completely avoiding dynamic, path-based `require()` calls. This is a critical security design that prevents code injection and ensures that only defined endpoints can be accessed.

## Prerequisites

Before you begin, ensure you have the following tools installed on your system:
- **Docker & Docker Compose**: For building and running the containerized environment.
- **OpenSSL**: For generating the RSA key pair for JWT signing.
- **curl**: For testing the API endpoints from the command line.
- **jq**: A lightweight command-line JSON processor, useful for pretty-printing API responses.


---
## Getting Started

### Prerequisites
- Docker & Docker Compose

### 1. Generate RSA Key Pair

The gateway uses an RS256 key pair: the `auth_service` signs JWTs with the private key, and the `api_gateway` verifies them with the public key.

```sh
# Generate a 2048-bit RSA private key
openssl genpkey -algorithm RSA -out private_key.pem -pkeyopt rsa_keygen_bits:2048

# Extract the public key from the private key
openssl rsa -pubout -in private_key.pem -out public_key.pem
```

### 2. Place Keys in Service Directories

Move the generated keys to their respective locations. **Do not commit the private key to version control.**

- `private_key.pem` -> `auth_service/`
- `public_key.pem`  -> `api_gateway/`

### 3. Launch the Environment

From the project's root directory, build the images and launch all services in detached mode.

```sh
docker-compose up --build -d
```

The system is now running. The API Gateway is listening on `http://127.0.0.1:8080`.

## Configuration

This project is designed to be easily configurable. Key settings are located in:

- **Service Authentication Policy**: `api_gateway/nginx.d/default.conf`
  - The `init_by_lua_block` contains an `auth_policy` table where you can define which services require authentication. This could be loaded from a json file or from a remote service
    ```lua
    local auth_policy = {
        ["public"] = false,    -- No authentication required.
        ["debug"] = true,      -- Authentication required.
        ["protected"] = true,  -- Authentication required.
    }
    ```
- **Redis Connection**: `api_gateway/lua/lib/redis_client.lua`
  - The `REDIS_CONFIG` table defines the connection details for the Redis service. It is already configured to use environment variables, which is best practice.
- **Rate Limiting**: `api_gateway/nginx.d/default.conf`
  - The `limit_req_zone` directives at the top of the file define the rate limits for login attempts and general API usage.

---

## Security Considerations

- **Private Key Management**: **NEVER** commit your `private_key.pem` to version control. Use a secrets management system like HashiCorp Vault, AWS Secrets Manager, or environment variables to inject it into the `auth_service` container in a production environment.
- **Error Messages**: For the purpose of this demo, error messages (e.g., from JWT validation) are detailed. In a production environment, you should trim these messages to avoid leaking internal system details. For example, instead of "token expired", simply return "Unauthorized".
- **Environment Variables**: The Redis client can be configure to use `os.getenv()` to read connection details. This is a good practice that should be extended to other configuration values as needed for production deployments.

---

## Testing the Gateway: A Step-by-Step Demo

Use these `curl` commands to interact with the system. In the following, `-c` is used to save the cookie. But when authenticating, the JWT will be return and can be use as `BEARER` token in the `Authorization` header as would work any API gateway;

### Step 1: Access a Public Endpoint
This requires no authentication and should succeed.
```sh
curl -i http://127.0.0.1:8080/api/public/
```
> **Expected:** `HTTP/1.1 200 OK` with a JSON payload.

### Step 2: Attempt to Access a Protected Endpoint (Fails)
This should be rejected by the gateway with a `401 Unauthorized` error.
```sh
curl -i http://127.0.0.1:8080/api/protected/
```
> **Expected:** `HTTP/1.1 401 Unauthorized`.

### Step 3: Log In to Get a Token
Authenticate with valid credentials. We use `-c cookie-jar.txt` to save the `HttpOnly` cookie for later use.
```sh
curl -i -X POST http://127.0.0.1:8080/api/auth/login \
-H "Content-Type: application/json" \
-d '{"username": "user1", "password": "password1"}' \
-c cookie-jar.txt
```
> **Expected:** `HTTP/1.1 200 OK`. The response body contains the JWT, and the `Set-Cookie` header is present.

### Step 4: Access a Protected Endpoint (Succeeds)
Retry the request from Step 2, this time including the cookie we just received by using the `-b cookie-jar.txt` flag.
```sh
curl -i http://127.0.0.1:8080/api/protected/ -b cookie-jar.txt
```
> **Expected:** `HTTP/1.1 200 OK` with data from the protected service.

### Step 5: Test Schema Validation (Fails then Succeeds)
First, send an invalid payload to a protected endpoint. The gateway should reject it.
```sh
# This payload is invalid because the 'title' field is required
curl -i -X POST http://127.0.0.1:8080/api/protected/items \
-b cookie-jar.txt \
-H "Content-Type: application/json" \
-d '{"description": "An item without a title"}'
```
> **Expected:** `HTTP/1.1 400 Bad Request` with validation error details.

Now, send a valid payload. The gateway should accept it.
```sh
curl -i -X POST http://127.0.0.1:8080/api/protected/items \
-b cookie-jar.txt \
-H "Content-Type: application/json" \
-d '{"title": "Title item", "description":"description for item xx", "priority": "high"}'
```
> **Expected:** `HTTP/1.1 201 Created`.

### Step 6: Log Out
Send a request to the logout endpoint. This revokes the token in Redis and clears the client-side cookie.
```sh
curl -i http://127.0.0.1:8080/api/auth/logout -b cookie-jar.txt
```
> **Expected:** `HTTP/1.1 200 OK` with a "Successfully logged out" message.

### Step 7: Verify Token Revocation
Attempt to use the same (now revoked) token one last time. The request should be rejected, proving the revocation system works.
```sh
curl -i http://127.0.0.1:8080/api/protected/ -b cookie-jar.txt
```
> **Expected:** `HTTP/1.1 401 Unauthorized` with a "token revoked" reason.


## improvement & Reference : 

### demo
For the purpose of the demo, errors raised to client are very detailed for jwt validation and more but would need to be trimmed to security reason;

The microservices (auth_service, protected_service, public_service) are basic service for the purpose of the demo.

The auth_service use jose to generate the JWT, but it would be better to use encrypted JWT and decode the header of the token.

### openresty / lua module

[openresty](https://openresty-reference.readthedocs.io/en/latest/) : referential

[api7/jsonschema](https://github.com/api7/jsonschema) : schema validation

### jose 

[jose](https://github.com/panva/jose) : jwt 

