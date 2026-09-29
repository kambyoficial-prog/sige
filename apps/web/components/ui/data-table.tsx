"use client";

import * as React from "react";
import { flexRender, getCoreRowModel, useReactTable, type ColumnDef } from "@tanstack/react-table";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";

export function DataTable<TData, TValue>({ columns, data, loading = false, emptyTitle = "Sem registos", emptyDescription = "Não existem registos para apresentar." }: { columns: ColumnDef<TData, TValue>[]; data: TData[]; loading?: boolean; emptyTitle?: string; emptyDescription?: string }) {
  const table = useReactTable({ data, columns, getCoreRowModel: getCoreRowModel() });
  if (loading) return <div className="space-y-2 rounded-lg border border-border p-3">{Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-10 w-full" />)}</div>;
  if (!data.length) return <EmptyState title={emptyTitle} description={emptyDescription} />;
  return <div className="rounded-lg border border-border"><Table><TableHeader>{table.getHeaderGroups().map(group => <TableRow key={group.id}>{group.headers.map(header => <TableHead key={header.id}>{header.isPlaceholder ? null : flexRender(header.column.columnDef.header, header.getContext())}</TableHead>)}</TableRow>)}</TableHeader><TableBody>{table.getRowModel().rows.map(row => <TableRow key={row.id}>{row.getVisibleCells().map(cell => <TableCell key={cell.id}>{flexRender(cell.column.columnDef.cell, cell.getContext())}</TableCell>)}</TableRow>)}</TableBody></Table></div>;
}
