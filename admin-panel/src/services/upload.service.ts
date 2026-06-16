import api from "./api";

export const uploadService = {
  uploadSingle: async (file: File): Promise<string> => {
    const formData = new FormData();
    formData.append("file", file);

    const response = await api.post("/admin/upload/single", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return response.data.data?.url || "";
  },

  uploadMultiple: async (files: File[]): Promise<string[]> => {
    const formData = new FormData();
    files.forEach((file) => formData.append("files", file));

    const response = await api.post("/admin/upload", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return response.data.data?.urls || [];
  },
};
