import { AlertTriangle } from "lucide-react";
import { Modal } from "./Modal";
import Button from "./Button";

interface ConfirmDialogProps {
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  variant?: "danger" | "warning";
  isLoading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export default function ConfirmDialog({
  title,
  message,
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  variant = "danger",
  isLoading = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  return (
    <Modal title={title} onClose={onCancel} size="sm">
      <div className="flex flex-col items-center text-center py-2">
        <div
          className={`rounded-full p-3 ${
            variant === "danger" ? "bg-red-100" : "bg-yellow-100"
          }`}
        >
          <AlertTriangle
            className={`h-6 w-6 ${
              variant === "danger" ? "text-red-600" : "text-yellow-600"
            }`}
          />
        </div>
        <p className="mt-3 text-sm text-gray-600">{message}</p>
      </div>
      <div className="flex justify-end gap-3 pt-4">
        <Button variant="secondary" onClick={onCancel} disabled={isLoading}>
          {cancelLabel}
        </Button>
        <Button
          variant={variant === "danger" ? "danger" : "primary"}
          onClick={onConfirm}
          isLoading={isLoading}
        >
          {confirmLabel}
        </Button>
      </div>
    </Modal>
  );
}
