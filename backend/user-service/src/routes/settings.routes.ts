import { Router } from "express";

import * as AdminController from "../controllers/admin.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";

const settingsRouter = Router();

// Public endpoint — no auth required
// GET /settings/keys — returns all public keys for mobile apps
settingsRouter.get(
  "/keys",
  ErrorHandlerMiddleware(AdminController.getPublicSettings),
  ResponseMiddleware,
);

export default settingsRouter;
