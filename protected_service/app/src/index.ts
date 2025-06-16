import { serve, type HttpBindings } from '@hono/node-server';
import { Hono } from 'hono';
import { logger } from 'hono/logger';
import { v4 as uuidv4 } from 'uuid';

try {
  const app = new Hono<{ Bindings: HttpBindings }>();

  app.use('*', logger());

  // --- Existing Endpoint ---
  app.get('/', async (c) => {
    // The gateway sets these headers after validating the JWT
    const userId = c.req.header('X-User-ID');
    const userRoles = c.req.header('X-User-Roles');

    return c.json({
      message: "This is a private root endpoint.",
      data: `Random data: ${uuidv4()}`,
      userInfo: {
        id: userId || 'not-provided',
        roles: userRoles ? JSON.parse(userRoles) : 'not-provided',
      },
    });
  });

  // --- New Endpoints ---

  // 1. GET with a path parameter
  // e.g., /items/123
  app.get('/items/:id', (c) => {
    const { id } = c.req.param();
    const userId = c.req.header('X-User-ID');

    return c.json({
      message: `Data for item #${id}`,
      retrievedBy: userId,
      timestamp: new Date().toISOString(),
    });
  });

  // 2. GET with a query parameter
  // e.g., /items?status=pending
  app.get('/items', (c) => {
    const status = c.req.query('status');
    const userId = c.req.header('X-User-ID');

    if (!status) {
        return c.json({ 
            message: "Listing all items",
            retrievedBy: userId,
            items: [
                { id: 1, title: "Buy milk" },
                { id: 2, title: "Walk the dog" }
            ]
        }, 200);
    }

    return c.json({
        message: `Searching for items with status: ${status}`,
        retrievedBy: userId,
        filtersApplied: { status },
    });
  });

  // 3. POST with a JSON body
  app.post('/items', async (c) => {
    const userId = c.req.header('X-User-ID');
    const body = await c.req.json();

    return c.json({
      message: 'New item created successfully!',
      createdBy: userId,
      itemReceived: body,
      assignedId: uuidv4(),
    }, 201); // 201 Created status
  });


  const server = serve({
    fetch: app.fetch,
    port: parseInt(process.env.PORT ?? '3000'),
  }, (info) => {
    console.log(`Server is running on http://localhost:${info.port}`);
  });

  // Graceful shutdown
  process.on('SIGINT', () => {
    server.close();
    process.exit(0);
  });
  process.on('SIGTERM', () => {
    server.close((err) => {
      if (err) {
        console.error(err);
        process.exit(1);
      }
      process.exit(0);
    });
  });

} catch (err) {
  console.log('error detected');
  console.log(err);
}