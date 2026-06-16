import { useState } from "react";
import { X, ZoomIn, ZoomOut, Download, ExternalLink } from "lucide-react";

interface DocumentViewerProps {
  url: string;
  title?: string;
  onClose: () => void;
}

export default function DocumentViewer({ url, title, onClose }: DocumentViewerProps) {
  const [zoom, setZoom] = useState(1);

  const isPdf = url.toLowerCase().endsWith(".pdf");

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70" onClick={onClose}>
      <div
        className="relative w-full max-w-4xl max-h-[90vh] bg-white rounded-xl overflow-hidden shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b bg-gray-50">
          <h3 className="text-sm font-semibold text-gray-900 truncate">
            {title || "Document Preview"}
          </h3>
          <div className="flex items-center gap-2">
            {!isPdf && (
              <>
                <button
                  onClick={() => setZoom((z) => Math.max(0.25, z - 0.25))}
                  className="rounded-lg p-1.5 text-gray-500 hover:bg-gray-200"
                  title="Zoom Out"
                >
                  <ZoomOut className="h-4 w-4" />
                </button>
                <span className="text-xs text-gray-500 min-w-[40px] text-center">
                  {Math.round(zoom * 100)}%
                </span>
                <button
                  onClick={() => setZoom((z) => Math.min(3, z + 0.25))}
                  className="rounded-lg p-1.5 text-gray-500 hover:bg-gray-200"
                  title="Zoom In"
                >
                  <ZoomIn className="h-4 w-4" />
                </button>
              </>
            )}
            <a
              href={url}
              download
              className="rounded-lg p-1.5 text-gray-500 hover:bg-gray-200"
              title="Download"
            >
              <Download className="h-4 w-4" />
            </a>
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-lg p-1.5 text-gray-500 hover:bg-gray-200"
              title="Open in new tab"
            >
              <ExternalLink className="h-4 w-4" />
            </a>
            <button
              onClick={onClose}
              className="rounded-lg p-1.5 text-gray-500 hover:bg-red-100 hover:text-red-600"
              title="Close"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="overflow-auto bg-gray-100" style={{ maxHeight: "calc(90vh - 52px)" }}>
          {isPdf ? (
            <iframe
              src={url}
              className="w-full border-0"
              style={{ height: "calc(90vh - 52px)" }}
              title={title || "Document"}
            />
          ) : (
            <div className="flex items-center justify-center p-4 min-h-[400px]">
              <img
                src={url}
                alt={title || "Document"}
                className="max-w-full transition-transform duration-200"
                style={{ transform: `scale(${zoom})`, transformOrigin: "center" }}
                onError={(e) => {
                  (e.target as HTMLImageElement).src = "";
                  (e.target as HTMLImageElement).alt = "Failed to load image";
                }}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
