import type { ReactNode } from "react";

type BadgeVariant = "success" | "danger" | "warning" | "info" | "secondary";

interface BadgeProps {
  variant?: BadgeVariant;
  children: ReactNode;
  className?: string;
  // Legacy support
  status?: string;
}

const variantColors: Record<BadgeVariant, string> = {
  success: "bg-green-100 text-green-800",
  danger: "bg-red-100 text-red-800",
  warning: "bg-yellow-100 text-yellow-800",
  info: "bg-blue-100 text-blue-800",
  secondary: "bg-gray-100 text-gray-800",
};

export default function Badge({
  variant = "secondary",
  children,
  className = "",
  status,
}: BadgeProps) {
  // Legacy support: if status is provided, use it as children
  const content = children ?? status?.replace(/_/g, " ") ?? "";
  const colorClass = variantColors[variant];

  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${colorClass} ${className}`}
    >
      {content}
    </span>
  );
}
