import { Request, Response, NextFunction } from "express";
import * as searchService from "../services/search.service";

export const globalSearch = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const query = req.query.q as string;
  const admin = (req as any).admin;

  const results = await searchService.globalSearch(
    query,
    admin.permissions || [],
    admin.role,
  );

  req.rData = results;
  next();
};
