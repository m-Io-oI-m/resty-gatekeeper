import { serve, type HttpBindings } from '@hono/node-server'
import { Hono } from 'hono';
import jwt = require('hono/jwt');
import { logger } from 'hono/logger'
import { v4 as uuidv4 } from 'uuid';



try {

  const app = new Hono<{ Bindings: HttpBindings }>()

  app.use('*', logger())

  app.get('/', async (c) => {

    // Fixed response format to match Lua expectations
    return c.json({
      data: `I'm public endpoint, random data: ${ uuidv4() }`
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