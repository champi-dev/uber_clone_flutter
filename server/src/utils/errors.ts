export class AppError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}
export const badRequest = (m: string) => new AppError(400, m);
export const unauthorized = (m = 'Unauthorized') => new AppError(401, m);
export const forbidden = (m = 'Forbidden') => new AppError(403, m);
export const notFound = (m = 'Not found') => new AppError(404, m);
