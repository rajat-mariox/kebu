import { useState, useEffect } from "react";

interface Admin {
  id: string;
  email: string;
  name: string;
  role?: string;
  lastLogin?: string;
}

export const useAuth = () => {
  const [admin, setAdmin] = useState<Admin | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem("adminToken");
    const adminData = localStorage.getItem("adminData");

    if (token && adminData) {
      setAdmin(JSON.parse(adminData));
    }
    setIsLoading(false);
  }, []);

  const login = (token: string, adminData: Admin) => {
    localStorage.setItem("adminToken", token);
    localStorage.setItem("adminData", JSON.stringify(adminData));
    setAdmin(adminData);
  };

  const logout = () => {
    localStorage.removeItem("adminToken");
    localStorage.removeItem("adminData");
    setAdmin(null);
  };

  return {
    admin,
    isAuthenticated: !!admin,
    isLoading,
    login,
    logout,
  };
};
