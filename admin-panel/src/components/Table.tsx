import type { ReactNode } from "react";

// New interface that pages expect
interface SimpleColumn<T> {
  key: string;
  label: string;
  render?: (value: any, row: T) => ReactNode;
}

// Legacy interface
interface LegacyColumn<T> {
  header: string;
  accessor: keyof T | ((item: T) => ReactNode);
  className?: string;
}

export type Column<T> = SimpleColumn<T> | LegacyColumn<T>;

interface TableProps<T> {
  columns: Column<T>[];
  data: T[];
  keyExtractor?: (item: T) => string;
  isLoading?: boolean;
  emptyMessage?: string;
}

function isSimpleColumn<T>(column: Column<T>): column is SimpleColumn<T> {
  return "key" in column && "label" in column;
}

export default function Table<T extends Record<string, any>>({
  columns,
  data = [] as unknown as T[],
  keyExtractor,
  isLoading = false,
  emptyMessage = "No data available",
}: TableProps<T>) {
  const safeData = Array.isArray(data) ? data : [];

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-orange-500 border-t-transparent"></div>
      </div>
    );
  }

  if (safeData.length === 0) {
    return (
      <div className="flex h-64 items-center justify-center text-gray-500">
        {emptyMessage}
      </div>
    );
  }

  const getKey = (item: T, index: number): string => {
    if (keyExtractor) return keyExtractor(item);
    if ("_id" in item) return String(item._id);
    if ("id" in item) return String(item.id);
    return String(index);
  };

  const renderHeader = (column: Column<T>): string => {
    if (isSimpleColumn(column)) return column.label;
    return column.header;
  };

  const renderCell = (column: Column<T>, item: T): ReactNode => {
    if (isSimpleColumn(column)) {
      const value = item[column.key];
      if (column.render) {
        return column.render(value, item);
      }
      return String(value ?? "");
    }
    // Legacy column
    if (typeof column.accessor === "function") {
      return column.accessor(item);
    }
    return String(item[column.accessor] ?? "");
  };

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            {columns.map((column, index) => (
              <th
                key={index}
                className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
              >
                {renderHeader(column)}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200 bg-white">
          {safeData.map((item, index) => (
            <tr key={getKey(item, index)} className="hover:bg-gray-50">
              {columns.map((column, colIndex) => (
                <td
                  key={colIndex}
                  className="whitespace-nowrap px-6 py-4 text-sm text-gray-900"
                >
                  {renderCell(column, item)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
