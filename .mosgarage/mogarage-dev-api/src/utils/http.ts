import { Request } from "express";

export interface Paginated<T> {
  data: T[];
  pagination: { page: number; pageSize: number; total: number };
}

export function paginate<T>(items: T[], req: Request): Paginated<T> {
  const page = Math.max(1, parseInt(String(req.query.page ?? "1"), 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(String(req.query.pageSize ?? "20"), 10) || 20)
  );
  const start = (page - 1) * pageSize;
  const data = items.slice(start, start + pageSize);
  return { data, pagination: { page, pageSize, total: items.length } };
}

export class ApiError extends Error {
  status: number;
  details?: string[];
  constructor(status: number, message: string, details?: string[]) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export const NotFound = (resource: string) =>
  new ApiError(404, `${resource} not found`);

export const Conflict = (message: string) => new ApiError(409, message);
