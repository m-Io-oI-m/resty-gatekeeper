import { serve, type HttpBindings } from '@hono/node-server'
import { Hono } from 'hono';
import { logger } from 'hono/logger'
import * as jose from 'jose';
import * as path from 'path';
import * as fs from 'fs/promises';
import { v4 as uuidv4 } from 'uuid';

type Username = 'user1' | 'user2' | 'user3';

interface User {
  password: string;
  uid: string;
  role: string
}

interface AuthRequestBody {
  username: Username;
  password: string;
}


try {
  
  const pathKey = path.resolve('./private_key.pem')
  
  const fileKey = await fs.readFile(pathKey, 'utf-8')

  const privateKey = await jose.importPKCS8(fileKey, 'RS256')

  // const ecPublicKey = await jose.importSPKI(fileKey.toString(), 'RS256')

  const users: Record<Username, User> = {
    user1: { password: 'password1', uid: uuidv4(), role: 'user' },
    user2: { password: 'password2', uid: uuidv4(), role: 'user' },
    user3: { password: 'password3', uid: uuidv4(), role: 'user' }
  };

  const app = new Hono<{ Bindings: HttpBindings }>()

  app.use('*', logger())

  app.post('/login', async (c) => {

    console.log()

    const { username, password } = await c.req.json<AuthRequestBody>();

    const user = users[username];

    if (!user || user.password !== password) {
      return c.json({ error: 'invalid_credentials' }, 401);
    }

    const customClaims = {
      roles: [ user.role ]
    };

    const alg = 'RS256';
    const jwt = await new jose.SignJWT(customClaims)
      .setProtectedHeader({ alg })
      .setIssuedAt()
      .setSubject(username)
      .setNotBefore("1 seconds")
      .setJti(uuidv4()) // JTI is crucial for revocation
      .setExpirationTime('1h')
      .sign(privateKey);

    // Fixed response format to match Lua expectations
    return c.json({
      token: jwt,  // Changed from access_token to token
      user: {
        id: user.uid,
        username: username,
        roles: [user.role]  // Changed to array format
      },
      expires_at: Math.floor(Date.now() / 1000) + 3600  // Current time + 1 hour in seconds
    });
  });

  const server = serve({
    fetch: app.fetch,
    port: parseInt(process.env.PORT ?? '3000')
  }, (info) => {
    console.log(`Server is running on http://localhost:${info.port}`)
  })

  // graceful shutdown
  process.on("SIGINT", () => {
    server.close()
    process.exit(0)
  })
  process.on("SIGTERM", () => {
    server.close((err) => {
      if (err) {
        console.error(err)
        process.exit(1)
      }
      process.exit(0)
    })
  })

} catch(err) {
  console.log("error detected")
  console.log(err)
}