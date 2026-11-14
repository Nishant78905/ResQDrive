# RESQDRIVE API

Express REST API for driver accounts, emergency contacts, vehicles, accident reports, and dispatcher incident lookup. SMS delivery is attempted only when TextBee is explicitly configured; otherwise notification attempts are recorded as failed and are never reported as sent.

## Requirements

- Node.js 18 or newer and npm
- PostgreSQL 14 or newer

## Setup

1. Create a PostgreSQL database named `resqdrive`.
2. From the repository root, apply the database files:

   ```powershell
   psql -d resqdrive -f backend/db/schema.sql
   psql -d resqdrive -f backend/db/seed.sql
   ```

3. Copy `backend/.env.example` to `backend/.env`. Set `DATABASE_URL` and generate a private random `JWT_SECRET` with at least 32 characters.
4. Install and run the API:

   ```powershell
   cd backend
   npm install
   npm run dev
   ```

5. Check `http://localhost:3000/health` or import `backend/postman/resqdrive.postman_collection.json` into Postman.

The seed account has no working password. Register a driver through `POST /api/auth/register`. To use dispatcher routes, create a dispatcher with a bcrypt hash in the `dispatch_users` table; dispatcher login is `POST /api/dispatch/login`.

## API

All protected requests use `Authorization: Bearer <JWT>`.

| Method | Path | Access |
| --- | --- | --- |
| POST | `/api/auth/register` | Public |
| POST | `/api/auth/login` | Public |
| POST | `/api/dispatch/login` | Public |
| GET, POST | `/api/contacts` | Driver |
| PATCH, DELETE | `/api/contacts/:id` | Driver, owner only |
| GET, POST | `/api/vehicles` | Driver |
| PATCH, DELETE | `/api/vehicles/:id` | Driver, owner only |
| POST | `/api/accidents` | Driver |
| PATCH | `/api/accidents/:id/cancel` | Driver, owner only |
| GET | `/api/accidents/history` | Driver |
| GET | `/api/dispatch/active` | Dispatcher or admin |
| PATCH | `/api/dispatch/:id/resolve` | Dispatcher or admin |

Accident creation calls `create_accident_with_sos` inside a PostgreSQL transaction. Notification delivery happens after commit; the current mock only logs. Replace `services/notificationService.js` with a provider adapter for Twilio SMS, Firebase push, and email delivery.

## Security and Configuration

The API validates inputs with Joi, hashes passwords with bcryptjs, signs JWTs from environment configuration, rate limits `/api`, sets Helmet headers, restricts CORS, and centralizes errors. Never commit `.env` or put credentials in the seed file.
