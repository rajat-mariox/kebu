import { useState, useEffect, useCallback } from "react";
import { FileText, Save, Eye, Code, CheckCircle } from "lucide-react";
import toast from "react-hot-toast";
import { cmsService } from "../services";
import type { CMSPage } from "../types";

const defaultPages = [
  { key: "terms_conditions", title: "Terms & Conditions" },
  { key: "privacy_policy", title: "Privacy Policy" },
  { key: "refund_policy", title: "Refund Policy" },
  { key: "about_us", title: "About Us" },
  { key: "contact_us", title: "Contact Us" },
  { key: "faq", title: "FAQ" },
];

export default function CMS() {
  const [pages, setPages] = useState<CMSPage[]>([]);
  const [activePage, setActivePage] = useState("terms_conditions");
  const [content, setContent] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [view, setView] = useState<"edit" | "preview">("edit");

  const fetchPages = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await cmsService.getAll();
      const data = res.data as CMSPage[] | { pages?: CMSPage[]; items?: CMSPage[] } | undefined;
      let list: CMSPage[] = [];
      if (Array.isArray(data)) {
        list = data;
      } else if (data && 'pages' in data) {
        list = data.pages || [];
      } else if (data && 'items' in data) {
        list = data.items || [];
      }
      setPages(list);
    } catch {
      setPages([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchPages(); }, [fetchPages]);

  useEffect(() => {
    const page = pages.find((p) => p.slug === activePage);
    setContent(page?.content || "");
  }, [activePage, pages]);

  const handleSave = async () => {
    setIsSaving(true);
    try {
      const existing = pages.find((p) => p.slug === activePage);
      const pageData = {
        slug: activePage,
        title: defaultPages.find((p) => p.key === activePage)?.title || activePage,
        content,
        isActive: true,
      };
      if (existing) await cmsService.update(activePage, pageData);
      else await cmsService.create(pageData);
      toast.success("Page saved");
      fetchPages();
    } catch {
      toast.error("Failed to save page");
    } finally {
      setIsSaving(false);
    }
  };

  const isPublished = (key: string) => pages.some((p) => p.slug === key);

  const insertTag = (before: string, after: string) => {
    const el = document.getElementById("content-editor") as HTMLTextAreaElement;
    if (!el) return;
    const start = el.selectionStart;
    const end = el.selectionEnd;
    const sel = el.value.substring(start, end);
    setContent(el.value.substring(0, start) + before + sel + after + el.value.substring(end));
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Content Management</h1>
        <p className="mt-1 text-sm text-gray-500">Manage static pages and content</p>
      </div>

      <div className="flex gap-6">
        {/* Sidebar */}
        <div className="w-60 flex-shrink-0">
          <div className="rounded-xl bg-white shadow-sm border border-gray-100 overflow-hidden">
            <div className="p-4 border-b">
              <h3 className="font-semibold text-gray-900 flex items-center gap-2">
                <FileText className="h-4 w-4 text-blue-600" /> Pages
              </h3>
            </div>
            <nav className="p-2 space-y-0.5">
              {defaultPages.map((page) => (
                <button
                  key={page.key}
                  onClick={() => setActivePage(page.key)}
                  className={`w-full text-left px-3 py-2 rounded-lg text-sm flex items-center justify-between transition-colors ${
                    activePage === page.key
                      ? "bg-blue-50 text-blue-700 font-medium"
                      : "text-gray-600 hover:bg-gray-50"
                  }`}
                >
                  <span>{page.title}</span>
                  {isPublished(page.key) ? (
                    <CheckCircle className="h-3.5 w-3.5 text-green-500" />
                  ) : (
                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-gray-100 text-gray-500">Draft</span>
                  )}
                </button>
              ))}
            </nav>
          </div>
        </div>

        {/* Editor */}
        <div className="flex-1">
          <div className="rounded-xl bg-white shadow-sm border border-gray-100 overflow-hidden">
            {isLoading ? (
              <div className="flex items-center justify-center h-96">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
              </div>
            ) : (
              <>
                {/* Toolbar */}
                <div className="p-4 border-b flex items-center justify-between">
                  <div>
                    <h3 className="font-semibold text-gray-900">
                      {defaultPages.find((p) => p.key === activePage)?.title}
                    </h3>
                    {isPublished(activePage) && (
                      <p className="text-xs text-gray-500 mt-0.5">
                        Last updated: {new Date(pages.find((p) => p.slug === activePage)?.updatedAt || "").toLocaleString()}
                      </p>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="flex rounded-lg border border-gray-200 overflow-hidden">
                      <button onClick={() => setView("edit")}
                        className={`px-3 py-1.5 text-xs font-medium flex items-center gap-1 ${view === "edit" ? "bg-blue-50 text-blue-600" : "text-gray-500 hover:bg-gray-50"}`}>
                        <Code className="h-3.5 w-3.5" /> Edit
                      </button>
                      <button onClick={() => setView("preview")}
                        className={`px-3 py-1.5 text-xs font-medium flex items-center gap-1 border-l ${view === "preview" ? "bg-blue-50 text-blue-600" : "text-gray-500 hover:bg-gray-50"}`}>
                        <Eye className="h-3.5 w-3.5" /> Preview
                      </button>
                    </div>
                    <button onClick={handleSave} disabled={isSaving}
                      className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors">
                      <Save className="h-4 w-4" />
                      {isSaving ? "Saving..." : "Save"}
                    </button>
                  </div>
                </div>

                {view === "edit" ? (
                  <div className="p-4">
                    {/* Formatting Toolbar */}
                    <div className="flex gap-1 mb-2 p-1.5 bg-gray-50 rounded-lg border">
                      <button type="button" onClick={() => insertTag("<strong>", "</strong>")}
                        className="px-2.5 py-1 text-sm font-bold bg-white border rounded hover:bg-gray-50">B</button>
                      <button type="button" onClick={() => insertTag("<em>", "</em>")}
                        className="px-2.5 py-1 text-sm italic bg-white border rounded hover:bg-gray-50">I</button>
                      <span className="w-px bg-gray-200 mx-1" />
                      <button type="button" onClick={() => insertTag("\n<h2>", "</h2>\n")}
                        className="px-2.5 py-1 text-xs bg-white border rounded hover:bg-gray-50">H2</button>
                      <button type="button" onClick={() => insertTag("\n<h3>", "</h3>\n")}
                        className="px-2.5 py-1 text-xs bg-white border rounded hover:bg-gray-50">H3</button>
                      <button type="button" onClick={() => insertTag("\n<p>", "</p>\n")}
                        className="px-2.5 py-1 text-xs bg-white border rounded hover:bg-gray-50">P</button>
                      <span className="w-px bg-gray-200 mx-1" />
                      <button type="button" onClick={() => insertTag("\n<ul>\n  <li>", "</li>\n</ul>\n")}
                        className="px-2.5 py-1 text-xs bg-white border rounded hover:bg-gray-50">List</button>
                      <button type="button" onClick={() => insertTag('<a href="">', "</a>")}
                        className="px-2.5 py-1 text-xs bg-white border rounded hover:bg-gray-50">Link</button>
                    </div>

                    <textarea
                      id="content-editor"
                      value={content}
                      onChange={(e) => setContent(e.target.value)}
                      rows={22}
                      placeholder="Enter page content here... (HTML supported)"
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 font-mono text-sm resize-y"
                    />
                  </div>
                ) : (
                  <div className="p-6">
                    <div
                      className="prose max-w-none p-6 bg-gray-50 rounded-lg border min-h-[300px]"
                      dangerouslySetInnerHTML={{ __html: content || "<p class='text-gray-400'>No content yet</p>" }}
                    />
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
