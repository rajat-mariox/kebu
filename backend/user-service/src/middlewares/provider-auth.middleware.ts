import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import config from "../config";

const ProviderAuthMiddleware = () => {
  /**
   * Verify Provider Token
   */
  const verifyProviderToken = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const authHeader = req.headers.authorization;

      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({
          message: "No token provided",
          code: 0,
        });
      }

      const token = authHeader.split(" ")[1];

      const decoded = jwt.verify(token, config.auth.jwtSecret) as {
        providerId: string;
      };

      if (!decoded.providerId) {
        return res.status(401).json({
          message: "Invalid token",
          code: 0,
        });
      }

      (req as any).providerId = decoded.providerId;
      next();
    } catch (error) {
      return res.status(401).json({
        message: "Invalid or expired token",
        code: 0,
      });
    }
  };

  return { verifyProviderToken };
};

export default ProviderAuthMiddleware;
