import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Admin, AdminRole, Permission } from "../types";

interface AuthState {
  admin: Admin | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  setAuth: (admin: Admin, token: string) => void;
  logout: () => void;
  setLoading: (loading: boolean) => void;
  hasPermission: (permission: Permission) => boolean;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      admin: null,
      token: null,
      isAuthenticated: false,
      isLoading: true,

      setAuth: (admin, token) => {
        set({
          admin,
          token,
          isAuthenticated: true,
          isLoading: false,
        });
      },

      logout: () => {
        set({
          admin: null,
          token: null,
          isAuthenticated: false,
          isLoading: false,
        });
        localStorage.removeItem("auth-storage");
      },

      setLoading: (loading) => set({ isLoading: loading }),

      hasPermission: (permission) => {
        const { admin } = get();
        if (!admin) return false;

        const role = typeof admin.role === "string" ? null : admin.role as AdminRole | null;

        if (role?.name === "Super Admin") return true;

        return (
          (admin.permissions as Permission[])?.includes(permission) ||
          role?.permissions?.includes(permission) ||
          false
        );
      },
    }),
    {
      name: "auth-storage",
      onRehydrateStorage: () => (state) => {
        if (state) {
          state.setLoading(false);
        }
      },
    },
  ),
);
