export const isProduction = process.env.NODE_ENV === "production";
export const isDevelopment = process.env.NODE_ENV === "development";
export const isTest = process.env.NODE_ENV === "test";

export const validateRequiredEnvVars = (vars: string[]): void => {
  const missing = vars.filter((v) => !process.env[v]);
  if (missing.length > 0) {
    console.error(`Missing required environment variables: ${missing.join(", ")}`);
    if (isProduction) {
      throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
    }
  }
};
