import api from "./api";

export const searchService = {
  globalSearch: (q: string) => api.get("/admin/search", { params: { q } }),
};
