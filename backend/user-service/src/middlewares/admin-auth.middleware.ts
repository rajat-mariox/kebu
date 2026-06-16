import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

import config from "../config";
import Admin from "../models/admin.model";
import ResponseMiddleware from "./response.middleware";

interface JwtPayload {
  adminId: string;
  role: string;
}

const AdminAuthMiddleware = () => {
  const verifyAdminToken = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    console.log("AdminAuthMiddleware => verifyAdminToken");

    const authHeader = req.headers.authorization;

    try {
      if (!authHeader) {
        throw new Error("invalid_token");
      }

      const [, token] = authHeader.split(" ");

      const payload = jwt.verify(token, config.auth.jwtSecret) as JwtPayload;

      const admin = await Admin.findById(payload.adminId);

      if (!admin) {
        throw new Error("invalid_token");
      }

      if (!admin.isActive) {
        throw new Error("ac_deactivated");
      }

      (req as any).adminId = admin._id;
      (req as any).admin = admin;
      (req as any).adminRole = admin.role;

      next();
    } catch (ex: any) {
      req.rCode = 3;
      req.msg =
        ex.message === "ac_deactivated" ? "ac_deactivated" : "invalid_token";

      return ResponseMiddleware(req, res, next);
    }
  };

  const requireRole = (...allowedRoles: string[]) => {
    return (req: Request, res: Response, next: NextFunction) => {
      const adminRole = (req as any).adminRole;

      if (!allowedRoles.includes(adminRole)) {
        req.rCode = 4;
        req.msg = "forbidden";
        return ResponseMiddleware(req, res, next);
      }

      next();
    };
  };

  const requirePermission = (permission: string) => {
    return (req: Request, res: Response, next: NextFunction) => {
      const admin = (req as any).admin;

      if (
        admin.role !== "super_admin" &&
        !admin.permissions.includes(permission)
      ) {
        req.rCode = 4;
        req.msg = "forbidden";
        return ResponseMiddleware(req, res, next);
      }

      next();
    };
  };

  return {
    verifyAdminToken,
    requireRole,
    requirePermission,
  };
};

export default AdminAuthMiddleware;
