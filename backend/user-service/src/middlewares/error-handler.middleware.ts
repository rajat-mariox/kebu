import { Request, Response, NextFunction } from "express";
import ResponseMiddleware from "./response.middleware";

const ErrorHandlerMiddleware =
  (handler: Function) =>
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      await handler(req, res, next);
    } catch (ex: any) {
      console.error("ErrorHandlerMiddleware =>", ex);

      req.rCode = 0;
      const message = "Something went wrong. Please try again later.";

      return ResponseMiddleware(req, res, next, message);
    }
  };

export default ErrorHandlerMiddleware;
